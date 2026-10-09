#!/usr/bin/env python3
"""Run the native SectRect helper against retained measured rectangle fixtures."""
import argparse, os, subprocess
import local_temp as tempfile
from pathlib import Path
from check_sectrect import check,pairs,ROOT
# Two original intersections followed by fourteen Mac edge/alias fixtures.
ROWS=['0000000001E00280 E0C0E0C01F401F40 0000000001E00280 0 1',
 '0000000001E00280 009600A0015E01E0 009600A0015E01E0 0 1',
 '00010002000A0014 00030004001E0028 00030004000A0014 0 1',
 'FFF6FFEC00000000 FFE2FFD8FFF1FFFB 0000000000000000 0 0',
 '0000000000000000 0002000300040005 0000000000000000 0 0',
 '0002000300040005 0000000000000000 0000000000000000 0 0',
 '0014001E0014001E 0002000300040005 0000000000000000 0 0',
 '0014001E000A000F 0002000300040005 0000000000000000 0 0',
 '0014001E000A000F 00280032001E002D 0000000000000000 0 0',
 '800080007FFF7FFF 0000000000010001 0000000000010001 0 1',
 '00010002000A0014 00030004001E0028 00030004000A0014 1 1',
 '00010002000A0014 00030004001E0028 00030004000A0014 2 1',
 '0007000800070009 0004000300040003 0000000000000000 0 0',
 '00000000000A000A 000A00000014000A 0000000000000000 0 0',
 '00000000000A000A 0000000A000A0014 0000000000000000 0 0',
 '00000000000A000A 00000000000A000A 00000000000A000A 0 1']
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--reference',type=Path);p.add_argument('--status',type=int);a=p.parse_args()
if a.reference:
    text=a.reference.read_text();check(text,a.status);measured=[]
    for e,r in pairs(text):
        alias=1 if e['dst']==e['r1'] else 2 if e['dst']==e['r2'] else 0
        measured.append(' '.join([e['data1'],e['data2'],r['dest'],str(alias),str(int(r['result'],16)>>8)]))
    if measured!=ROWS:raise SystemExit('FAIL retained SectRect fixtures differ from Mac')
with tempfile.TemporaryDirectory(prefix='aitd-sectrect-') as work:
    exe=Path(work)/'check'
    subprocess.run([os.environ.get('HOST_CXX','c++'),'-std=c++17','-Wall','-Wextra','-Werror','-fsanitize=address,undefined',str(ROOT/'tools/test_sectrect.cpp'),'-o',str(exe)],check=True)
    subprocess.run([str(exe)],input='\n'.join(ROWS)+'\n',text=True,check=True,timeout=30)
