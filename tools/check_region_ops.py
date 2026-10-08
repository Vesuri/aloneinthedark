#!/usr/bin/env python3
"""Check encoded-region Boolean operations; optionally compare Mac lamp captures."""
import argparse
import os
from pathlib import Path
import random
import struct
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SOURCE = r'''
#include <cstdio>
#include <cstdlib>
#include "src/mac/RegionOps.h"
#include "src/mac/FillRect8.h"
int main(int argc,char** argv) {
 uint8_t a[4096]={},b[4096]={},out[4096];uint16_t size=0;
 if(argc==3) {
  int d=atoi(argv[1]);WindowGeometry::word(a,10);WindowGeometry::word(a+2,20);
  WindowGeometry::word(a+4,10+d);WindowGeometry::word(a+6,20+d);
  if(!RegionOps::circle(a,out,sizeof out,size))return 2;
 } else {
  FILE* f=fopen(argv[1],"rb");if(!f)return 3;size_t na=fread(a,1,sizeof a,f);fclose(f);
  f=fopen(argv[2],"rb");if(!f)return 4;size_t nb=fread(b,1,sizeof b,f);fclose(f);
  if(atoi(argv[3])==4) {
   uint8_t rectangles[16];f=fopen(argv[4],"rb");if(!f)return 7;
   size_t n=fread(rectangles,1,sizeof rectangles,f);fclose(f);
   if(n!=16 || !RegionOps::map(a,na,rectangles,rectangles+8,out,sizeof out,size))return 8;
   fwrite(out,1,size,stdout);return 0;
  }
  if(atoi(argv[3])==5) {
   uint8_t map[8],port[8],vis[8],drawn[8],pixels[1920];
   int16_t m[]={-16,-16,24,24},p[]={-9,-7,19,15},v[]={-4,-10,22,18};
   for(unsigned i=0;i<4;++i) {WindowGeometry::word(map+i*2,m[i]);WindowGeometry::word(port+i*2,p[i]);WindowGeometry::word(vis+i*2,v[i]);}
   for(unsigned i=0;i<sizeof pixels;++i)pixels[i]=uint8_t(i);
   if(!FillRect8::solid(pixels,sizeof pixels,48,map,port,vis,map,a+2,77,drawn,a,na))return 6;
   fwrite(pixels,1,sizeof pixels,stdout);return 0;
  }
  if(!RegionOps::combine(a,na,b,nb,RegionOps::Operation(atoi(argv[3])),out,sizeof out,size))return 5;
 }
 fwrite(out,1,size,stdout);
}
'''


def encode(pixels):
    if not pixels:
        return struct.pack('>5h',10,0,0,0,0)
    top=min(y for x,y in pixels);bottom=max(y for x,y in pixels)+1
    left=min(x for x,y in pixels);right=max(x for x,y in pixels)+1
    if len(pixels)==(bottom-top)*(right-left):
        return struct.pack('>5h',10,top,left,bottom,right)
    words=[];previous=set()
    for y in range(top,bottom+1):
        edges=set()
        for x in range(left,right+1):
            if ((x,y) in pixels)!=((x-1,y) in pixels):edges.add(x)
        changes=sorted(edges^previous)
        if changes:words += [y,*changes,32767]
        previous=edges
    words.append(32767)
    return struct.pack('>'+str(5+len(words))+'h',10+2*len(words),top,left,bottom,right,*words)


def run(reference):
    with tempfile.TemporaryDirectory(prefix='aitd-region-ops-') as name:
        directory=Path(name);source=directory/'check.cpp';exe=directory/'check'
        source.write_text(SOURCE)
        subprocess.run([os.environ.get('CXX','c++'),'-std=c++11','-fsanitize=address,undefined',
                        '-I',str(ROOT),str(source),'-o',str(exe)],check=True)
        a=directory/'a';b=directory/'b';rectangles=directory/'rectangles'
        def combine(first,second,op):
            a.write_bytes(first);b.write_bytes(second)
            return subprocess.check_output([str(exe),str(a),str(b),str(op)])
        def mapping(region,source,target):
            a.write_bytes(region);b.write_bytes(encode(set()))
            rectangles.write_bytes(struct.pack('>8h',*source,*target))
            return subprocess.check_output([str(exe),str(a),str(b),'4',str(rectangles)])
        def coordinate(value,source,target,axis):
            num=(value-source[axis])*(target[axis+2]-target[axis])
            den=source[axis+2]-source[axis]
            return target[axis]+(1 if num>=0 else -1)*((abs(num)+den//2)//den)
        rng=random.Random(20261008)
        for n in range(100):
            sets=[]
            for operand in range(2):
                pixels=set()
                for _ in range(rng.randrange(5)):
                    x,y=rng.randrange(-12,12),rng.randrange(-12,12)
                    w,h=rng.randrange(1,10),rng.randrange(1,10)
                    pixels.update((xx,yy) for xx in range(x,x+w) for yy in range(y,y+h))
                sets.append(pixels)
            first,second=sets
            for op,expected in enumerate((first^second,first-second,first&second)):
                assert combine(encode(first),encode(second),op)==encode(expected),(n,op)
            painted=bytearray(i%256 for i in range(1920))
            for x,y in first:
                if -7<=x<15 and -4<=y<19:painted[(y+16)*48+x+16]=77
            assert combine(encode(first),encode(set()),5)==painted,('masked fill',n)
            source=(-7,-5,13,11);target=(-3,2,rng.randrange(0,30),rng.randrange(3,30))
            mapped=set()
            for x,y in first:
                for yy in range(coordinate(y,source,target,0),coordinate(y+1,source,target,0)):
                    for xx in range(coordinate(x,source,target,1),coordinate(x+1,source,target,1)):
                        mapped.add((xx,yy))
            assert mapping(encode(first),source,target)==encode(mapped),('mapping',n)
        # Bad lengths and unterminated complex streams cannot produce output.
        for invalid in (b'',b'\0\x0b'+bytes(9),struct.pack('>6h',12,0,0,1,1,0)):
            a.write_bytes(invalid);b.write_bytes(encode(set()))
            result=subprocess.run([str(exe),str(a),str(b),'0'],capture_output=True)
            assert result.returncode==5 and not result.stdout
        if reference:
            for d in (1,2,3,5,9,25,49,50,51,100):
                got=subprocess.check_output([str(exe),str(d),'circle'])
                assert got==(reference/f'oval-{d}x{d}.bin').read_bytes(),d
            assert mapping((reference/'maprgn-before.bin').read_bytes(),
                           struct.unpack('>4h',(reference/'maprgn-from.bin').read_bytes()),
                           struct.unpack('>4h',(reference/'maprgn-to.bin').read_bytes()))==(
                               reference/'maprgn-after.bin').read_bytes()
            current=(reference/'lamp-744fd8.bin').read_bytes()
            screen=(reference/'lamp-744fd4.bin').read_bytes()
            previous=(reference/'lamp-744fdc.bin').read_bytes()
            assert combine(current,screen,0)==(reference/'lamp-744fe0.bin').read_bytes()
            assert combine(previous,current,1)==(reference/'lamp-744fe4.bin').read_bytes()
    print('PASS region-ops: 300 Boolean, 100 scaling and 100 masked fill raster checks, invalid-stream rejection'
          + (', 10 original circles, lamp masks and scaled thumbnail' if reference else ''))


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--reference',type=Path)
    run(parser.parse_args().reference)
