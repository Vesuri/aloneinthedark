#!/usr/bin/env python3
"""Verify the measured reuse of an inactive, already-realized palette."""
import argparse
import os
from pathlib import Path
import re
import struct
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def check(path, status, helper=False):
    text=path.read_text()
    if status != 0 or re.search(r'FAIL|LUA ERROR|TIMEOUT',text) or text.count('PASS original reactivated presentation palette')!=1 or text.count('Exited via the debugger')!=1:
        raise ValueError('original completion')
    data=lambda phase,kind:(ROOT/'tmp'/f'rebind-reference-{phase}-{kind}.bin').read_bytes()
    a,b=data('enter','palette'),data('return','palette')
    if len(a)!=4112 or len(b)!=4112 or struct.unpack_from('>II',a,4)!=(0xc003,0) or struct.unpack_from('>II',b,4)!=(0xc003,1):
        raise ValueError('realized inactive-to-active state')
    expected=bytearray(a);struct.pack_into('>I',expected,8,1)
    if b!=expected:raise ValueError('palette changes beyond active state')
    for kind in ('old','old-private'):
        if data('enter',kind)!=data('return',kind):raise ValueError('default palette preservation')
    if data('return','private')!=data('return','clut')[:4] or data('enter','private')==data('return','private'):
        raise ValueError('renewed private/device seed')
    a,b=data('enter','pixels'),data('return','pixels')
    if len(a)!=307200 or len(b)!=307200 or any(a[y*640+160:y*640+480]!=b[y*640+160:y*640+480] for y in range(150,350)):
        raise ValueError('client pixel preservation')
    if helper:
        with tempfile.TemporaryDirectory(prefix='aitd-rebind-') as work:
            exe=Path(work)/'test'
            subprocess.run([os.environ.get('HOST_CXX','c++'),'-std=c++17','-Wall','-Wextra','-Werror','-fsanitize=address,undefined',str(ROOT/'tools/test_palette8.cpp'),'-o',str(exe)],check=True)
            subprocess.run([str(exe),'--rebind',str(ROOT/'tmp')],check=True,timeout=30)
    print('PASS original palette reactivation: active state, complete CLUT/private seed, default palette and client preservation')


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('log',type=Path);parser.add_argument('--status',type=int,required=True)
    parser.add_argument('--helper',action='store_true');args=parser.parse_args()
    try:check(args.log,args.status,args.helper)
    except (ValueError,OSError) as error:raise SystemExit('FAIL palette reactivation: '+str(error))
