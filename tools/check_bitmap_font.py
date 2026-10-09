#!/usr/bin/env python3
"""Exercise the native font parser against generated port-owned resources."""
import os
from pathlib import Path
import subprocess
import local_temp as tempfile
from placeholder_font import build
root=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='aitd-font-') as work:
    work=Path(work);fond,nfnt=build()
    (work/'fond').write_bytes(fond);(work/'nfnt').write_bytes(nfnt)
    exe=work/'check'
    subprocess.run([os.environ.get('HOST_CXX','c++'),'-std=c++17','-Wall','-Wextra','-Werror','-fsanitize=address,undefined',str(root/'tools/test_bitmap_font.cpp'),'-o',str(exe)],check=True)
    subprocess.run([str(exe),str(work/'fond'),str(work/'nfnt')],check=True,timeout=30)
