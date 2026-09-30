#!/usr/bin/env python3
"""Compare the native rectangle helper with measured original and fixture results."""
import os
from pathlib import Path
import subprocess
import tempfile
from check_unionrect import check,pairs,ROOT
text=(ROOT/'tmp/m2-unionrect-reference-final.log').read_text()
print(check(text,0))
rows=[]
for before,after in pairs(text):
    alias=1 if before['dst']==before['r1'] else 2 if before['dst']==before['r2'] else 0
    rows.append(' '.join([before['data1'],before['data2'],after['dest'],str(alias)]))
with tempfile.TemporaryDirectory(prefix='aitd-rect-') as work:
    exe=Path(work)/'check'
    subprocess.run([os.environ.get('HOST_CXX','c++'),'-std=c++17','-Wall','-Wextra','-Werror','-fsanitize=address,undefined',str(ROOT/'tools/test_rect_bounds.cpp'),'-o',str(exe)],check=True)
    subprocess.run([str(exe)],input='\n'.join(rows)+'\n',text=True,check=True,timeout=30)
