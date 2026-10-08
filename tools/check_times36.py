#!/usr/bin/env python3
"""Compare the compiled Times36 renderer with the original pause-draw capture."""
import argparse,os,subprocess,tempfile
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--reference-dir',type=Path,required=True);a=p.parse_args()
root=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='aitd-times36-') as work:
    exe=Path(work)/'check'
    subprocess.run([os.environ.get('HOST_CXX','c++'),'-std=c++17','-Wall','-Wextra','-Werror','-fsanitize=address,undefined',str(root/'tools/test_times36.cpp'),'-o',str(exe)],check=True)
    subprocess.run([str(exe),str(a.reference_dir)],check=True,timeout=30)
