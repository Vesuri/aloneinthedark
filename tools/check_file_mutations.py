#!/usr/bin/env python3
"""Check the bounded, scratch-only Mac File Manager mutation fixture."""
import argparse
from pathlib import Path
import re
import unittest

TRAPS=[0xa208,0xa215,0xa000,0xa012,0xa003,0xa011,0xa012,0xa260,0xa003,0xa260,
       0xa012,0xa002,0xa003,0xa013,0xa001,0xa000,0xa003,0xa012,0xa001,0xa009,0xa013]
CHECKS={5:{'actual':4,'position':12},6:{'misc':12},8:{'actual':2,'fcbmark':2},
        9:{'actual':0,'position':32},10:{'actual':32,'fcbmark':32},
        12:{'actual':20,'position':20},13:{'actual':4,'position':23},
        17:{'actual':0xdeadbeef},18:{'actual':0xdeadbeef}}

def validate(text,status=0):
    if (status or 'FAIL ' in text or 'Error in breakpoint' in text
            or text.count('PASS mutation capture complete; scratch file deleted')!=1
            or 'bytes=7008a2606004' not in text):
        raise ValueError('missing normal completion, byte proof or scratch cleanup')
    def rows(prefix):
        return [{k:int(v,16) for k,v in re.findall(r'(\w+)=([0-9A-Fa-f]+)',line)}
                for line in text.splitlines() if line.startswith(prefix)]
    calls=rows('MUTATION RETURN ');results=rows('MUTATION stage=')
    if ([r['stage'] for r in calls]!=list(range(1,22))
            or [r['stage'] for r in results]!=list(range(1,22))):
        raise ValueError('missing, duplicate or reordered calls')
    for n,(call,result,trap) in enumerate(zip(calls,results,TRAPS),1):
        expected=(-61 if n in (17,18) else 0)&65535
        if call['stub']!=trap or result['d0']&65535!=expected or result['result']!=expected:
            raise ValueError('trap/result mismatch')
        for key,value in CHECKS.get(n,{}).items():
            if result.get(key)!=value:raise ValueError(f'stage {n} {key} mismatch')
    return 'PASS mutation reference: write/EOF/mark/zero-count/permission/flush/close; scratch deleted'

class Tests(unittest.TestCase):
    def fixture(self):
        lines=['ARM bytes=7008a2606004']
        for n,trap in enumerate(TRAPS,1):
            error=(-61 if n in (17,18) else 0)&65535
            lines.append(f'MUTATION RETURN stage={n:X} stub={trap:X}')
            fields=' '.join(f'{k}={v:X}' for k,v in CHECKS.get(n,{}).items())
            lines.append(f'MUTATION stage={n:X} d0={error:X} result={error:X} {fields}')
        return '\n'.join(lines)+'\nPASS mutation capture complete; scratch file deleted\n'
    def test_accept(self):self.assertIn('PASS',validate(self.fixture()))
    def test_reject(self):
        for before,after in [('scratch file deleted',''),('bytes=7008a2606004',''),
                             ('stage=A','stage=9'),('actual=DEADBEEF','actual=0'),
                             ('stub=A003','stub=A002'),('result=FFC3','result=0')]:
            with self.subTest(before=before),self.assertRaises(ValueError):
                validate(self.fixture().replace(before,after))
        with self.assertRaises(ValueError):validate(self.fixture(),124)

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('log',type=Path,nargs='?');p.add_argument('--status',type=int,default=0)
    p.add_argument('--selftest',action='store_true');a=p.parse_args()
    if a.selftest:unittest.main(argv=['check_file_mutations'])
    elif a.log:
        try:print(validate(a.log.read_text(),a.status))
        except (ValueError,KeyError) as error:raise SystemExit('FAIL mutation reference: '+str(error))
    else:p.error('log or --selftest required')
