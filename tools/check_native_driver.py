#!/usr/bin/env python3
"""Accept integrated native driver initialization through the second Times lookup."""
import argparse
import re
from pathlib import Path
import unittest

CALLS=['PASS native driver call: selector=21 D0=0 D1=0 preserved=13 stack=unchanged rate=22 voices=6/2/2',
       'PASS native driver call: selector=24 D0=0 D1=1 preserved=13 stack=unchanged rate=11 voices=6/2/2']
SECOND = r'PASS font second: Dan1\+003A result=20 stack=\$[0-9a-fA-F]{8} native-driver-calls=2'
ENDPOINT = 'MLIST_NEXT state=3 trap=A886 selector=FFFFFFFF segment=12 offset=216 manager=QUICKDRAW routine=TEXTWIDTH windows=113 services=211/211 reads=62 bytes=265454'
GUARD = 'PASS menu-list next-stop original-MDRV=absent'
DETACHED = '[Inferior 1 (Remote target) detached]'
COMPLETE = 'PASS native driver startup: Jnth=11 calls=2 second-Times=20 next=TEXTWIDTH original-MDRV=absent'

def check(text, status):
    if status != 0 or any(bad in text for bad in ('FAIL', 'Error in sourced command file', 'Program received signal', 'timeout')):
        raise ValueError('runner/observer completion')
    second = re.findall(SECOND, text)
    if len(second) != 1:
        raise ValueError('missing/duplicate second Times lookup')
    markers = CALLS + second + [ENDPOINT, GUARD, DETACHED]
    for marker in markers:
        if text.count(marker) != 1:
            raise ValueError('missing/duplicate positive control')
    positions = [text.index(marker) for marker in markers]
    if positions != sorted(positions):
        raise ValueError('call/completion order')

class Checks(unittest.TestCase):
    def test_required_calls(self):
        second = 'PASS font second: Dan1+003A result=20 stack=$005f6d9e native-driver-calls=2'
        markers = CALLS + [second, ENDPOINT, GUARD, DETACHED]
        good = '\n'.join(markers)
        check(good, 0)
        rejected = [(good, 124), (good, None), (good + '\nFAIL', 0),
                    (good.replace('D1=1', 'D1=0'), 0),
                    (good.replace('result=20', 'result=0'), 0),
                    (good.replace('native-driver-calls=2', 'native-driver-calls=1'), 0),
                    (good.replace('services=211/211', 'services=211/210'), 0),
                    ('\n'.join(CALLS[::-1] + markers[2:]), 0),
                    ('\n'.join([second] + CALLS + markers[3:]), 0)]
        for marker in markers:
            rejected.extend([(good.replace(marker, ''), 0), (good + '\n' + marker, 0)])
        for text, status in rejected:
            with self.subTest(text=text, status=status), self.assertRaises(ValueError):
                check(text, status)
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('log',type=Path,nargs='?');p.add_argument('--status',type=int);p.add_argument('--selftest',action='store_true');a=p.parse_args()
    if a.selftest:raise SystemExit(not unittest.TextTestRunner().run(unittest.defaultTestLoader.loadTestsFromTestCase(Checks)).wasSuccessful())
    try:
        source=Path(__file__).resolve().parents[1]/'tmp/runtime-data/Alone In The Dark'
        from check_driver_startup import check_call_source
        check_call_source(source);check(a.log.read_text(),a.status)
        print(COMPLETE)
    except (ValueError,OSError,AttributeError) as error:raise SystemExit('FAIL native driver: '+str(error))
