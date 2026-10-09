#!/usr/bin/env python3
"""Sanitize selective resource publication and independently inspect saved bodies."""
import os
from pathlib import Path
import subprocess
import local_temp as tempfile
from resource_fork import read_resource_fork
root=Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix='aitd-resource-publication-') as work:
    d=Path(work);exe=d/'test';first=d/'first';second=d/'second';peers=d/'peers';removed=d/'removed'
    subprocess.run([os.environ.get('HOST_CXX','c++'),'-std=c++17','-Wall','-Wextra','-Werror','-include','cstdint','-fsanitize=address,undefined',str(root/'tools/test_resource_publication.cpp'),*[str(root/'src/mac'/f) for f in ('ResourceMap.cpp','ResourceWriter.cpp','ResourceDirectory.cpp')],'-o',str(exe)],check=True)
    subprocess.run([str(exe),str(first),str(second),str(peers),str(removed)],check=True,timeout=30)
    for path,body in [(first,b'BBBB'),(second,b'DDD')]:
        assert [(r.kind,r.rid,r.attrs,r.name,r.body) for r in read_resource_fork(path)]==[(b'ISOL',128,0,'S',b'C'*70001),(b'ISOL',129,0,'S',body)]
    assert [(r.rid,r.name,r.body) for r in read_resource_fork(peers)]==[(128,'S',b'AAAA'),(129,'S',b'BBBB')]
    assert [(r.rid,r.name,r.body) for r in read_resource_fork(removed)]==[(128,'S',b'CCCC')]
    print('PASS unpublished peers: omitted body unread, identities/names retained, later publication/removal exact')
    print('PASS selective publication independent payload/name/order round trips')
