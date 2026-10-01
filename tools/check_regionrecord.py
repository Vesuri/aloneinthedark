#!/usr/bin/env python3
"""Check production polygon-to-region encoding against original CPU captures."""
import argparse
import os
from pathlib import Path
import re
import struct
import subprocess
import tempfile
from check_driver22 import fields, one

ROOT = Path(__file__).resolve().parents[1]


def run(reference=None, status=None, native=None, native_status=None):
    code = r'''
#include <cstdint>
#include <cstdio>
#include <cstring>
#include "src/mac/PolygonRegion.h"
int main() {
 PolygonRegion::Scratch scratch;
 uint8_t p[4096],out[4096],before[4096];unsigned v,n=0;
 while(scanf("%2x",&v)==1) {if(n==sizeof p)return 2;p[n++]=v;}
 memset(out,0xa5,sizeof out);memcpy(before,out,sizeof out);uint16_t size;
 if(!PolygonRegion::encode(p,n,out,sizeof out,size,scratch))return 3;
 for(unsigned i=0;i<size;++i)printf("%02x",out[i]);puts("");
 // Insufficient capacity and invalid input must fail without publishing bytes.
 memset(out,0xa5,sizeof out);
 if(PolygonRegion::encode(p,n,out,size-1,size,scratch)||size||memcmp(out,before,sizeof out))return 4;
 if(PolygonRegion::encode(p,n-1,out,sizeof out,size,scratch)||size||memcmp(out,before,sizeof out))return 5;
 p[n-1]^=1;
 if(PolygonRegion::encode(p,n,out,sizeof out,size,scratch)||size||memcmp(out,before,sizeof out))return 6;
 p[n-1]^=1;p[3]^=1; // Bounding box must agree with the recorded vertices.
 if(PolygonRegion::encode(p,n,out,sizeof out,size,scratch)||size||memcmp(out,before,sizeof out))return 7;
 p[3]^=1;p[10]=0x7f;p[11]=0xff;p[n-4]=0x7f;p[n-3]=0xff;
 if(PolygonRegion::encode(p,n,out,sizeof out,size,scratch)||size||memcmp(out,before,sizeof out))return 8;
 // Over-complex input is rejected before walking any unavailable vertices.
 p[0]=1;p[1]=18; // 274 bytes: 66 points, beyond the 65-point limit.
 if(PolygonRegion::encode(p,sizeof p,out,sizeof out,size,scratch)||size||memcmp(out,before,sizeof out))return 9;
 return 0;
}'''
    with tempfile.TemporaryDirectory(prefix='aitd-regionrecord-') as directory:
        source=Path(directory)/'check.cpp';exe=Path(directory)/'check'
        source.write_text(code)
        subprocess.run([os.environ.get('CXX','c++'),'-std=c++11','-Wall','-Wextra',
                        '-fsanitize=address,undefined','-I',str(ROOT),str(source),'-o',str(exe)],check=True)
        def encode(polygon):
            result=subprocess.run([str(exe)],input=polygon.hex(),text=True,capture_output=True)
            if result.returncode:
                raise ValueError(f'encoder/atomic rejection failed ({result.returncode}): {result.stderr}')
            return bytes.fromhex(result.stdout)
        rectangle=struct.pack('>5h',30,-10,-10,10,10)+b''.join(
            struct.pack('>hh',y,x) for x,y in [(-10,-10),(10,-10),(10,10),(-10,10),(-10,-10)])
        if encode(rectangle)!=struct.pack('>5h',10,-10,-10,10,10):
            raise ValueError('signed rectangle')
        if reference is None:return
        text=reference.read_text()
        if status!=0 or text.count('COMPLETE original polygon region recording')!=1 or text.count('COMPLETE original region fixtures count=10')!=1 or text.count('Exited via the debugger')!=1 or re.search(r'FAIL|LUA ERROR|TIMEOUT|Timed out',text):
            raise ValueError('reference completion')
        def blob(suffix):return (ROOT/'tmp'/f'regionrecord-reference-{suffix}.bin').read_bytes()
        for n in range(11):
            prefix=f'fixture{n}' if n else '17-RETURN'
            actual=encode(blob(prefix+'-poly'));expected=blob(prefix+'-region')
            if actual!=expected:raise ValueError(f'region fixture {n}: encoded bytes differ')
            if n:
                want=bytearray(blob(prefix+'-before-port'));want[48:52]=blob(prefix+'-poly')[-4:]
                if want!=blob(prefix+'-after-port'):
                    raise ValueError(f'region fixture {n}: recording state not restored')
                if len(re.findall(rf'^RREC_FIXTURE n={n} size={len(expected):X} memerr=0$',text,re.M))!=1:
                    raise ValueError(f'region fixture {n}: result record')
        size=fields(one(text,r'^RREC_SIZE (.*)$'));flags=fields(one(text,r'^RREC_FLAGS (.*)$'));owner=fields(one(text,r'^RREC_OWNER (.*)$'))
        if size['size']!=252 or size['memerr'] or flags['flags'] or flags['memerr'] or owner['owner']!=owner['zone'] or owner['memerr']:
            raise ValueError('original region ownership/extent/state')
        if blob('ENTER-pixels')!=blob('RETURN-pixels'):
            raise ValueError('recording changed framebuffer')
        raw=(ROOT/'tmp/segments/CODE_4_Dark').read_bytes()
        for n,offset in [(14,0x33e0),(15,0x33e8),(16,0x33ec),(17,0x33f0)]:
            if len(re.findall(rf'^RREC_BYTES n={n} data={raw[offset-2:offset+2].hex().upper()}$',text,re.M))!=1:
                raise ValueError('original caller bytes')
            before=blob(f'{n}-ENTER-port');after=blob(f'{n}-RETURN-port');want=bytearray(before)
            if n in (15,17):
                want[66:68]=b'\xff\xff' if n==15 else bytes(2)
                want[96:100]=b'\0\0\0\1' if n==15 else bytes(4)
            if after!=want:raise ValueError(f'original port delta {n}')
            if n<17 and blob(f'{n}-RETURN-region')!=bytes.fromhex('000a0000000000000000'):
                raise ValueError('region published before CloseRgn')


        if native is None:return
        native_text=native.read_text()
        if native_status!=0 or native_text.count('PASS native polygon region recording; next stop DisposeRgn')!=1 or native_text.count('[Inferior 1 (Remote target) detached]')!=1 or re.search(r'FAIL|Error in|TIMEOUT|Timed out|Program received signal',native_text):
            raise ValueError('native completion')
        stack=re.findall(r'^POLYGON_STACK frame=(\d+) saved=(\d+) entry=([0-9A-F]+) lower=([0-9A-F]+) upper=([0-9A-F]+) headroom=(\d+)$',native_text,re.M)
        if len(stack)!=1:raise ValueError('native polygon stack observation')
        frame,saved,entry,lower,upper,headroom=stack[0]
        frame,saved,headroom=map(int,(frame,saved,headroom))
        entry,lower,upper=(int(v,16) for v in (entry,lower,upper))
        if not frame>0 or entry>upper or entry-lower-frame-saved!=headroom or headroom<4096:
            raise ValueError('native polygon interrupt headroom')
        heap=fields(one(native_text,r'^RREC_HEAP (.*)$'))
        if heap['before_count']!=heap['after_count'] or heap['before_total']-heap['after_total']!=4096-252:
            raise ValueError('native workspace ownership')
        for n,trap in [(14,0xa8d8),(15,0xa8da),(16,0xa8c6),(17,0xa8db)]:
            e,r=[fields(one(text,rf'^RREC_{phase} n={n} (.*)$')) for phase in ('ENTER','RETURN')]
            a,b=[fields(one(native_text,rf'^RREC_{phase} n={n} (.*)$')) for phase in ('ENTER','RETURN')]
            if a['trap']!=trap or e['trap']!=trap or b['sp']-a['sp']!=r['sp']-e['sp'] or b['d0']!=r['d0'] or b['memerr']:
                raise ValueError(f'native result/stack {n}')
            for reg in [f'd{i}' for i in range(3,8)]+[f'a{i}' for i in range(2,7)]:
                if e[reg]!=r[reg] or a[reg]!=b[reg]:raise ValueError(f'preserved {reg} at {n}')
            # FramePoly/CloseRgn scratch registers are overwritten before use
            # by the checked original caller; compare live preserved registers.
            if n<16:
                for reg in ('d1','d2'):
                    if a[reg]!=b[reg] or e[reg]!=r[reg]:raise ValueError('preserved '+reg)
            def nb(phase,kind):return (ROOT/'tmp'/f'regionrecord-native-{n}-{phase}-{kind}.bin').read_bytes()
            before=nb('ENTER','port');want=bytearray(before)
            reference_before=blob(f'{n}-ENTER-port');reference_after=blob(f'{n}-RETURN-port')
            for i,(old,new) in enumerate(zip(reference_before,reference_after)):
                if old!=new:want[i]=new
            if nb('RETURN','port')!=want or nb('RETURN','region')!=blob(f'{n}-RETURN-region'):
                raise ValueError(f'native region/port {n}')
            if b['size']!=len(nb('RETURN','region')):raise ValueError('native logical extent')
            if n==14 and b['a0']!=b['body']+10:raise ValueError('NewRgn body-end result')
            if n==15 and b['a0']!=b['port']:raise ValueError('OpenRgn port result')
        if (ROOT/'tmp/regionrecord-native-ENTER-pixels.bin').read_bytes()!=(ROOT/'tmp/regionrecord-native-RETURN-pixels.bin').read_bytes():
            raise ValueError('native framebuffer modified')
        if not re.search(r'^RREC_OWNER size=252 owned=1 frames=\d+ book=0$',native_text,re.M):
            raise ValueError('native ownership')


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--reference',type=Path);parser.add_argument('--status',type=int)
    parser.add_argument('--native',type=Path);parser.add_argument('--native-status',type=int)
    args=parser.parse_args()
    if args.reference and args.status is None:parser.error('--reference requires --status')
    if args.native and (not args.reference or args.native_status is None):parser.error('--native requires reference and native status')
    run(args.reference,args.status,args.native,args.native_status)
    print('PASS polygon region encoding: signed rectangle, atomic rejection'+
          ('; 11 exact original regions, caller bytes, recording state and pixel isolation' if args.reference else '')+
          ('; native bytes/ABI/ownership and pixel isolation' if args.native else ''))
