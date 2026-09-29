#!/usr/bin/env python3
"""Accept the first original GetFNum and explicit graphics stop, not the second call."""
import argparse
import hashlib
from pathlib import Path
import re
import unittest
from placeholder_font import build
from check_font_lookup import check_original
from resource_fork import read_resource_fork

MARKER='PASS font startup prerequisite: first Times=20 overlay=31/80800 next=AEINSTALLEVENTHANDLER; second call pending graphics services'
ROOT=Path(__file__).resolve().parents[1]
FILES=[ROOT/'tmp/font-native-fond.bin',ROOT/'tmp/font-native-nfnt.bin']
def check(text,status):
    if status!=0 or text.count(MARKER)!=1 or any(s in text for s in ('FAIL','Error in sourced command file','Program received signal','DIAGNOSTIC','timeout')):
        raise ValueError('runner/observer/positive completion')
    rows=re.findall(r'^PASS font first: Dan1\+0014 result=20 stack=\$([0-9a-fA-F]+) D0=\$00000000$',text,re.M)
    if len(rows)!=1 or not int(rows[0],16):raise ValueError('original first result/stack/D0')

def check_driver_source(path):
    core=next(r.body for r in read_resource_fork(path) if r.kind==b'CODE' and r.rid==3)
    for start,end,digest in ((0x10cc,0x114c,'d03e649634914302762a0a3477fb28c6025efd1081c2b0d79579d36261bdf8e9'),(0x1cbe,0x1cf8,'eb6f9bdf7537d3f83c5fd4a8bacc4e0c5ee760a032285ef543f2f12ebbb98f1c')):
        if hashlib.sha256(core[start:end]).hexdigest()!=digest:raise ValueError('original Jnth/MDRV loader or entry-store bytes')

class Checks(unittest.TestCase):
    def test_completion(self):
        good='PASS font first: Dan1+0014 result=20 stack=$00600000 D0=$00000000\n'+MARKER
        check(good,0)
        for bad,status in ((good,124),(good,None),(good.replace(MARKER,''),0),(good+'\n'+MARKER,0),(good.replace('result=20','result=0'),0),(good+'\nError in sourced command file',0)):
            with self.assertRaises(ValueError):check(bad,status)

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('log',type=Path,nargs='?');p.add_argument('--status',type=int);p.add_argument('--prepare',action='store_true');p.add_argument('--selftest',action='store_true');a=p.parse_args()
    if a.selftest:raise SystemExit(not unittest.TextTestRunner().run(unittest.defaultTestLoader.loadTestsFromTestCase(Checks)).wasSuccessful())
    if a.prepare:
        for path in FILES:path.unlink(missing_ok=True)
    else:
        try:
            check_original(ROOT/'tmp/runtime-data/Alone In The Dark');check_driver_source(ROOT/'tmp/runtime-data/Alone In The Dark');check(a.log.read_text(),a.status)
            for path,body in zip(FILES,build()):
                if path.read_bytes()!=body:raise ValueError('installed font body differs: '+path.name)
            print('PASS native first font lookup: original bytes/result and exact installed FOND/NFNT; second original call remains pending')
        except (ValueError,OSError,AttributeError) as error:raise SystemExit('FAIL native font: '+str(error))
