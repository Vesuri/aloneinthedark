#!/usr/bin/env python3
"""Inspect both dirty-close forks independently before the native fixture deletes them."""
from pathlib import Path
from resource_fork import read_resource_fork
root=Path(__file__).resolve().parent.parent/'amiga/.run/dh1/Saved Games'
try:
    for suffix,body in [('A',b'EEEE'),('B',b'FFFF')]:
        path=root/('Resource Dirty '+suffix)
        assert path.read_bytes()==b''
        assert [(r.kind,r.rid,r.attrs,r.name,r.body) for r in read_resource_fork(Path(str(path)+'.rsrc'))]==[(b'LIFE',128,0,'Scratch',body)]
        assert not any(Path(str(path)+'.rsrc'+s).exists() for s in ['.aitd-new','.aitd-old'])
except (AssertionError,OSError,ValueError) as e:raise SystemExit('FAIL resource dirty disk: '+str(e))
print('PASS resource dirty disk: exact EEEE/FFFF bodies, metadata and cleanup')
