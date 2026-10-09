#!/usr/bin/env python3
"""Verify original indexed cursor inversion and the bounded native row helper."""
import argparse
import os
from pathlib import Path
import re
import subprocess
import local_temp as tempfile

ROOT=Path(__file__).resolve().parents[1]


def check(log,status,folder):
    if status!=0 or re.search(r'FAIL|LUA ERROR|TIMEOUT',log) or log.count('PASS original 256-index cursor inversion and restoration')!=1 or log.count('Exited via the debugger')!=1:
        raise ValueError('original completion')
    states=re.findall(r'^CURSOR_INVERT phase=(hidden|visible|restored) x=(\d+) y=(\d+) visible=(\d+) level=(-?\d+) obscured=(\d+)$',log,re.M)
    if len(states)!=3 or [r[0] for r in states]!=['hidden','visible','restored']:
        raise ValueError('original cursor state coverage')
    x,y=map(int,states[0][1:3])
    if not (0<=x<=624 and 0<=y<=464) or any(r[1:3]!=states[0][1:3] for r in states) or [r[3:] for r in states]!=[('0','-1','0'),('1','0','0'),('0','-1','0')]:
        raise ValueError('original position/visibility')
    data=lambda phase,kind:(folder/f'cursor-invert-reference-{phase}-{kind}.bin').read_bytes()
    if data('fixture','shape')!=bytes([255])*32+bytes(36):raise ValueError('original full inversion shape')
    before=data('hidden','pixels');after=data('visible','pixels');expected=bytearray(before)
    if len(before)!=307200 or len(after)!=307200:raise ValueError('screen extent')
    for row in range(16):
        for col in range(16):
            i=(y+row)*640+x+col
            if before[i]!=row*16+col:raise ValueError('all 256 fixture indices')
            expected[i]^=255
    if after!=expected or data('restored','pixels')!=before:raise ValueError('exact indexed inversion/restoration')
    clut=data('hidden','clut')
    if len(clut)!=2056 or any(data(phase,'clut')!=clut for phase in ('visible','restored')):
        raise ValueError('complete palette preservation')
    print('PASS original cursor: all 256 indices XOR 255, exact hide restoration, no other pixels or palette changes')


def helper():
    with tempfile.TemporaryDirectory(prefix='aitd-cursor-xor-') as folder:
        exe=Path(folder)/'test'
        subprocess.run([os.environ.get('HOST_CXX','c++'),'-std=c++17','-Wall','-Wextra','-Werror','-fsanitize=address,undefined',str(ROOT/'tools/test_cursor_invert.cpp'),'-o',str(exe)],check=True)
        subprocess.run([str(exe)],check=True,timeout=30)


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('log',type=Path,nargs='?')
    parser.add_argument('--status',type=int)
    parser.add_argument('--folder',type=Path,default=ROOT/'tmp')
    args=parser.parse_args()
    try:
        if args.log:check(args.log.read_text(),args.status,args.folder)
        helper()
    except (ValueError,OSError) as error:
        raise SystemExit('FAIL cursor XOR: '+str(error))
