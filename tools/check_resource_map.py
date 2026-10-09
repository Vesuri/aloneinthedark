#!/usr/bin/env python3
"""Build the map-only parser fixture; optionally compare an original fork oracle."""
import argparse
import os
from pathlib import Path
import subprocess
import local_temp as tempfile
from resource_fork import read_resource_fork
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--original',type=Path);a=p.parse_args()
root=Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix='aitd-resource-map-') as work:
    exe=str(Path(work)/'test')
    subprocess.run([os.environ.get('HOST_CXX','c++'),'-std=c++17','-Wall','-Wextra','-Werror','-include','cstdint','-fsanitize=address,undefined',str(root/'tools/test_resource_map.cpp'),str(root/'src/mac/ResourceMap.cpp'),'-o',exe],check=True)
    result=subprocess.run([exe]+([str(a.original)] if a.original else []),check=True,capture_output=True,text=True,timeout=30)
    if a.original:
        expected=[]
        for r in read_resource_fork(a.original):
            digest=2166136261
            for byte in r.body:digest=((digest^byte)*16777619)&0xffffffff
            expected.append(f'RESOURCE {int.from_bytes(r.kind,"big"):08x} {r.rid} {r.attrs} {len(r.body)} {digest:08x} {r.name.encode("mac_roman").hex()}')
        if [line for line in result.stdout.splitlines() if line.startswith('RESOURCE ')]!=expected:
            raise SystemExit('FAIL original resource map: Python oracle mismatch')
    print('\n'.join(line for line in result.stdout.splitlines() if line.startswith('PASS ')))
