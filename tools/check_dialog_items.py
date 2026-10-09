#!/usr/bin/env python3
"""Exercise the native packed dialog item bounds."""
import os
from pathlib import Path
import subprocess
import local_temp as tempfile
root=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='aitd-dialog-') as work:
    exe=Path(work)/'check'
    subprocess.run([os.environ.get('HOST_CXX','c++'),'-std=c++17','-Wall','-Wextra','-Werror','-fsanitize=address,undefined',str(root/'tools/test_dialog_items.cpp'),'-o',str(exe)],check=True)
    subprocess.run([str(exe)],check=True,timeout=30)
