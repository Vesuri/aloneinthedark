#!/usr/bin/env python3
"""Check the original size-choice path before implementing the fixed D4 policy."""
import argparse
import hashlib
from pathlib import Path
import re
import unittest
from resource_fork import read_resource_fork

RANGES=((3,0x4ea,0x53a,'f58bd7a1dff7b4d7876deedd8d0c2f6794ff940a8ef5d8b07d58bc937f0c976d'),
        (13,0x30a6,0x3148,'39fd9dc71afcdf273404dadf56611a5cb252824467d35cec23812a2bd1f433d0'),
        (8,0x820,0x860,'f6bd51a45fcac73d9847572d35dde13f007fc23f24772ccf9d76eff9908c97b9'),
        (8,0x938,0x970,'fa6d4b11c4865bbd89078c60680c23eeea4537edc81508fd9146ba4b863ebf7e'),
        (9,0x1070,0x109c,'474f8a03c2ddd2d18c9367305105c552f8e79613077ee7cb114d754752f9e5fe'))
def original(path):
    rows=read_resource_fork(path)
    for seg,start,end,digest in RANGES:
        body=next(r.body for r in rows if r.kind==b'CODE' and r.rid==seg)
        if hashlib.sha256(body[start:end]).hexdigest()!=digest:raise ValueError('original screen-choice bytes')
def check(text,status,expected):
    if status or any(x in text for x in ('FAIL','[LUA ERROR]','unknown command','Error in','timeout')):raise ValueError('failed observer')
    for marker in ('PASS original screen choice','Exited via the debugger'):
        if text.count(marker)!=1:raise ValueError('missing/duplicate completion')
    def one(pattern):
        rows=re.findall(pattern,text,re.M)
        if len(rows)!=1:raise ValueError('missing/duplicate evidence')
        return rows[0]
    before=bytes.fromhex(one(r'^CHOICE_PREF before=([0-9A-F]{20})$'))
    after=bytes.fromhex(one(r'^CHOICE_PREF after=([0-9A-F]{20})$'))
    if before[:4]!=bytes.fromhex('ff800001') or before[7]!=expected:raise ValueError('preference input')
    want=bytearray(before);want[7]=0
    if after!=want:raise ValueError('changed unrelated preferences or wrong size')
    if one(r'^CHOICE_DIALOG id=([0-9A-F]+)$')!='3E8':raise ValueError('dialog identity')
    items=[int(x,16) for x in re.findall(r'^CHOICE_ITEM item=([0-9A-F]+)$',text,re.M)]
    if not items or items[-1]!=2 or any(x!=0 for x in items[:-1]):raise ValueError('item selection')
    result,pref=one(r'^CHOICE_RESULT d0=([0-9A-F]+) pref=([0-9A-F]+)$')
    if int(result,16)&0xffff!=1-expected or int(pref,16)!=expected:raise ValueError('original result mapping')
    if one(r'^CHOICE_WINDOW id=([0-9A-F]+) opcode=([0-9A-F]+)$')!=('80','AA46'):raise ValueError('window selection')
    return before,after

class Checks(unittest.TestCase):
    def fixture(self,size):
        return f'''CHOICE_PREF before=FF8000010101010{size}0000
CHOICE_DIALOG id=3E8
CHOICE_ITEM item=0
CHOICE_ITEM item=2
CHOICE_RESULT d0=8000{1-size} pref={size}
CHOICE_PREF after=FF800001010101000000
CHOICE_WINDOW id=80 opcode=AA46
PASS original screen choice
Exited via the debugger
'''
    def test_inputs(self):
        for size in (0,1):check(self.fixture(size),0,size)
    def test_rejections(self):
        text=self.fixture(1)
        for old,new in [('id=80','id=84'),('item=2','item=1'),('d0=80000','d0=80001'),('after=FF800001010101000000','after=FF800001000101000000'),('PASS original screen choice',''),('CHOICE_DIALOG id=3E8','CHOICE_DIALOG id=3E8\nCHOICE_DIALOG id=3E8')]:
            with self.subTest(old=old),self.assertRaises(ValueError):check(text.replace(old,new),0,1)
        with self.assertRaises(ValueError):check(text,124,1)
        with self.assertRaises(ValueError):check(text,0,0)

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('log',nargs='?',type=Path);p.add_argument('--status',type=int);p.add_argument('--input',type=int,choices=(0,1));p.add_argument('--original',type=Path,default=Path('tmp/runtime-data/Alone In The Dark'));p.add_argument('--selftest',action='store_true');a=p.parse_args()
    if a.selftest:raise SystemExit(not unittest.TextTestRunner().run(unittest.defaultTestLoader.loadTestsFromTestCase(Checks)).wasSuccessful())
    try:
        original(a.original);check(a.log.read_text(),a.status,a.input)
        print('PASS screen choice: original bytes, item 2, only size byte changes, WIND 128')
    except (ValueError,OSError,AttributeError) as e:raise SystemExit('FAIL screen choice: '+str(e))
