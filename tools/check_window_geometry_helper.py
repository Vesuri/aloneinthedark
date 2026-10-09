#!/usr/bin/env python3
"""Run sanitizer checks for window coordinate and structure-region helpers."""
import os
from pathlib import Path
import subprocess
import local_temp as tempfile
ROOT=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='aitd-window-geometry-') as directory:
    exe=Path(directory)/'test'
    subprocess.run([os.environ.get('HOST_CXX','c++'),'-std=c++17','-Wall','-Wextra','-Werror','-fsanitize=address,undefined',str(ROOT/'tools/test_window_geometry.cpp'),'-o',str(exe)],check=True)
    subprocess.run([str(exe)],check=True,timeout=30)
