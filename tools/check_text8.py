#!/usr/bin/env python3
"""Exercise the intro text renderer with measured pen and buffer boundaries."""
import argparse
import os
from pathlib import Path
import subprocess
import local_temp as tempfile
from placeholder_font import build
parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--reference-dir',type=Path);args=parser.parse_args()
root=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='aitd-text8-') as work:
    work=Path(work);fond,nfnt=build()
    (work/'fond').write_bytes(fond);(work/'nfnt').write_bytes(nfnt)
    exe=work/'check'
    subprocess.run([os.environ.get('HOST_CXX','c++'),'-std=c++17','-Wall','-Wextra','-Werror','-fsanitize=address,undefined',str(root/'tools/test_text8.cpp'),'-o',str(exe)],check=True)
    command=[str(exe),str(work/'fond'),str(work/'nfnt')]
    if args.reference_dir:command.extend(str(args.reference_dir/name) for name in ('drawtext-reference-enter-pixels.bin','drawtext-reference-return-pixels.bin'))
    subprocess.run(command,check=True,timeout=30)
