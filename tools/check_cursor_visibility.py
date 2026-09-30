#!/usr/bin/env python3
"""Run the runtime cursor state helper against measured Mac transitions."""
import argparse,os,re,subprocess,tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
ROWS=['O 0 0 1 1','I 1 0 0 0','O 0 0 1 1','O 0 0 1 0','S 1 0 0 0',
      'H 0 -1 0 0','O 0 -1 1 0','S 0 0 1 0','I 1 0 0 0','O 0 0 1 1','M 1 0 0 0']
def reference(text,status):
    if status!=0 or any(s in text for s in ('FAIL','LUA ERROR','timeout')):raise ValueError('reference completion')
    if text.count('PASS original ObscureCursor and nine fixtures plus mouse restoration')!=1 or text.count('Exited via the debugger')!=1:raise ValueError('positive completion')
    rows=re.findall(r'^CUR_RETURN n=(\d+) low=(\w+) ',text,re.M)
    moved=re.findall(r'^CUR_AFTER_MOVE n=10 low=(\w+) ',text,re.M)
    if len(rows)!=10 or len(moved)!=1:raise ValueError('state count')
    for i,((n,low),row) in enumerate(zip(rows+[('10',moved[0])],ROWS)):
        b=bytes.fromhex(low);op,vis,level,obscured,changed=row.split()
        if int(n)!=i or (b[0],int.from_bytes(b[4:6],'big',signed=True),b[6])!=(int(vis),int(level),int(obscured)):raise ValueError('measured cursor state')
    return True
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--reference',type=Path);p.add_argument('--status',type=int);a=p.parse_args()
    if a.reference:reference(a.reference.read_text(),a.status)
    with tempfile.TemporaryDirectory(prefix='aitd-cursor-') as work:
        exe=Path(work)/'check'
        subprocess.run([os.environ.get('HOST_CXX','c++'),'-std=c++17','-Wall','-Wextra','-Werror','-fsanitize=address,undefined',str(ROOT/'tools/test_cursor_visibility.cpp'),'-o',str(exe)],check=True)
        subprocess.run([str(exe)],input='\n'.join(ROWS)+'\n',text=True,check=True,timeout=30)
