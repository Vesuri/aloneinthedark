#!/usr/bin/env python3
"""Inspect only the paired Resource Manager fixture's persisted scratch forks."""
from pathlib import Path
from resource_fork import read_resource_fork
root=Path(__file__).resolve().parent.parent/'amiga/.run/dh1/Saved Games'
try:
    for letter,rows in [('A',[(b'STR#',128,b'AAAA'),(b'RPRB',7,b'7777'),(b'RPRB',1,b'1111')]),
                        ('B',[(b'STR#',128,b'BBBB'),(b'RPRB',2,b'2222'),(b'RPRB',7,b'wwww')])]:
        path=root/('Resource Probe '+letter)
        if path.read_bytes()!=b'':raise ValueError('data fork changed')
        resources=read_resource_fork(Path(str(path)+'.rsrc'))
        if [(r.kind,r.rid,r.attrs,r.name,r.body) for r in resources]!=[(kind,rid,0,'General',body) for kind,rid,body in rows]:
            raise ValueError('resource metadata/order/body mismatch')
        for suffix in ['.rsrc.aitd-new','.rsrc.aitd-old']:
            if Path(str(path)+suffix).exists():raise ValueError('transaction leftover')
    print('PASS resource files disk: six exact resources, names/IDs/order, independent data forks, no transaction leftovers')
except (OSError,ValueError) as error:
    raise SystemExit('FAIL resource files disk: '+str(error))
