#!/usr/bin/env python3
"""Production polygon recorder: host edge cases and paired original/native calls."""
import argparse, os, re, struct, subprocess
import local_temp as tempfile
from pathlib import Path
from check_driver22 import fields, one
ROOT=Path(__file__).resolve().parents[1]

def run(reference=None,status=None,native=None,native_status=None):
    code=r'''
#include <cstdint>
#include <cstdio>
#include <cstring>
#include "src/mac/PolygonRecord.h"
int main(){
 uint8_t p[32768]={0};PolygonRecord::put(p,10);int x=0,y=0,a,b;char op;
 while(scanf(" %c",&op)==1){
  if(op=='M'){if(scanf("%d%d",&x,&y)!=2)return 2;}
  else if(op=='L'){if(scanf("%d%d",&a,&b)!=2||!PolygonRecord::append(p,sizeof(p),x,y,a,b))return 3;x=a;y=b;}
  else if(op=='C'){if(!PolygonRecord::close(p,sizeof(p)))return 4;}
  else return 5;
  unsigned n=RectBounds::word(p);for(unsigned i=0;i<n;++i)printf("%02x",p[i]);puts("");
 }
 // Invalid records and insufficient capacity must not change any bytes.
 uint8_t q[32]={0},saved[32];PolygonRecord::put(q,10);memcpy(saved,q,32);
 if(PolygonRecord::append(q,17,0,0,1,1)||memcmp(q,saved,32))return 6;
 if(!PolygonRecord::append(q,32,0,0,1,1))return 7;memcpy(saved,q,32);
 if(PolygonRecord::append(q,32,2,2,3,3)||memcmp(q,saved,32))return 8;
 if(PolygonRecord::close(q,32)||memcmp(q,saved,32))return 9;
 PolygonRecord::put(q,11);if(PolygonRecord::growth(q,32,0,0))return 10;
 return 0;
}'''
    with tempfile.TemporaryDirectory(prefix='aitd-polygon-') as d:
        source=Path(d)/'test.cpp';exe=Path(d)/'test';source.write_text(code)
        subprocess.run([os.environ.get('CXX','c++'),'-std=c++11','-Wall','-Wextra','-I',str(ROOT),str(source),'-o',str(exe)],check=True)
        def model(commands):
            p=subprocess.run([str(exe)],input=commands,text=True,capture_output=True,check=True)
            return [bytes.fromhex(line) for line in p.stdout.splitlines()]
        chain=[(-32768,-5),(32767,2),(0,32767),(-32768,-5)]
        out=model('M -32768 -5\nL 32767 2\nL 0 32767\nL -32768 -5\nC\n')
        expected=struct.pack('>H4h',26,-5,-32768,32767,32767)+b''.join(struct.pack('>hh',y,x) for x,y in chain)
        if out[-1]!=expected:raise ValueError('signed polygon bounds/points')
        if not reference:return
        log=reference.read_text()
        def complete(text,rc,marker):
            if rc!=0 or text.count(marker)!=1 or re.search(r'FAIL|LUA ERROR|Error in|TIMEOUT|Timed out|Program received signal',text):raise ValueError('completion')
        complete(log,status,'COMPLETE original polygon recording')
        if log.count('Exited via the debugger')!=1:raise ValueError('reference termination')
        if 'POLY_SKIP Return released' not in log:raise ValueError('reference Enter route')
        traps=[0xa8cb,0xa893]+[0xa891]*10+[0xa8cc]
        offsets=[0x3396,0x33b8]+[0x33ce]*10+[0x33dc]
        raw=(ROOT/'tmp/segments/CODE_4_Dark').read_bytes()
        def blob(which,n,phase,kind):return (ROOT/'tmp'/f'polygon-{which}-{n}-{phase}-{kind}.bin').read_bytes()
        records=[];commands='';expected_poly=bytes.fromhex('000a0000000000000000')
        for n,(trap,offset) in enumerate(zip(traps,offsets),1):
            if one(log,rf'^POLY_BYTES n={n} data=(\w+)$')!=raw[offset-2:offset+2].hex().upper():raise ValueError('original caller bytes')
            e,r=[fields(one(log,rf'^POLY_{phase} n={n} (.*)$')) for phase in ('ENTER','RETURN')]
            if e['trap']!=trap or r['sp']!=e['sp']+(4 if trap in (0xa891,0xa893) else 0):raise ValueError('reference stack')
            if n>1 and blob('reference',n,'ENTER','poly')!=expected_poly:raise ValueError('reference recording continuity')
            port=blob('reference',n,'ENTER','port');after=blob('reference',n,'RETURN','port');want=bytearray(port)
            if trap==0xa8cb:
                want[66:68]=b'\xff\xff';want[100:104]=b'\0\0\0\1'
            elif trap in (0xa891,0xa893):
                y,x=struct.unpack('>hh',e['args'].to_bytes(4,'big'));want[48:52]=struct.pack('>hh',y,x)
                commands+=f'{"L" if trap==0xa891 else "M"} {x} {y}\n';expected_poly=model(commands)[-1]
            else:
                want[66:68]=bytes(2);want[100:104]=bytes(4);commands+='C\n';expected_poly=model(commands)[-1]
            if r['size']!=len(expected_poly) or after!=want or blob('reference',n,'RETURN','poly')!=expected_poly:raise ValueError('reference polygon/port')
            for reg in [f'd{i}' for i in range(3,8)]+[f'a{i}' for i in range(2,7)]:
                if e[reg]!=r[reg]:raise ValueError('reference preserved '+reg)
            if r['memerr'] or r['d0']!=(1 if trap in (0xa8cb,0xa8cc) else (0 if trap==0xa891 else e['d0'])):raise ValueError('reference result')
            if n==13:
                top,bottom=struct.unpack_from('>H',expected_poly,2)[0],struct.unpack_from('>H',expected_poly,6)[0]
                if r['d1']!=top or r['d2']!=((e['d2']&0xffff0000)|bottom):raise ValueError('reference close bounds scratch')
            elif r['d1']!=e['d1'] or r['d2']!=e['d2']:raise ValueError('reference D1/D2 preservation')
            records.append((e,r,port,after,expected_poly))
        if fields(one(log,r'^POLY_SIZE (.*)$'))['size']!=54 or fields(one(log,r'^POLY_FLAGS (.*)$'))['flags']!=0:raise ValueError('original handle extent/state')
        owner=fields(one(log,r'^POLY_OWNER (.*)$'))
        if owner['owner']!=owner['zone'] or owner['memerr']:raise ValueError('original handle owner')
        for which in (['reference','native'] if native else ['reference']):
            if (ROOT/'tmp'/f'polygon-{which}-ENTER-pixels.bin').read_bytes()!=(ROOT/'tmp'/f'polygon-{which}-RETURN-pixels.bin').read_bytes():raise ValueError(which+' drawing during recording')
        if not native:return
        text=native.read_text();complete(text,native_status,'PASS native polygon recording; next stop OpenRgn')
        if text.count('[Inferior 1 (Remote target) detached]')!=1:raise ValueError('native termination')
        for n,(e,r,port,after,expected_poly) in enumerate(records,1):
            a,b=[fields(one(text,rf'^POLY_{phase} n={n} (.*)$')) for phase in ('ENTER','RETURN')]
            if b['memerr'] or b['size']!=len(expected_poly):raise ValueError('native memory error/extent')
            if 3<=n<=12 and (b['a1']!=b['poly'] or b['a0']-b['a5']!=r['a0']-r['a5']):raise ValueError('native LineTo semantic pointers')
            if n==1 and (b['a0']!=b['port'] or b['a1']!=b['body']+10):raise ValueError('native OpenPoly pointer results')
            if n==2 and b['a1']!=b['port']:raise ValueError('native MoveTo port result')
            if n==13 and b['a0']!=b['port']:raise ValueError('native ClosePoly port result')
            if a['trap']!=e['trap'] or b['sp']-a['sp']!=r['sp']-e['sp'] or b['d0']!=r['d0']:raise ValueError('native stack/result')
            for reg in [f'd{i}' for i in range(3,8)]+[f'a{i}' for i in range(2,7)]:
                if a[reg]!=b[reg]:raise ValueError('native preserved '+reg)
            if n==13:
                if b['d1']!=r['d1'] or b['d2']!=(a['d2']&0xffff0000)|(r['d2']&65535):raise ValueError('native close bounds scratch')
            elif b['d1']!=a['d1'] or b['d2']!=a['d2']:raise ValueError('native D1/D2 preservation')
            before=blob('native',n,'ENTER','port');got=blob('native',n,'RETURN','port');want=bytearray(before)
            ranges=((66,68),(100,104)) if n in (1,13) else ((48,52),)
            for start,end in ranges:want[start:end]=after[start:end]
            if got!=want or blob('native',n,'RETURN','poly')!=expected_poly:raise ValueError('native polygon/port')
        if not re.search(r'POLY_OWNER size=54 flags=0 owned=1',text):raise ValueError('native ownership')

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--reference',type=Path);p.add_argument('--status',type=int);p.add_argument('--native',type=Path);p.add_argument('--native-status',type=int);a=p.parse_args()
    if a.native and not a.reference:p.error('--native requires --reference')
    if a.reference and a.status is None:p.error('--reference requires --status')
    if a.native and a.native_status is None:p.error('--native requires --native-status')
    run(a.reference,a.status,a.native,a.native_status)
    print('PASS polygon recording: signed bounds and atomic rejection'+(', original bytes/ABI/ownership' if a.reference else '')+(', native bytes/ABI/ownership' if a.native else ''))
