#!/usr/bin/env python3
"""Build the streaming serializer fixture and compare output with an independent reader."""
import argparse
import os
from pathlib import Path
import subprocess
import local_temp as tempfile
from resource_fork import read_resource_fork
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--original',type=Path);a=p.parse_args()
root=Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix='aitd-resource-writer-') as work:
    d=Path(work);exe=d/'test';out=d/'synthetic';empty=d/'empty'
    subprocess.run([os.environ.get('HOST_CXX','c++'),'-std=c++17','-Wall','-Wextra','-Werror','-include','cstdint','-fsanitize=address,undefined',str(root/'tools/test_resource_writer.cpp'),str(root/'src/mac/ResourceMap.cpp'),str(root/'src/mac/ResourceWriter.cpp'),'-o',str(exe)],check=True)
    cmd=[str(exe),str(out),str(empty)]
    if a.original:cmd += [str(a.original.resolve()),str(d/'original-copy')]
    subprocess.run(cmd,check=True,timeout=30)
    entries=read_resource_fork(out)
    expected=bytes((i*37+(i>>8))&255 for i in range(100003))
    assert [(r.kind,r.rid,r.attrs,r.name,r.body) for r in entries]==[(b'TEST',128,0x28,'Aé\0',expected),(b'TEST',-1,0x10,'',expected[17:20]),(b'OTHR',-3,0,'',b'')]
    assert [(r.kind,r.rid,r.attrs,r.name,r.body) for r in read_resource_fork(Path(str(out)+'.duplicates'))]==[(b'TEST',128,0x28,'Aé\0',expected),(b'TEST',128,0x10,'',expected[17:20]),(b'OTHR',-3,0,'',b'')]
    assert read_resource_fork(empty)==[]
    if a.original:
        assert read_resource_fork(a.original)==read_resource_fork(d/'original-copy')
        print('PASS resource writer independent original map/metadata/payload round trip')
    print('PASS resource writer independent synthetic/empty round trips')
