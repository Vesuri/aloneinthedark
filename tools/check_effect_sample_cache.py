#!/usr/bin/env python3
"""Sanitized ownership/content checks for the optional one-shot PCM cache."""
import os
from pathlib import Path
import subprocess
import local_temp as tempfile
root=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='aitd-effect-cache-') as folder:
    binary=Path(folder)/'check'
    subprocess.run([os.environ.get('CXX','c++'),'-std=c++17','-O2','-Wall','-Wextra',
        '-fsanitize=address,undefined','-I',str(root/'src'),
        str(root/'tools/test_effect_sample_cache.cpp'),'-o',str(binary)],check=True)
    subprocess.run([str(binary)],check=True)
