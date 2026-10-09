#!/usr/bin/env python3
"""Build and run the independent eight-bit planar conversion checks."""
import os
from pathlib import Path
import subprocess
import local_temp as tempfile
ROOT = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='aitd-planar8-') as folder:
    exe = Path(folder)/'test'
    subprocess.run([os.environ.get('HOST_CXX', 'c++'), '-std=c++17', '-Wall',
                    '-Wextra', '-Werror', '-fsanitize=address,undefined',
                    str(ROOT/'tools/test_planar8.cpp'), '-o', str(exe)], check=True)
    subprocess.run([str(exe)], check=True, timeout=30)
