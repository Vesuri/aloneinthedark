#!/usr/bin/env python3
"""Validate complete RGB24 copper bank encoding independently of the emulator."""
import os
from pathlib import Path
import subprocess
import local_temp as tempfile
ROOT = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='aitd-aga-palette-') as folder:
    exe = Path(folder)/'test'
    subprocess.run([os.environ.get('HOST_CXX', 'c++'), '-std=c++17', '-Wall',
                    '-Wextra', '-Werror', '-fsanitize=address,undefined',
                    str(ROOT/'tools/test_aga_palette.cpp'), '-o', str(exe)], check=True)
    subprocess.run([str(exe)], check=True, timeout=30)
