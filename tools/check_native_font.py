#!/usr/bin/env python3
"""Accept both original GetFNum calls and exact installed font resources."""
import argparse
import hashlib
from pathlib import Path
import re
import unittest
from placeholder_font import build
from check_font_lookup import check_original
from check_native_driver import check as check_driver
from resource_fork import read_resource_fork

ROOT=Path(__file__).resolve().parents[1]
FILES=[ROOT/'tmp/font-native-fond.bin',ROOT/'tmp/font-native-nfnt.bin']
def check(text, status):
    check_driver(text, status)
    if 'DIAGNOSTIC' in text:
        raise ValueError('diagnostic is not acceptance')
    first = re.findall(r'^PASS font first: Dan1\+0014 result=20 stack=\$([0-9a-fA-F]{8}) D0=\$00000000$', text, re.M)
    abi = re.findall(r'^PASS font second ABI: D0=\$[0-9a-fA-F]{8} preserved stack-pop=8 ResErr=0 MemErr=0$', text, re.M)
    if len(first) != 1 or not int(first[0], 16) or len(abi) != 1:
        raise ValueError('original font results/stack/D0/errors')
    if not text.index('PASS font first:') < text.index('PASS font second:') < text.index(abi[0]) < text.index('MLIST_NEXT'):
        raise ValueError('original font call order')

def check_driver_source(path):
    core=next(r.body for r in read_resource_fork(path) if r.kind==b'CODE' and r.rid==3)
    for start,end,digest in ((0x10cc,0x114c,'d03e649634914302762a0a3477fb28c6025efd1081c2b0d79579d36261bdf8e9'),(0x1cbe,0x1cf8,'eb6f9bdf7537d3f83c5fd4a8bacc4e0c5ee760a032285ef543f2f12ebbb98f1c')):
        if hashlib.sha256(core[start:end]).hexdigest()!=digest:raise ValueError('original Jnth/MDRV loader or entry-store bytes')

class Checks(unittest.TestCase):
    def test_completion(self):
        from check_native_driver import CALLS, ENDPOINT, GUARD, DETACHED
        first = 'PASS font first: Dan1+0014 result=20 stack=$00600000 D0=$00000000'
        second = 'PASS font second: Dan1+003A result=20 stack=$00600000 native-driver-calls=2'
        abi = 'PASS font second ABI: D0=$12345678 preserved stack-pop=8 ResErr=0 MemErr=0'
        good = '\n'.join([first] + CALLS + [second, abi, ENDPOINT, GUARD, DETACHED])
        check(good, 0)
        rejected = [(good, 124), (good, None), (good.replace('result=20', 'result=0'), 0),
                    (good.replace('ResErr=0', 'ResErr=-192'), 0),
                    (good.replace('stack-pop=8', 'stack-pop=4'), 0),
                    (good.replace('MemErr=0', 'MemErr=-108'), 0),
                    (good + '\nError in sourced command file', 0)]
        for marker in (first, second, abi):
            rejected.extend([(good.replace(marker, ''), 0), (good + '\n' + marker, 0)])
        for text, status in rejected:
            with self.subTest(text=text, status=status), self.assertRaises(ValueError):
                check(text, status)

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
            print('PASS both native font lookups: original bytes/results/ABI and exact installed FOND/NFNT; next DETACHRESOURCE')
        except (ValueError,OSError,AttributeError) as error:raise SystemExit('FAIL native font: '+str(error))
