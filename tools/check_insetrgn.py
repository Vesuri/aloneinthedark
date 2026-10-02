#!/usr/bin/env python3
"""One-pixel region expansion: independent pixel oracle and original capture."""
import argparse, os, re, struct, subprocess, tempfile
from pathlib import Path
from check_driver22 import fields, one
ROOT=Path(__file__).resolve().parents[1]

def pixels(data):
    w=struct.unpack('>'+'h'*(len(data)//2),data);n,top,left,bottom,right=w[:5]
    if n==10:return {(x,y) for y in range(top,bottom) for x in range(left,right)}
    rows={};edges=set();i=5
    while w[i]!=32767:
        y=w[i];i+=1
        while w[i]!=32767:edges.symmetric_difference_update([w[i]]);i+=1
        i+=1;rows[y]=sorted(edges)
    result=set();edges=[]
    for y in range(top,bottom):
        edges=rows.get(y,edges)
        for left,right in zip(edges[::2],edges[1::2]):result.update((x,y) for x in range(left,right))
    return result

def encode(points):
    if not points:return struct.pack('>5h',10,0,0,0,0)
    top=min(y for x,y in points);bottom=max(y for x,y in points)+1
    left=min(x for x,y in points);right=max(x for x,y in points)+1
    if len(points)==(bottom-top)*(right-left):return struct.pack('>5h',10,top,left,bottom,right)
    previous=set();words=[]
    for y in range(top,bottom+1):
        next_edges={x for x in range(left,right+1) if ((x,y) in points)!=((x-1,y) in points)}
        changes=sorted(previous^next_edges)
        if changes:words += [y]+changes+[32767]
        previous=next_edges
    words += [32767]
    return struct.pack('>'+'h'*(5+len(words)),10+len(words)*2,top,left,bottom,right,*words)

def run(reference=None,status=None,native=None,native_status=None):
    code=r'''
#include <cstdint>
#include <cstdio>
#include <cstring>
#include "src/mac/RegionExpand.h"
int main(int argc,char**){uint8_t p[4096],out[4096],saved[4096];unsigned n=0,v;uint16_t size;
while(scanf("%2x",&v)==1){if(n==sizeof p)return 1;p[n++]=v;}
if(argc>1){memset(out,0xa5,sizeof out);memcpy(saved,out,sizeof out);
return RegionExpand::one(p,n,out,sizeof out,size)||size||memcmp(out,saved,sizeof out)?5:0;}
if(!RegionExpand::one(p,n,out,sizeof out,size))return 2;
for(unsigned i=0;i<size;++i)printf("%02x",out[i]);puts("");
unsigned required=size;memset(out,0xa5,sizeof out);memcpy(saved,out,sizeof out);
if(RegionExpand::one(p,n,out,required-1,size)||size||memcmp(out,saved,sizeof out))return 3;
if(RegionExpand::one(p,n-1,out,sizeof out,size)||size||memcmp(out,saved,sizeof out))return 4;
return 0;}
'''
    with tempfile.TemporaryDirectory(prefix='aitd-inset-') as directory:
        source=Path(directory)/'check.cpp';exe=Path(directory)/'check';source.write_text(code)
        subprocess.run([os.environ.get('CXX','c++'),'-std=c++11','-Wall','-Wextra','-fsanitize=address,undefined','-I',str(ROOT),str(source),'-o',str(exe)],check=True)
        def model(data):
            r=subprocess.run([str(exe)],input=data.hex(),capture_output=True,text=True)
            if r.returncode:raise ValueError(f'encoder/rejection {r.returncode}: {r.stderr}')
            return bytes.fromhex(r.stdout)
        shapes=[set(),{(x,y) for x in range(-4,3) for y in range(-2,6)},
                {(x,y) for x in range(12) for y in range(12) if x<3 or y<3},
                {(x,y) for x in range(20) for y in range(12) if x<5 or x>8},
                {(x,y) for x in range(20) for y in range(12) if x<5 or x>6},
                {(x,y) for x in range(12) for y in range(12) if x<2 or x>9 or y<2 or y>9},
                # Many transitions, negative coordinates, and long empty gaps
                # exercise forward decoding and the three-row expansion window.
                {(x,y) for y in range(-100,200) for x in range(-8,12)
                 if y % 31 < 20 and (x < (y % 7)-5 or x > (y % 5)+5)}]
        for points in shapes:
            expected=encode({(x+dx,y+dy) for x,y in points for dx in (-1,0,1) for dy in (-1,0,1)})
            if model(encode(points))!=expected:raise ValueError('independent pixel oracle')
        malformed=bytearray(encode(shapes[-1]))
        malformed[-2:]=b'\x00\x00'  # Invalid tail must be checked before publishing.
        rejected=subprocess.run([str(exe),'reject'],input=malformed.hex(),capture_output=True,text=True)
        if rejected.returncode:raise ValueError('malformed tail published output: '+rejected.stderr)
        if reference:
            text=reference.read_text()
            if status!=0 or text.count('COMPLETE original pond region expansion')!=1 or text.count('Exited via the debugger')!=1 or re.search(r'FAIL|LUA ERROR|TIMEOUT|Timed out',text):raise ValueError('completion')
            raw=(ROOT/'tmp/segments/CODE_4_Dark').read_bytes()[0x33f2:0x33fa]
            if raw.hex()!='2f0a4878ffffa8e1' or one(text,r'^INSET_BYTES n=18 data=(\w+)$')!=raw[-4:].hex().upper():raise ValueError('original caller bytes')
            argument=one(text,r'^INSET_ARGUMENTS (\w+)$')
            if len(argument)!=16 or not argument.startswith('FFFFFFFF'):raise ValueError('inset distances')
            before=(ROOT/'tmp/inset-reference-18-ENTER-region.bin').read_bytes();after=(ROOT/'tmp/inset-reference-18-RETURN-region.bin').read_bytes()
            expected=encode({(x+dx,y+dy) for x,y in pixels(before) for dx in (-1,0,1) for dy in (-1,0,1)})
            if model(before)!=after or expected!=after:raise ValueError('original expansion bytes')
            for suffix in ('port','poly'):
                if (ROOT/f'tmp/inset-reference-18-ENTER-{suffix}.bin').read_bytes()!=(ROOT/f'tmp/inset-reference-18-RETURN-{suffix}.bin').read_bytes():raise ValueError('changed '+suffix)
            if (ROOT/'tmp/inset-reference-ENTER-pixels.bin').read_bytes()!=(ROOT/'tmp/inset-reference-RETURN-pixels.bin').read_bytes():raise ValueError('drawing')
            e,r=[fields(one(text,rf'^INSET_{phase} n=18 (.*)$')) for phase in ('ENTER','RETURN')]
            if e['trap']!=0xa8e1 or r['sp']!=e['sp']+8 or r['d0'] or r['memerr']:raise ValueError('ABI')
            for reg in [f'd{i}' for i in range(3,8)]+[f'a{i}' for i in range(2,7)]:
                if e[reg]!=r[reg]:raise ValueError('preserved '+reg)
            owner=fields(one(text,r'^INSET_OWNER (.*)$'));size=fields(one(text,r'^INSET_SIZE (.*)$'));flags=fields(one(text,r'^INSET_FLAGS (.*)$'))
            if size['size']!=len(after) or size['memerr'] or flags['flags'] or flags['memerr'] or owner['owner']!=owner['zone'] or owner['memerr']:raise ValueError('ownership')
        if native:
            t=native.read_text()
            if native_status!=0 or t.count('PASS native InsetRgn measured original return')!=1 or t.count('[Inferior 1 (Remote target) detached]')!=1 or re.search(r'FAIL|Error in|TIMEOUT|Timed out|Program received signal',t):raise ValueError('native completion')
            stack=fields(one(t,r'^INSET_SYSTEM_STACK (.*)$'));dispatch=fields(one(t,r'^INSET_DISPATCH (.*)$'))
            if not stack['lower']+5200<dispatch['sp']<=stack['upper']:raise ValueError('native stack headroom')
            a,b=[fields(one(t,rf'^INSET_NATIVE_{phase} (.*)$')) for phase in ('ENTER','RETURN')]
            if a['distances']!=0xffffffff or b['sp']!=a['sp']+8 or b['d0'] or b['memerr'] or a['region']!=b['region']:raise ValueError('native ABI/result')
            for reg in [f'd{i}' for i in range(3,8)]+[f'a{i}' for i in range(2,7)]:
                if a[reg]!=b[reg]:raise ValueError('native preserved '+reg)
            if b['d1']!=(a['d1']&0xffff0000)|0xffff or b['d2']!=(a['d2']&0xffff0000)|200:raise ValueError('native bounds scratch')
            for phase in ('ENTER','RETURN'):
                data=(ROOT/f'tmp/inset-native-{phase}-region.bin').read_bytes()
                if data!=(ROOT/f'tmp/inset-reference-18-{phase}-region.bin').read_bytes():raise ValueError('native region '+phase)
                if len(data)!=(a if phase=='ENTER' else b)['size']:raise ValueError('native region extent')
            for suffix in ('port','pixels'):
                if (ROOT/f'tmp/inset-native-ENTER-{suffix}.bin').read_bytes()!=(ROOT/f'tmp/inset-native-RETURN-{suffix}.bin').read_bytes():raise ValueError('native changed '+suffix)
            if not re.search(r'^INSET_NATIVE_OWNER size=244 flags=0 owned=1 frames=\d+ book=0$',t,re.M):raise ValueError('native heap/recording evidence')
    print('PASS InsetRgn(-1,-1): independent shapes, atomic rejection'+('; exact original region/ABI/ownership and no drawing' if reference else '')+('; paired native bytes/ABI/ownership' if native else ''))

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--reference',type=Path);p.add_argument('--status',type=int);p.add_argument('--native',type=Path);p.add_argument('--native-status',type=int);a=p.parse_args()
    if a.reference and a.status is None:p.error('--reference requires --status')
    if a.native and (not a.reference or a.native_status is None):p.error('--native requires reference and native status')
    run(a.reference,a.status,a.native,a.native_status)
