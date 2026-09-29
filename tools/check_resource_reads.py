#!/usr/bin/env python3
"""Validate debugger-captured streamed resources against local original bytes."""
import argparse
import hashlib
from pathlib import Path
from resource_fork import read_resource_fork
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--prepare',action='store_true');p.add_argument('--status',type=int,default=0);a=p.parse_args()
root=Path(__file__).resolve().parent.parent
files=[root/'tmp/resource-strs.bin',root/'tmp/resource-mctb.bin',root/'tmp/resource-general.bin']
if a.prepare:
    for path in files:path.unlink(missing_ok=True)
else:
    log=(root/'amiga/.run/gdb-out.log').read_text()
    marker='PASS resource-read: maps=212 preparation=201058 runtime=16/96648 windows=16 samples=3 next=GETFNUM'
    if a.status or log.count(marker)!=1 or any(bad in log for bad in ['FAIL','Error in sourced command file','Program received signal']):
        raise SystemExit('FAIL resource-read: runner, observer or completion')
    resources={(r.kind,r.rid):r.body for r in read_resource_fork(root/'amiga/.run/dh1/data/Alone In The Dark')}
    for key,path in zip([(b'STRS',0),(b'mctb',128),(b'STR#',128)],files):
        actual=path.read_bytes()
        if actual!=resources[key]:raise SystemExit('FAIL resource-read: sample differs from original '+str(key))
        print(f'PASS resource sample {key}: bytes={len(actual)} SHA256={hashlib.sha256(actual).hexdigest()}')
    print(marker)
