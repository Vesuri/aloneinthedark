#!/usr/bin/env python3
"""Sanitize RGB memoization, table identities and invalidation contracts."""
import os
from pathlib import Path
import subprocess
import local_temp as tempfile
ROOT=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='aitd-rgb-cache-') as folder:
    exe=Path(folder)/'test'
    subprocess.run([os.environ.get('HOST_CXX','c++'),'-std=c++17','-Wall','-Wextra',
                    '-Werror','-fsanitize=address,undefined',
                    str(ROOT/'tools/test_rgb_cache.cpp'),'-o',str(exe)],check=True)
    subprocess.run([str(exe)],check=True,timeout=30)
print('PASS RGB cache: exact indices, collisions, relocated tables, seeds, headers, rebuilds and rejection')
