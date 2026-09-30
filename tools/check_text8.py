#!/usr/bin/env python3
"""Exercise the intro text renderer with measured pen and buffer boundaries."""
import os
from pathlib import Path
import subprocess
import tempfile
from placeholder_font import build
root=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='aitd-text8-') as work:
    work=Path(work);fond,nfnt=build()
    (work/'fond').write_bytes(fond);(work/'nfnt').write_bytes(nfnt)
    exe=work/'check'
    subprocess.run([os.environ.get('HOST_CXX','c++'),'-std=c++17','-Wall','-Wextra','-Werror','-fsanitize=address,undefined',str(root/'tools/test_text8.cpp'),'-o',str(exe)],check=True)
    subprocess.run([str(exe),str(work/'fond'),str(work/'nfnt')],check=True,timeout=30)
