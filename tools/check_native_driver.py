#!/usr/bin/env python3
"""Accept native driver initialization; the second Times call remains pending."""
import argparse
from pathlib import Path
import unittest
from check_driver_startup import check_call_source

CALLS=['PASS native driver call: selector=21 D0=0 D1=0 preserved=13 stack=unchanged rate=22 voices=6/2/2',
       'PASS native driver call: selector=24 D0=0 D1=1 preserved=13 stack=unchanged rate=11 voices=6/2/2']
COMPLETE='PASS native driver startup: Jnth=11 calls=2 first-Times=20 second=pending-menu next=COUNTMITEMS original-MDRV=absent'
def check(text,status):
    if status!=0 or any(bad in text for bad in ('FAIL','Error in sourced command file','Program received signal','timeout')):
        raise ValueError('runner/observer completion')
    for marker in CALLS+[COMPLETE]:
        if text.count(marker)!=1:raise ValueError('missing/duplicate positive control')
    if not text.index(CALLS[0])<text.index(CALLS[1])<text.index(COMPLETE):raise ValueError('call order')

class Checks(unittest.TestCase):
    def test_required_calls(self):
        good='\n'.join(CALLS+[COMPLETE]);check(good,0)
        for bad,status in ((good,124),(good,None),(good.replace(CALLS[0],''),0),(good+COMPLETE,0),(good+'\nFAIL',0),(good.replace('D1=1','D1=0'),0),('\n'.join(CALLS[::-1]+[COMPLETE]),0)):
            with self.assertRaises(ValueError):check(bad,status)
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('log',type=Path,nargs='?');p.add_argument('--status',type=int);p.add_argument('--selftest',action='store_true');a=p.parse_args()
    if a.selftest:raise SystemExit(not unittest.TextTestRunner().run(unittest.defaultTestLoader.loadTestsFromTestCase(Checks)).wasSuccessful())
    try:
        source=Path(__file__).resolve().parents[1]/'tmp/runtime-data/Alone In The Dark'
        check_call_source(source);check(a.log.read_text(),a.status)
        print(COMPLETE)
    except (ValueError,OSError,AttributeError) as error:raise SystemExit('FAIL native driver: '+str(error))
