#!/usr/bin/env python3
"""Run sanitizer checks for eight-bit offscreen layout helpers."""
import os
import sys
from pathlib import Path
import subprocess
import tempfile
import re
ROOT=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='aitd-gworld8-') as directory:
    exe=Path(directory)/'test'
    subprocess.run([os.environ.get('HOST_CXX','c++'),'-std=c++17','-Wall','-Wextra','-Werror','-fsanitize=address,undefined',str(ROOT/'tools/test_gworld8.cpp'),'-o',str(exe)],check=True)
    subprocess.run([str(exe)],check=True,timeout=30)
    if '--pixel-reference' in sys.argv:
        text=(ROOT/'tmp/m2-pixbase-reference-copy.log').read_text()
        rows={phase:{k:int(v,16) for k,v in re.findall(r'(\w+)=([\dA-Fa-f]+)',line)}
              for phase,line in re.findall(r'^PBASE phase=(\S+) (.*)$',text,re.M)}
        pixel_handle=int.from_bytes((ROOT/'tmp/pixbase-reference-unlocked-before-pm.bin').read_bytes()[:4],'big')
        for phase in ['locked','unlocked']:
            e,r=rows[phase+'-before'],rows[phase+'-after']
            pm=(ROOT/f'tmp/pixbase-reference-{phase}-before-pm.bin').read_bytes()
            args=[int.from_bytes(pm[14:16],'big'),int.from_bytes(pm[:4],'big'),pixel_handle,e['pixels'],e['pm'],phase=='locked',e['D0']]
            output=subprocess.check_output([str(exe),'--pixel-address']+[f'{int(v):x}' for v in args],text=True)
            assert [int(x,16) for x in output.split()]==[r[k] for k in ['result','D0','A0','A1']]
        print('PASS original locked/unlocked pixel-address helper contracts')
    if '--reference' in sys.argv or '--device-reference' in sys.argv:
        prefix='gworld-device-reference' if '--device-reference' in sys.argv else 'gworld-reference'
        output=Path(directory)/'inverse.bin'
        subprocess.run([str(exe),str(ROOT/f'tmp/{prefix}-clut.bin'),str(output)],check=True,timeout=30)
        expected=(ROOT/f'tmp/{prefix}-aux-device-inverse.bin').read_bytes()
        assert output.read_bytes()[:4364]==expected[:4364], 'Mac inverse table/header/collision mismatch'
        print('PASS original inverse table: 4096 entries, header and 256 collision links')
print("PASS GWorld8: measured layout, all valid stride widths, range rejection, exact PixMap bytes, pixel-address contracts and write bounds")
