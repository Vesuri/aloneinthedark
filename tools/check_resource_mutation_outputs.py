#!/usr/bin/env python3
"""Independently inspect native saved mutation/isolation forks before deletion."""
import argparse
from pathlib import Path
from resource_fork import read_resource_fork
p=argparse.ArgumentParser(description=__doc__);p.add_argument('phase',choices=['permissions','mutation','isolation','rollback','map-selected','map-peers','map-final','map-rollback-empty','map-rollback-peers']);a=p.parse_args()
root=Path(__file__).resolve().parent.parent/'amiga/.run/dh1/Saved Games'
stem='Resource Permissions' if a.phase=='permissions' else 'Resource Map Edits' if a.phase.startswith('map-') else 'Resource Mutation' if a.phase!='isolation' else 'Resource Isolation';path=root/stem
expected=[(b'RWRK',128,0,'Scratch',b'DDDD'),(b'RWRK',129,0,'Scratch',b'BBBB')] if a.phase=='mutation' else [(b'ISOL',128,0,'Scratch',b'EEEE'),(b'ISOL',129,0,'Scratch',b'FFFF')]
if a.phase=='permissions':expected=[(b'RPRM',128,0,'Scratch',b'ABCD')]
if a.phase.startswith('map-'):
    expected=[(b'ISOL',128,0,'Scratch',b'CCCC' if a.phase=='map-final' else b'AAAA')]
    if a.phase in ('map-peers','map-rollback-peers'):expected.append((b'ISOL',129,0,'Scratch',b'BBBB'))
if a.phase in ('rollback','map-rollback-empty'):expected=[]
try:
    assert path.read_bytes()==b''
    assert [(r.kind,r.rid,r.attrs,r.name,r.body) for r in read_resource_fork(Path(str(path)+'.rsrc'))]==expected
    assert not any(Path(str(path)+'.rsrc'+s).exists() for s in ['.aitd-new','.aitd-old'])
except (AssertionError,OSError,ValueError) as e:raise SystemExit('FAIL resource '+a.phase+' disk: '+str(e))
print('PASS resource '+a.phase+' disk: exact bodies/IDs/names/attributes/order, empty data fork, no transaction leftovers')
