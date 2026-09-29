#!/usr/bin/env python3
"""Check bounded original and scratch GetFNum reference captures."""
import argparse
import hashlib
from pathlib import Path
import re
import unittest
from resource_fork import read_resource_fork

ARM='ARM font lookup dispatcher bytes=2f0a2f02246f000a; Dan1 live jump-table attribution'
ORIGINAL='PASS original font lookup complete'
FIXTURE='PASS font lookup fixture complete'

def check_original(path):
    body=next(r.body for r in read_resource_fork(path) if r.kind==b'CODE' and r.rid==12)
    if hashlib.sha256(body[4:0x3a]).hexdigest()!='4dc53d56f934a717f86412d91bdb85c20dd43ec89943f1f1dc5b0f05eb727450':
        raise ValueError('original Dan1 font lookup bytes')

def fields(line):
    return {k:int(v,16) for k,v in re.findall(r'(\w+)=([0-9A-F]+)(?: |$)',line)}

def check(text,status,fixture=False):
    complete=FIXTURE if fixture else ORIGINAL
    if status!=0 or any(s in text for s in ('FAIL ', 'LUA ERROR', 'Error in breakpoint', 'FONT_WAIT', 'timeout')):
        raise ValueError('failed or incomplete reference run')
    if text.count(complete)!=1 or text.count(ARM)!=1 or (ORIGINAL if fixture else FIXTURE) in text:
        raise ValueError('missing/duplicate/wrong completion')
    rows=[line for line in text.splitlines() if line.startswith(('FONT_ORIGINAL ', 'FONT_CASE '))]
    offsets=(0x12,) if fixture else (0x12,0x38)
    if len(rows)!=(10 if fixture else 4):raise ValueError('call count')
    for i,offset in enumerate(offsets):
        e,r=rows[2*i:2*i+2];entry,result=fields(e),fields(r)
        if not e.startswith('FONT_ORIGINAL entry=') or not r.startswith('FONT_ORIGINAL return='):raise ValueError('call ordering')
        if entry.get('entry')!=offset or entry.get('name')!=0x0554696d or entry.get('tail')!=0x6573 or entry.get('bytes')!={0x12:0x4a6efffe,0x38:0x3f3c0005}[offset]:raise ValueError('original call attribution/name/bytes')
        if not entry.get('out') or entry['sp']+8!=result.get('sp') or result['sp']!=result.get('expected'):raise ValueError('original stack contract')
        if result.get('return')!=offset+2 or result.get('result')!=20 or result.get('res')!=0 or result.get('mem')!=0 or result.get('d0')!=entry.get('d0'):raise ValueError('original result/register contract')
    if fixture:
        for n,line in enumerate(rows[2:],1):
            r=fields(line)
            expected={'stage':n,'result':20 if n<=4 else 0,'before':0xabcd,'after':0xdcba,'d0':0x12345678,'res':0 if n<=4 else 0xff40,'mem':0x7777 if n<=4 or n==6 else 0}
            if not line.startswith('FONT_CASE ') or any(r.get(k)!=v for k,v in expected.items()) or not r.get('sp') or r['sp']!=r.get('expected'):raise ValueError('fixture result/guards/register/stack contract')
    if text.index(complete)<text.index(rows[-1]):raise ValueError('early completion')

class Checks(unittest.TestCase):
    def test_reject_incomplete(self):
        rows=[ARM]
        for offset,code in ((0x12,0x4a6efffe),(0x38,0x3f3c0005)):
            rows += [f'FONT_ORIGINAL entry={offset:X} out=1020 name=0554696D tail=6573 sp=1000 bytes={code:08X} d0=1234',f'FONT_ORIGINAL return={offset+2:X} result=0014 d0=1234 res=0000 mem=0000 sp=1008 expected=1008']
        rows += [ORIGINAL];good='\n'.join(rows);check(good,0)
        for bad,status in ((good,124),(good,None),(good.replace(ORIGINAL,''),0),(good+'\n'+ORIGINAL,0),(good+'\nFAIL error',0),(good.replace('result=0014','result=0000'),0),(good.replace('expected=1008','expected=1000'),0),(good.replace('name=0554696D','name=00000000'),0),(good.replace('bytes=4A6EFFFE','bytes=00000000'),0)):
            with self.assertRaises(ValueError):check(bad,status)
        with self.assertRaises(ValueError):check(good,0,True)
    def test_fixture_guards(self):
        rows=[ARM,'FONT_ORIGINAL entry=12 out=1020 name=0554696D tail=6573 sp=1000 bytes=4A6EFFFE d0=0','FONT_ORIGINAL return=14 result=0014 d0=0 res=0000 mem=0000 sp=1008 expected=1008']
        for n in range(1,9):
            rows.append(f'FONT_CASE stage={n:X} result={20 if n<=4 else 0:04X} before=ABCD after=DCBA d0=12345678 res={0 if n<=4 else 0xff40:04X} mem={0x7777 if n<=4 or n==6 else 0:04X} sp=2000 expected=2000')
        rows.append(FIXTURE);good='\n'.join(rows);check(good,0,True)
        for bad in (good.replace('before=ABCD','before=CCCC'),good.replace('stage=8','stage=7'),good.replace('res=FF40','res=0000'),good.replace('mem=7777','mem=0000')):
            with self.assertRaises(ValueError):check(bad,0,True)

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('log',nargs='?',type=Path);p.add_argument('--status',type=int);p.add_argument('--fixture',action='store_true');p.add_argument('--selftest',action='store_true');p.add_argument('--original',type=Path,default=Path('tmp/runtime-data/Alone In The Dark'));a=p.parse_args()
    if a.selftest:raise SystemExit(not unittest.TextTestRunner().run(unittest.defaultTestLoader.loadTestsFromTestCase(Checks)).wasSuccessful())
    try:
        check_original(a.original);check(a.log.read_text(),a.status,a.fixture)
        print('PASS font lookup: '+('eight reference fixtures' if a.fixture else 'both original Dan1 calls')+', original bytes, results, stack and D0')
    except (ValueError,OSError,StopIteration,KeyError,AttributeError) as error:raise SystemExit('FAIL font lookup: '+str(error))
