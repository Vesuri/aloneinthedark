#!/usr/bin/env python3
"""Compare recorded lamp picture operations and source raster with the original Mac."""
import argparse
import os
from pathlib import Path
import shutil
import struct
import subprocess
import tempfile
from check_picture_record8 import ROOT, raster


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--reference',type=Path,required=True)
    parser.add_argument('--native',type=Path)
    args=parser.parse_args()
    with tempfile.TemporaryDirectory(prefix='aitd-lamp-picture-') as name:
        folder=Path(name);exe=folder/'check';out=folder/'picture.bin'
        for source,destination in [('src-map','enter-src-pm'),('src-colors','enter-src-clut'),
                                   ('src-pixels','enter-src-pixels'),('from','enter-from'),
                                   ('to','enter-to'),('to','frame'),('clip','clip')]:
            shutil.copy2(args.reference/f'lamp-pict-{source}.bin',
                         folder/f'pictrecord-reference-{destination}.bin')
        subprocess.run([os.environ.get('HOST_CXX','c++'),'-std=c++17','-Wall','-Wextra',
                        '-Werror','-fsanitize=address,undefined',str(ROOT/'tools/test_picture_record8.cpp'),
                        '-o',str(exe)],check=True)
        subprocess.run([str(exe),str(folder),str(out),'lamp'],check=True)
        original=raster(args.reference/'lamp-picture.bin',True);generated=raster(out,True)
        assert original[2:]==generated[2:],'picture operations/colours/rectangles/mode differ'
        top,left,bottom,right=original[2]
        for y in range(top,bottom):
            assert original[0][y-original[1][0]][left-original[1][1]:right-original[1][1]]==(
                generated[0][y-generated[1][0]][left-generated[1][1]:right-generated[1][1]])
        if args.native:
            recorded=raster(args.native/'lamp-picture.bin',True)
            assert recorded[3:5]==original[3:5]
            assert recorded[6]==original[6],'native background fill differs'
            # Independently map native source-region transitions, cancelling
            # coincident coordinates. This checks actual trap output in PICT.
            data=(args.native/'map-before.bin').read_bytes()
            words=struct.unpack('>'+str(len(data)//2)+'h',data)
            source=struct.unpack('>4h',(args.native/'map-from.bin').read_bytes())
            target=struct.unpack('>4h',(args.native/'map-to.bin').read_bytes())
            def coord(value,axis):
                n=(value-source[axis])*(target[axis+2]-target[axis]);d=source[axis+2]-source[axis]
                return target[axis]+(1 if n>=0 else -1)*((abs(n)+d//2)//d)
            transitions={};at=5
            while words[at]!=32767:
                y=coord(words[at],0);at+=1;row=transitions.setdefault(y,set())
                while words[at]!=32767:
                    row.symmetric_difference_update([coord(words[at],1)]);at+=1
                at+=1
            state=set();encoded=[];top=left=32767;bottom=0;right=-32768
            for y,changes in sorted(transitions.items()):
                if state:bottom=y
                state^=changes
                if state:top=min(top,y);left=min(left,min(state));right=max(right,max(state))
                if changes:encoded += [y,*sorted(changes),32767]
            assert not state
            encoded.append(32767)
            expected=struct.pack('>'+str(5+len(encoded))+'h',10+2*len(encoded),top,left,bottom,right,*encoded)
            assert recorded[7]==expected,'native mapped region differs'
    print('PASS lamp PICT: original fill, complex clip, raster, colour table and dither mode'
          + ('; native MapRgn result and recorded operations' if args.native else ''))


if __name__=='__main__':main()
