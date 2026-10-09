#!/usr/bin/env python3
"""Build and run the portable zone allocator tests; optional host sanitizers."""
import argparse
import os
from pathlib import Path
import subprocess
import local_temp as tempfile

root = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--sanitize', action='store_true')
args = parser.parse_args()
with tempfile.TemporaryDirectory(prefix='aitd-heap-') as work:
    exe = str(Path(work)/'test')
    command = [os.environ.get('HOST_CXX','c++'),'-std=c++17','-Wall','-Wextra','-Werror']
    if args.sanitize:
        command += ['-fsanitize=address,undefined']
    command += [str(root/'tools/test_mac_heap.cpp'),str(root/'src/mac/MacHeap.cpp'),'-o',exe]
    subprocess.run(command,check=True)
    subprocess.run([exe],check=True,timeout=30)
