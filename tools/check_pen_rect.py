#!/usr/bin/env python3
"""Validate direct solid particle pens with an independent per-pixel oracle."""
import os
from pathlib import Path
import subprocess
import local_temp as tempfile
root=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='aitd-pen-rect-') as folder:
    exe=Path(folder)/'test'
    subprocess.run([os.environ.get('HOST_CXX','c++'),'-std=c++17','-Wall','-Wextra','-Werror',
                    '-fsanitize=address,undefined',str(root/'tools/test_pen_rect.cpp'),'-o',str(exe)],check=True)
    subprocess.run([str(exe)],check=True,timeout=60)
