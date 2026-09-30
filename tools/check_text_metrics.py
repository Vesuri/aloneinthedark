#!/usr/bin/env python3
"""Check compiled native text metrics, optionally against measured Mac fixtures."""
import argparse,os,re,subprocess,tempfile
from pathlib import Path
from check_textwidth import check
root=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('--reference',type=Path);p.add_argument('--status',type=int);a=p.parse_args()
with tempfile.TemporaryDirectory(prefix='aitd-textwidth-') as folder:
    exe=Path(folder)/'test'
    subprocess.run([os.environ.get('HOST_CXX','c++'),'-std=c++17','-Wall','-Wextra','-Werror','-fsanitize=address,undefined',str(root/'tools/test_textwidth.cpp'),'-o',str(exe)],check=True)
    output=subprocess.check_output([str(exe)],text=True,timeout=30)
    if a.reference:
        reference=a.reference.read_text();check(reference,a.status)
        for label in ('TW_CHAR','TW_REPEAT'):
            def rows(text):return re.findall('^'+label+r' code=(\w+) width=(\w+)$',text,re.M)
            if rows(reference)!=rows(output):raise SystemExit('FAIL native text metrics differ from '+label)
print('PASS compiled text metrics: ranges, offset, zero/null and overflow guards'+('; all 529 Mac fixture results' if a.reference else ''))
