#!/usr/bin/env python3
"""Verify mutable resource metadata and streamed round trips with sanitizers."""
import argparse
import os
from pathlib import Path
import subprocess
import local_temp as tempfile
from resource_fork import read_resource_fork
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--original',type=Path);a=p.parse_args()
root=Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix='aitd-resource-directory-') as work:
    exe=Path(work)/'test';out=Path(work)/'changed-fork'
    subprocess.run([os.environ.get('HOST_CXX','c++'),'-std=c++17','-Wall','-Wextra','-Werror','-include','cstdint','-fsanitize=address,undefined',str(root/'tools/test_resource_directory.cpp'),*[str(root/'src/mac'/f) for f in ('ResourceMap.cpp','ResourceWriter.cpp','ResourceDirectory.cpp')],'-o',str(exe)],check=True)
    cmd=[str(exe),str(out)]
    if a.original:cmd += [str(a.original.resolve()),str(Path(work)/'original-copy')]
    subprocess.run(cmd,check=True,timeout=30)
    if a.original:
        assert read_resource_fork(a.original)==read_resource_fork(Path(work)/'original-copy')
        print('PASS resource directory independent original round trip')
    assert [(r.kind,r.rid,r.attrs,r.name,r.body) for r in read_resource_fork(Path(str(out)+'.duplicates'))]==[(b'TEST',128,0x28,'Old',bytes([40])),(b'TEST',128,0x28,'Old',bytes([30]))]
    entries=read_resource_fork(out)
    assert [(r.kind,r.rid,r.attrs,r.name,r.body) for r in entries]==[(b'TEST',128,0x10,'New',bytes((i*19)&255 for i in range(70001))),(b'TEST',7,0,'',bytes((20,30)))]
    print('PASS resource directory independent changed/removed/added fork round trip')
