#!/usr/bin/env python3
"""Independently inspect native saved mutation/isolation forks before deletion."""
import argparse
from pathlib import Path
from resource_fork import read_resource_fork
p=argparse.ArgumentParser(description=__doc__);p.add_argument('phase',choices=['mutation','isolation','rollback']);a=p.parse_args()
root=Path(__file__).resolve().parent.parent/'amiga/.run/dh1/Saved Games'
stem='Resource Mutation' if a.phase!='isolation' else 'Resource Isolation';path=root/stem
expected=[(b'RWRK',128,0,'Scratch',b'DDDD'),(b'RWRK',129,0,'Scratch',b'BBBB')] if a.phase=='mutation' else [(b'ISOL',128,0,'Scratch',b'EEEE'),(b'ISOL',129,0,'Scratch',b'FFFF')]
if a.phase=='rollback':expected=[]
try:
    assert path.read_bytes()==b''
    assert [(r.kind,r.rid,r.attrs,r.name,r.body) for r in read_resource_fork(Path(str(path)+'.rsrc'))]==expected
    assert not any(Path(str(path)+'.rsrc'+s).exists() for s in ['.aitd-new','.aitd-old'])
except (AssertionError,OSError,ValueError) as e:raise SystemExit('FAIL resource '+a.phase+' disk: '+str(e))
print('PASS resource '+a.phase+' disk: exact bodies/IDs/names/attributes/order, empty data fork, no transaction leftovers')
