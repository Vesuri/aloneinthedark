#!/usr/bin/env python3
"""Compare the native inverse-ring helper with recorded Mac RGB results."""
from pathlib import Path
import os,re,struct,subprocess,tempfile
ROOT=Path(__file__).resolve().parents[1]
text=(ROOT/'tmp/m2-rgb-reference-final.log').read_text()
assert text.count('PASS original RGB colours and 64 fixtures')==1 and text.count('Exited via the debugger')==1 and 'FAIL' not in text
rows=[]
for line in text.splitlines():
    if not line.startswith('RGB_RETURN '):continue
    d=dict(re.findall(r'(\w+)=([^ ]+)',line));rgb=struct.unpack('>3H',bytes.fromhex(d['rgb']))
    value=int(d['fore' if d['trap']=='AA14' else 'back'],16)
    rows.append(' '.join(f'{v:x}' for v in (*rgb,value)))
with tempfile.TemporaryDirectory(prefix='aitd-rgb-') as work:
    exe=Path(work)/'test'
    subprocess.run([os.environ.get('HOST_CXX','c++'),'-std=c++17','-Wall','-Wextra','-Werror','-fsanitize=address,undefined',str(ROOT/'tools/test_rgb_lookup.cpp'),'-o',str(exe)],check=True)
    subprocess.run([str(exe),str(ROOT/'tmp/rgb-reference-clut.bin'),str(ROOT/'tmp/rgb-reference-inverse.bin')],input='\n'.join(rows)+'\n',text=True,check=True,timeout=30)
