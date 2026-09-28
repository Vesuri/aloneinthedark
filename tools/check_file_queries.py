#!/usr/bin/env python3
"""Require a completed byte-checked Mac File Manager query probe."""
import argparse
from pathlib import Path
import re
import unittest

def validate(text):
    if ('FAIL ' in text or 'Error in breakpoint' in text
            or text.count('PASS file-query capture complete')!=1
            or 'bytes=7008a2606004' not in text):
        raise ValueError('missing completion/original-byte proof or failed probe')
    rows=[]
    for line in text.splitlines():
        if line.startswith('FCBQUERY '):
            rows.append({key:int(value,16) for key,value in re.findall(r'(\w+)=([0-9A-Fa-f]+)',line)})
    if [r['stage'] for r in rows]!=list(range(6)):raise ValueError('query stages missing or duplicated')
    for r,error in zip(rows,[0,0,0,-38,-35,-51]):
        if r['d0']&65535!=error&65535 or r['result']!=error&65535:
            raise ValueError('wrong D0/ioResult for query stage')
    if rows[0]['index'] or rows[0]['eof']!=1424934:raise ValueError('application fork baseline absent')
    a,b=rows[1:3]
    if a['index']!=1 or a['volume'] or b['index']:raise ValueError('wrong index/exact arguments')
    if not a['ref'] or any(a[k]!=b[k] for k in ('ref','id','flags','eof','parent')):
        raise ValueError('indexed fork differs from exact reference lookup')
    if rows[3]['index']!=32767 or rows[3]['volume'] or rows[4]['index']!=1 or rows[4]['volume']!=0x1234:
        raise ValueError('error request arguments not captured')
    if rows[5]['index'] or rows[5]['ref'] or rows[5]['volume']!=0x1234:
        raise ValueError('invalid exact reference not captured')
    return 'PASS indexed-FCB reference: index/exact identity; exhausted=-38 volume=-35 reference=-51'

class Tests(unittest.TestCase):
    def fixture(self):
        rows=[]
        for stage,error,index,volume,ref,eof in ((0,0,0,0,128,1424934),(1,0,1,0,2,100),(2,0,0,0,2,100),
            (3,-38,32767,0,2,100),(4,-35,1,0x1234,2,100),(5,-51,0,0x1234,0,100)):
            rows.append(f'FCBQUERY stage={stage:X} d0={error&0xffffffff:X} result={error&65535:X} index={index:X} volume={volume:X} ref={ref:X} id=42 flags=300 eof={eof:X} parent=3')
        return 'ARM bytes=7008a2606004\n'+'\n'.join(rows)+'\nPASS file-query capture complete\n'
    def test_accept(self):self.assertIn('PASS',validate(self.fixture()))
    def test_reject(self):
        for before,after in [('PASS file-query capture complete',''),('bytes=7008a2606004',''),
            ('result=FFDA','result=FFCD'),('index=7FFF','index=3'),('stage=2','stage=1'),('ref=2 id=42','ref=0 id=42')]:
            with self.subTest(before=before),self.assertRaises(ValueError):validate(self.fixture().replace(before,after))

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('log',nargs='?',type=Path)
    p.add_argument('--selftest',action='store_true');p.add_argument('--status',type=int,default=0);a=p.parse_args()
    if a.selftest:return not unittest.TextTestRunner().run(unittest.defaultTestLoader.loadTestsFromTestCase(Tests)).wasSuccessful()
    if not a.log:p.error('log required')
    if a.status:raise SystemExit('FAIL file-queries: nonzero runner status')
    try:print(validate(a.log.read_text()))
    except (ValueError,KeyError) as e:raise SystemExit('FAIL file-queries: '+str(e))
if __name__=='__main__':raise SystemExit(main())
