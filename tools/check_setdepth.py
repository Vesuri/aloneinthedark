#!/usr/bin/env python3
"""Validate original SetDepth's already-active eight-bit-mode contract."""
import argparse
import hashlib
from pathlib import Path
import re
import unittest
from resource_fork import read_resource_fork

REFERENCE='PASS setdepth reference calls=1 inflight=0 secondTimes=14'
NATIVE='PASS native SetDepth calls=1 next=DETACHRESOURCE'
PRESERVED=[f'd{n}' for n in range(3,8)]+[f'a{n}' for n in range(2,7)]
def original(path):
    core=next(r.body for r in read_resource_fork(path) if r.kind==b'CODE' and r.rid==3)
    if hashlib.sha256(core[0x4e2:0x512]).hexdigest()!='e9d2370d895b2f494aaea85cc9b863e890ee5d7da757ab15ab7b893548d04a29':raise ValueError('original SetDepth request bytes')
def fields(line):return {k:int(v,16) for k,v in re.findall(r'(\w+)=([0-9A-F]+)(?= |$)',line)}
def check(text,status,native=False):
    marker=NATIVE if native else REFERENCE
    if status!=0 or any(s in text for s in ('FAIL','[LUA ERROR]','unknown command','Error in','Program received signal','timeout')):raise ValueError('failed observer')
    for value in (marker,'DEPTH_SITE bytes=AAA22079 before=303C0A13','[Inferior 1 (Remote target) detached]' if native else 'Exited via the debugger'):
        if text.count(value)!=1:raise ValueError('missing/duplicate completion')
    data={}
    for tag in ('DEPTH_ENTER','DEPTH_RETURN'):
        rows=[l for l in text.splitlines() if l.startswith(tag+' ')]
        if len(rows)!=1:raise ValueError('paired call coverage')
        data[tag]=fields(rows[0])
        if tag=='DEPTH_ENTER':data['args']=bytes.fromhex(re.search(r'args=([0-9A-F/]+)',rows[0])[1].replace('/',''))
    e=data['DEPTH_ENTER'];r=data['DEPTH_RETURN']
    if e['seq']!=1 or r['seq']!=1 or e['d0']&0xffff!=0xa13 or data['args'][:6]!=bytes.fromhex('000100010008') or not int.from_bytes(data['args'][6:10],'big'):raise ValueError('request contract')
    if r['result']!=0 or r['d0']!=0 or r['sp']!=e['sp']+10 or r['expected']!=r['sp']:raise ValueError('OSErr/stack contract')
    if any(e[k]!=r[k] for k in PRESERVED):raise ValueError('preserved registers')
    if not native:
        for tag,size in (('GD',62),('PM',50),('CT',8)):
            before=re.findall(r'^'+tag+'_BEFORE seq=1 data=([0-9A-F]+)$',text,re.M)
            after=re.findall(r'^'+tag+'_AFTER seq=1 data=([0-9A-F]+)$',text,re.M)
            if len(before)!=1 or len(after)!=1:raise ValueError('record coverage')
            a,b=bytes.fromhex(before[0])[:size],bytes.fromhex(after[0])[:size]
            if len(a)!=size or len(b)!=size or a!=b:raise ValueError('device mutation')
            data[tag]=a
        if data['GD'][34:46]!=bytes.fromhex('0000000001e0028000000083') or data['PM'][4:14]!=bytes.fromhex('82800000000001e00280') or data['PM'][30:38]!=bytes.fromhex('0000000800010008') or data['CT'][4:8]!=bytes.fromhex('800000ff'):raise ValueError('fixed mode layout')
    return data

def reference(text,status):
    data=check(text,status)
    before=Path('tmp/setdepth-reference-before.clut').read_bytes();after=Path('tmp/setdepth-reference-after.clut').read_bytes()
    if len(before)!=2056 or before!=after or before[:8]!=data['CT']:raise ValueError('full reference color table changed')
    return data

def native(text,status,ref):
    data=check(text,status,True)
    before={}
    for tag,size in (('gd',62),('pm',50),('ct',2056),('pixels',307200)):
        a=Path('tmp/setdepth-native-before-'+tag+'.bin').read_bytes();b=Path('tmp/setdepth-native-after-'+tag+'.bin').read_bytes()
        if len(a)!=size or a!=b:raise ValueError('native '+tag+' extent or mutation')
        before[tag]=a
    gd,pm,ct=before['gd'],before['pm'],before['ct']
    for offset,length in ((4,2),(10,2),(20,2),(30,4),(34,8),(42,4)):
        if gd[offset:offset+length]!=ref['GD'][offset:offset+length]:raise ValueError('paired GDevice layout')
    if pm[4:42]!=ref['PM'][4:42] or pm[46:50]!=ref['PM'][46:50] or ct[4:8]!=ref['CT'][4:8]:raise ValueError('paired PixMap/CLUT header')
    if data['args'][:6]!=ref['args'][:6]:raise ValueError('paired request')

class Checks(unittest.TestCase):
    def test_native_selector_word(self):
        regs=''.join(' '+r+'=00000000' for r in PRESERVED)
        text=(NATIVE+'\nDEPTH_SITE bytes=AAA22079 before=303C0A13\n'
              '[Inferior 1 (Remote target) detached]\n'
              'DEPTH_ENTER seq=1 sp=1000 args=00010001/00080000/20000000 d0=ABCD0A13'+regs+'\n'
              'DEPTH_RETURN seq=1 sp=100A expected=100A result=0 d0=00000000'+regs+'\n')
        check(text,0,True)
        for bad in (text.replace('ABCD0A13','ABCD0A12'),text.replace('result=0','result=1'),text.replace('expected=100A','expected=1008')):
            with self.assertRaises(ValueError):check(bad,0,True)
    def test_incomplete(self):
        for marker in (REFERENCE,NATIVE):
            for status in (0,None,124):
                with self.assertRaises(ValueError):check(marker,status,marker==NATIVE)
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('log',type=Path,nargs='?');p.add_argument('--status',type=int);p.add_argument('--native',type=Path);p.add_argument('--native-status',type=int);p.add_argument('--selftest',action='store_true');a=p.parse_args()
    if a.selftest:raise SystemExit(not unittest.TextTestRunner().run(unittest.defaultTestLoader.loadTestsFromTestCase(Checks)).wasSuccessful())
    try:
        original(Path('tmp/runtime-data/Alone In The Dark'));text=a.log.read_text();ref=reference(text,a.status)
        for bad,status in ((text,124),(text,None),(text.replace(REFERENCE,''),0),(text+REFERENCE,0),(text.replace('result=0','result=1'),0),(text.replace('args=00010001','args=00000001'),0)):
            try:check(bad,status)
            except ValueError:continue
            raise ValueError('reference rejection fixture passed')
        if a.native:
            native_text=a.native.read_text();native(native_text,a.native_status,ref)
            for bad,status in ((native_text,124),(native_text,None),(native_text.replace(NATIVE,''),0),(native_text+NATIVE,0),(native_text.replace('result=0','result=1'),0)):
                try:check(bad,status,True)
                except ValueError:continue
                raise ValueError('native rejection fixture passed')
        print('PASS SetDepth: original bytes, depth 8/flags 1/values 1, zero OSErr, stack/registers, stable device and full CLUT'+('; native records and 307200 pixels unchanged' if a.native else ''))
    except (OSError,ValueError,KeyError,AttributeError) as error:raise SystemExit('FAIL SetDepth: '+str(error))
