#!/usr/bin/env python3
"""Verify original GetMainDevice: stable main handle, port, device and registers."""
import argparse
import hashlib
from pathlib import Path
import re
import unittest
from resource_fork import read_resource_fork
from check_getgworld import fields,record
REGS=[f'd{i}' for i in range(8)]+[f'a{i}' for i in range(1,7)]
def original(path):
    body=next(r.body for r in read_resource_fork(path) if r.kind==b'CODE' and r.rid==7)
    if hashlib.sha256(body[0x477a:0x47c4]).hexdigest()!='1ac1a71b5441e6923cc0d7cde118e10e1ab1e490b74f9b1ece73d3ffd63df2a2':raise ValueError('original main-device/positioning bytes')
def check(text,status,native=False):
    if status!=0 or any(x in text for x in ('FAIL','[LUA ERROR]','unknown command','Error in','timeout','Program received signal')):raise ValueError('failed observer')
    for marker in (('PASS native GetMainDevice next=GETPIXBASEADDR','[Inferior 1 (Remote target) detached]') if native else ('PASS original GetMainDevice','Exited via the debugger')):
        if text.count(marker)!=1:raise ValueError('missing/duplicate completion')
    rows=[]
    for label in ('MAIN_ENTER','MAIN_RETURN'):
        found=re.findall('^'+label+r' (.*)$',text,re.M)
        if len(found)!=1:raise ValueError('paired-call coverage')
        rows.append(fields(found[0]))
    e,r=rows
    if e['opcode']!=0xaa2a285f or not e['main'] or r['result']!=e['main'] or r['sp']!=e['sp']:raise ValueError('caller/result/stack')
    if any(e[k]!=r[k] for k in REGS+['main','current','port']):raise ValueError('preserved registers/state')
    return rows

def paired(reference,status,native,native_status):
    check(reference,status);check(native,native_status,True)
    before=record(reference,'MAIN_BEFORE',62);after=record(reference,'MAIN_AFTER',62)
    if before!=after:raise ValueError('reference device mutated')
    a=Path('tmp/main-device-native-before.bin').read_bytes();b=Path('tmp/main-device-native-after.bin').read_bytes()
    if len(a)!=62 or a!=b:raise ValueError('native device mutated/extent')
    for start,end in ((4,6),(10,12),(20,22),(30,46)):
        if a[start:end]!=before[start:end]:raise ValueError('portable device fields')

class Checks(unittest.TestCase):
    def fixture(self):
        regs=' '.join(k+'=0' for k in REGS)
        return f'MAIN_ENTER sp=100 opcode=AA2A285F main=200 current=200 port=300 {regs}\nMAIN_RETURN sp=100 result=200 main=200 current=200 port=300 {regs}\nPASS original GetMainDevice\nExited via the debugger\n'
    def test_result_and_preservation(self):
        text=self.fixture();check(text,0)
        for old,new in [('result=200','result=201'),('MAIN_RETURN sp=100','MAIN_RETURN sp=104'),('opcode=AA2A285F','opcode=AA32285F'),('PASS original GetMainDevice',''),('port=300','port=301')]:
            changed=text.replace(old,new,1)
            with self.subTest(old=old),self.assertRaises(ValueError):check(changed,0)
        for status in (None,124):
            with self.assertRaises(ValueError):check(text,status)
        with self.assertRaises(ValueError):check(text.replace('port=300 d0=0','port=300 d0=1',1),0)

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('reference',nargs='?',type=Path);p.add_argument('--status',type=int);p.add_argument('--native',type=Path);p.add_argument('--native-status',type=int);p.add_argument('--selftest',action='store_true');a=p.parse_args()
    if a.selftest:raise SystemExit(not unittest.TextTestRunner().run(unittest.defaultTestLoader.loadTestsFromTestCase(Checks)).wasSuccessful())
    try:
        original(Path('tmp/runtime-data/Alone In The Dark'));check(a.reference.read_text(),a.status)
        if a.native:paired(a.reference.read_text(),a.status,a.native.read_text(),a.native_status)
        print('PASS GetMainDevice: original bytes, stable main handle/port/device, no argument cleanup, preserved registers')
    except (ValueError,OSError,KeyError,AttributeError) as e:raise SystemExit('FAIL GetMainDevice: '+str(e))
