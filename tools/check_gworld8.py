#!/usr/bin/env python3
"""Run sanitizer checks for eight-bit offscreen layout helpers."""
import os
import sys
from pathlib import Path
import subprocess
import tempfile
ROOT=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='aitd-gworld8-') as directory:
    exe=Path(directory)/'test'
    subprocess.run([os.environ.get('HOST_CXX','c++'),'-std=c++17','-Wall','-Wextra','-Werror','-fsanitize=address,undefined',str(ROOT/'tools/test_gworld8.cpp'),'-o',str(exe)],check=True)
    subprocess.run([str(exe)],check=True,timeout=30)
    if '--reference' in sys.argv:
        output=Path(directory)/'inverse.bin'
        subprocess.run([str(exe),str(ROOT/'tmp/gworld-reference-clut.bin'),str(output)],check=True,timeout=30)
        expected=(ROOT/'tmp/gworld-reference-aux-device-inverse.bin').read_bytes()
        assert output.read_bytes()[:4364]==expected[:4364], 'Mac inverse table/header/collision mismatch'
        print('PASS original inverse table: 4096 entries, header and 256 collision links')
print("PASS GWorld8: measured layout, all valid stride widths, range rejection, exact PixMap bytes and write bounds")
