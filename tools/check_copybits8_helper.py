#!/usr/bin/env python3
import os, subprocess
import local_temp as tempfile
from pathlib import Path
root=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='aitd-copy8-') as d:
    exe=Path(d)/'test'
    subprocess.run([os.environ.get('HOST_CXX','c++'),'-std=c++17','-Wall','-Wextra','-Werror','-fsanitize=address,undefined',str(root/'tools/test_copybits8.cpp'),'-o',str(exe)],check=True)
    subprocess.run([str(exe)],check=True,timeout=30)
