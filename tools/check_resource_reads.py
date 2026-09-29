#!/usr/bin/env python3
"""Validate debugger-captured streamed resources against local original bytes."""
import argparse
import hashlib
import re
from pathlib import Path
from resource_fork import read_resource_fork
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--prepare',action='store_true');p.add_argument('--status',type=int,default=0);a=p.parse_args()
root=Path(__file__).resolve().parent.parent
files=[root/'tmp/resource-strs.bin',root/'tmp/resource-mctb.bin',root/'tmp/resource-general.bin']
if a.prepare:
    for path in files:path.unlink(missing_ok=True)
else:
    log=(root/'amiga/.run/gdb-out.log').read_text()
    modes=re.findall(r'^STARTUP_PREFS existing=([01]) windows=(75|101) services=(129/129|137/137)$',log,re.M)
    if len(modes)!=1 or modes[0] not in [('1','75','129/129'),('0','101','137/137')]:raise SystemExit('FAIL resource-read: missing/invalid starting preference fixture')
    marker=f'PASS resource-read: maps=243 preparation=201058 runtime=39/177820 windows={modes[0][1]} samples=3 next=NEWGWORLD'
    if a.status or log.count(marker)!=1 or any(bad in log for bad in ['FAIL','Error in sourced command file','Program received signal']):
        raise SystemExit('FAIL resource-read: runner, observer or completion')
    resources={(r.kind,r.rid):r.body for r in read_resource_fork(root/'amiga/.run/dh1/data/Alone In The Dark')}
    for key,path in zip([(b'STRS',0),(b'mctb',128),(b'STR#',128)],files):
        actual=path.read_bytes()
        if actual!=resources[key]:raise SystemExit('FAIL resource-read: sample differs from original '+str(key))
        print(f'PASS resource sample {key}: bytes={len(actual)} SHA256={hashlib.sha256(actual).hexdigest()}')
    print(marker)
