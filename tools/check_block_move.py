#!/usr/bin/env python3
"""Overlap, alignment and length boundaries for the native block-copy algorithm."""
import os
from pathlib import Path
import subprocess
import local_temp as tempfile
ROOT = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='aitd-block-move-') as folder:
    source=Path(folder)/'check.cpp'
    binary=Path(folder)/'check'
    source.write_text('''#include <cstdio>
#include "src/mac/BlockMoveBytes.h"
#include "src/mac/BlockMoveChecks.h"
int main() {
 auto n=BlockMoveChecks::run(BlockMoveBytes::move);
 printf("BlockMove checks: %u\\n",n);
 return n==28388 ? 0 : 1;
}
''')
    subprocess.run([os.environ.get('CXX','c++'),'-std=c++17','-O2','-Wall','-Wextra',
                    '-fsanitize=address,undefined','-iquote',str(ROOT),str(source),'-o',str(binary)],check=True)
    subprocess.run([str(binary)],check=True)
