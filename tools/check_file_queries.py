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

def validate_directories(text):
    if ('FAIL ' in text or 'Error in breakpoint' in text
            or text.count('PASS directory-query capture complete')!=1
            or 'bytes=7008a2606004' not in text):
        raise ValueError('missing completed directory probe or original-byte proof')
    rows=[{k:int(v,16) for k,v in re.findall(r'(\w+)=([0-9A-Fa-f]+)',line)}
          for line in text.splitlines() if line.startswith('DIRQUERY ')]
    if [r['stage'] for r in rows]!=list(range(21)):raise ValueError('directory stages missing or duplicated')
    traps=[0xa260,0xa215,0xa214,0xa014,0xa260,0xa015,0xa214,0xa014,0xa260,0xa215,
           0xa214,0xa014,0xa260,0xa214,0xa014,0xa260,0xa260,0xa260,0xa260,0xa260,0xa215]
    for n,r in enumerate(rows):
        error={15:-35,16:-51,20:-43}.get(n,0)&65535
        if r['trap']!=traps[n] or r['d0']&65535!=error or r['result']!=error:
            raise ValueError('directory call/result mismatch')
    app=rows[1]['directory'];data=rows[8]['directory'];wd=rows[4]['volume']
    if app<3 or data<3 or app==data or wd in (0,65535) or rows[4]['created']!=1:
        raise ValueError('distinct application/new working directory absent')
    for n,directory,ref in ((2,app,65535),(3,app,65535),(6,data,wd),(7,data,wd),
                            (10,data,65535),(11,data,65535),(13,data,65535),(14,data,65535)):
        if rows[n]['directory']!=directory or rows[n]['volume']!=ref:
            raise ValueError('default reference or directory identity mismatch')
    for n in (2,6,10):
        if rows[n]['process']!=0xdeadbeef or rows[n]['wdvolume']!=65535:
            raise ValueError('HGetVol must preserve process field and return actual volume')
    if rows[1]['volume']!=65535 or rows[9]['volume']!=wd or rows[9]['directory'] or rows[20]['directory']!=0x9999:
        raise ValueError('HSetVol arguments not captured')
    if rows[8]['process']!=0x41495444 or rows[18]['directory']!=2 or rows[19]['directory']!=2:
        raise ValueError('WD query identity or volume-root result mismatch')
    return 'PASS directory reference: HSetVol separates ID/ref; HGetVol preserves process; close/errors measured'

def validate_wd(text):
    if ('FAIL ' in text or 'Error in breakpoint' in text or text.count('PASS wd-query capture complete')!=1
            or 'bytes=7008a2606004' not in text):raise ValueError('missing completed WD probe')
    rows=[{k:int(v,16) for k,v in re.findall(r'(\w+)=([0-9A-Fa-f]+)',line)}
          for line in text.splitlines() if line.startswith('WDQUERY ')]
    if [r['stage'] for r in rows]!=list(range(27)):raise ValueError('WD stages missing or duplicated')
    errors={4:-35,10:-35,14:-35,15:-51,17:-35,18:-35,19:-35,20:-35,22:-35,23:-51,24:-51}
    for n,r in enumerate(rows):
        error=errors.get(n,0)&65535
        if r['d0']&65535!=error or r['result']!=error or r['trap']!={11:0xa015,13:0xa214}.get(n,0xa260):
            raise ValueError('WD trap/result mismatch')
    app=rows[1]['volume'];wd=rows[5]['volume'];directory=rows[8]['directory']
    if rows[1]['created'] or rows[2]['volume']!=0x8053 or rows[2]['process']!=0x4552494b:
        raise ValueError('application/System WD baseline absent')
    if rows[5]['created']!=1 or rows[6]['created'] or rows[6]['volume']!=wd:
        raise ValueError('reopened directory did not reuse WD')
    if rows[6]['process']!=0x41495445 or rows[7]['process']!=0x41495444:
        raise ValueError('first-open process identity not preserved')
    for n in (7,8,9,13):
        if rows[n]['volume']!=wd or rows[n]['directory']!=directory:
            raise ValueError('WD/default directory identity mismatch')
    if rows[9]['index']!=1 or rows[9]['process']!=0x41495444 or rows[10]['process']!=0x41495445:
        raise ValueError('positive/negative process filter evidence absent')
    if rows[13]['process']!=0xdeadbeef or rows[21]['index']!=65535 or rows[21]['directory']!=2 or rows[21]['volume']!=65535:
        raise ValueError('closed-default or negative-index evidence absent')
    if rows[26]['volume']!=app or rows[26]['directory']!=rows[1]['directory']:
        raise ValueError('application WD did not survive close')
    return 'PASS WD reference: System identity, reuse, process filter, closed default, errors, protected application'

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

class DirectoryTests(unittest.TestCase):
    def fixture(self):
        traps=[0xa260,0xa215,0xa214,0xa014,0xa260,0xa015,0xa214,0xa014,0xa260,0xa215,
               0xa214,0xa014,0xa260,0xa214,0xa014,0xa260,0xa260,0xa260,0xa260,0xa260,0xa215]
        lines=['ARM bytes=7008a2606004']
        for n,trap in enumerate(traps):
            error={15:-35,16:-51,20:-43}.get(n,0)&65535
            ref=0x8300 if n in (4,5,6,7,8,9,12,15,16) else 65535
            directory=10 if n in (1,2,3) else 2 if n in (18,19) else 0 if n==9 else 0x9999 if n==20 else 11
            process=0xdeadbeef if n in (2,6,10) else 0x41495444
            lines.append(f'DIRQUERY stage={n:X} trap={trap:X} d0={error:X} result={error:X} volume={ref:X} created=1 directory={directory:X} process={process:X} wdvolume=FFFF')
        return '\n'.join(lines)+'\nPASS directory-query capture complete\n'
    def test_accept_and_mutations(self):
        text=self.fixture();self.assertIn('PASS',validate_directories(text))
        for before,after in [('process=DEADBEEF','process=0'),('volume=8300','volume=FFFF'),
            ('result=FFD5','result=FF88'),('stage=A','stage=B')]:
            with self.subTest(before=before),self.assertRaises(ValueError):validate_directories(text.replace(before,after))
    def test_incomplete(self):
        for text in ('', 'ARM bytes=7008a2606004\nPASS directory-query capture complete\n'):
            with self.assertRaises(ValueError):validate_directories(text)


class WDTests(unittest.TestCase):
    def fixture(self):
        lines=['ARM bytes=7008a2606004']
        for n in range(27):
            error={4:-35,10:-35,14:-35,15:-51,17:-35,18:-35,19:-35,20:-35,22:-35,23:-51,24:-51}.get(n,0)&65535
            trap={11:0xa015,13:0xa214}.get(n,0xa260)
            ref=0x8053 if n==2 else 0x8043 if n in (1,26) else 65535 if n==21 else 0x8063
            process=0x4552494b if n==2 else 0x41495445 if n in (6,10) else 0xdeadbeef if n==13 else 0x41495444
            directory=10 if n in (1,26) else 2 if n==21 else 11
            index=65535 if n==21 else 1 if n in (9,10) else 0
            lines.append(f'WDQUERY stage={n:X} trap={trap:X} d0={error:X} result={error:X} volume={ref:X} created={int(n==5):X} process={process:X} directory={directory:X} index={index:X}')
        return '\n'.join(lines)+'\nPASS wd-query capture complete\n'
    def test_evidence(self):
        text=self.fixture();self.assertIn('PASS',validate_wd(text))
        for before,after in [('created=1','created=0'),('process=4552494B','process=0'),
            ('process=41495445','process=41495444'),('result=FFCD','result=FFDD'),('PASS wd-query capture complete','')]:
            with self.subTest(before=before),self.assertRaises(ValueError):validate_wd(text.replace(before,after))


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('log',nargs='?',type=Path)
    p.add_argument('--wd',action='store_true');p.add_argument('--directories',action='store_true');p.add_argument('--selftest',action='store_true');p.add_argument('--status',type=int,default=0);a=p.parse_args()
    if a.selftest:return not unittest.TextTestRunner().run(unittest.TestSuite([unittest.defaultTestLoader.loadTestsFromTestCase(t) for t in (Tests,DirectoryTests,WDTests)])).wasSuccessful()
    if not a.log:p.error('log required')
    if a.status:raise SystemExit('FAIL file-queries: nonzero runner status')
    try:print((validate_wd if a.wd else validate_directories if a.directories else validate)(a.log.read_text()))
    except (ValueError,KeyError) as e:raise SystemExit('FAIL file-queries: '+str(e))
if __name__=='__main__':raise SystemExit(main())
