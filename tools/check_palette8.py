#!/usr/bin/env python3
"""Sanitizer checks for the native eight-bit palette helper, without game data."""
import hashlib
import os
from pathlib import Path
import subprocess
import tempfile
ROOT=Path(__file__).resolve().parents[1]
SYSTEM_CLUT_SHA='8bde63f387a037ed68a9a1b659571162634834d079dd17e593df446b53aabb19'
def main():
    with tempfile.TemporaryDirectory(prefix='aitd-palette8-') as folder:
        exe=Path(folder)/'test'
        subprocess.run([os.environ.get('HOST_CXX','c++'),'-std=c++17','-Wall','-Wextra','-Werror','-fsanitize=address,undefined',str(ROOT/'tools/test_palette8.cpp'),'-o',str(exe)],check=True)
        subprocess.run([str(exe)],check=True,timeout=30)
        table=subprocess.run([str(exe),'--system-table'],check=True,timeout=30,stdout=subprocess.PIPE).stdout
        assert len(table)==2056 and table[:4]==bytes(4) and hashlib.sha256(table[4:]).hexdigest()==SYSTEM_CLUT_SHA
        print('PASS complete initial system colour table matches measured 256-entry digest')
if __name__=='__main__':main()
