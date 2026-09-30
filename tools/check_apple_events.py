#!/usr/bin/env python3
"""Verify original startup Apple Event registrations and the separate table fixture."""
import argparse
import hashlib
from pathlib import Path
import re
import struct
import unittest
from resource_fork import read_resource_fork
from check_getgworld import fields
from check_choice_services import one, PRESERVED
SITES=(0x1038,0x1056,0x1074,0x1092)
IDS=(0x6f617070,0x70646f63,0x6f646f63,0x71756974)
CALLBACKS=(0xac2,0xac2,0xad2,0xaca)
# label, selector, class, ID, callback offset (None means lookup), refCon, system,
# expected OSErr, returned callback offset, returned refCon.
CASES=tuple((f'original-{eid:08x}',0x921,0x61657674,eid,None,0,0,0,cb,0) for eid,cb in zip(IDS,CALLBACKS))+(
 ('absent',0x921,0x61697464,0x70726231,None,0,0,0xf94b,None,None),
 ('install',0x91f,0x61697464,0x70726231,0xac2,0x12345678,0,0,None,None),
 ('get-installed',0x921,0x61697464,0x70726231,None,0,0,0,0xac2,0x12345678),
 ('replace-refcon',0x91f,0x61697464,0x70726231,0xac2,0xcafebabe,0,0,None,None),
 ('get-refcon',0x921,0x61697464,0x70726231,None,0,0,0,0xac2,0xcafebabe),
 ('replace-handler',0x91f,0x61697464,0x70726231,0xaca,0xaabbccdd,0,0,None,None),
 ('get-handler',0x921,0x61697464,0x70726231,None,0,0,0,0xaca,0xaabbccdd),
 ('other-class',0x921,0x61697465,0x70726231,None,0,0,0xf94b,None,None),
 ('system-separate',0x921,0x61697464,0x70726231,None,0,1,0xf94b,None,None),
 ('null-handler',0x91f,0x61697464,0x70726231,0,0,0,0xffce,None,None),
 ('get-after-null',0x921,0x61697464,0x70726231,None,0,0,0,0xaca,0xaabbccdd),
 ('odd-handler',0x91f,0x61697464,0x70726231,0xac3,0,0,0xffce,None,None),
 ('get-after-odd',0x921,0x61697464,0x70726231,None,0,0,0,0xaca,0xaabbccdd))
def original(path):
    b=next(r.body for r in read_resource_fork(path) if r.kind==b'CODE' and r.rid==7)
    if hashlib.sha256(b[0x1000:0x1096]).hexdigest()!='08e0465b1dca0398dd3c55550ceb5b09e10c36360dc48f6b02630d7851e5438e':raise ValueError('original registration bytes')
def paired(e,r,seq):
    if e['seq']!=seq or r['seq']!=seq or r['sp']!=e['sp']+18 or any(e[k]!=r[k] for k in PRESERVED):raise ValueError('stack/register preservation')
def args(text,prefix,seq):
    return bytes.fromhex(one(text,rf'{prefix} seq={seq:X} data=([0-9A-F]{{40}})'))
def check(text,status,fixture=False,native=False):
    if status!=0 or any(x in text for x in ('FAIL','[LUA ERROR]','unknown command','Error in','timeout')):raise ValueError('failed observer')
    markers=('ARM native apple-events original bytes','PASS native Apple Event registrations calls=4','[Inferior 1 (Remote target) detached]') if native else ('ARM apple-events dispatcher bytes=2f0a2f02246f000a','PASS original Apple Event registrations calls=4','Exited via the debugger')
    for marker in markers:
        if text.count(marker)!=1:raise ValueError('completion')
    entries=re.findall(r'^AE_ENTER (.*)$',text,re.M);returns=re.findall(r'^AE_RETURN (.*)$',text,re.M)
    if len(entries)!=4 or len(returns)!=4:raise ValueError('original coverage')
    for n,(es,rs,site,eid,cb) in enumerate(zip(entries,returns,SITES,IDS,CALLBACKS),1):
        e,r=fields(es),fields(rs);paired(e,r,n)
        if (e['site'],e['selector'],r['result'])!=(site,0x91f,0):raise ValueError('original selection/result')
        a=args(text,'AE_ARGS',n)
        # Original CLR.B -(SP) leaves the second Boolean-slot byte unspecified.
        if a[0]!=0 or a[2:]!=struct.pack('>IIIIH',0,e['a5']+cb,eid,0x61657674,0):raise ValueError('original arguments')
        if fields(one(text,rf'AE_BYTES seq={n:X} (.*)'))!={'selector':0x91f,'trap':0xa816}:raise ValueError('live original bytes')
    if native:
        if one(text,r'AE_TABLE count=(\d+)')!='4':raise ValueError('native table count')
        for n,(eid,cb) in enumerate(zip(IDS,CALLBACKS)):
            row=fields(one(text,rf'AE_ENTRY index={n} (.*)'))
            if row!={'class':0x61657674,'id':eid,'handler':e['a5']+cb,'refcon':0}:raise ValueError('native installed registration')
        one(text,r'AE_NEXT state=3 trap=A885 selector=FFFFFFFF segment=12 offset=346 manager=QUICKDRAW routine=DRAWTEXT windows=(?:159|185) services=\d+/\d+')
        if text.count('PASS native Apple Event startup next=DRAWTEXT original-MDRV=absent')!=1:raise ValueError('native next stop')
    if not fixture:
        if 'AE_FIX_' in text:raise ValueError('unexpected fixture')
        return
    check_fixture(text)

def check_fixture(text):
    if text.count('PASS Apple Event table fixture calls=11')!=1:raise ValueError('fixture completion')
    entries=re.findall(r'^AE_FIX_ENTER (.*)$',text,re.M)
    returns=re.findall(r'^AE_FIX_RETURN label=([\w-]+) (.*)$',text,re.M)
    if len(entries)!=len(CASES) or len(returns)!=len(CASES):raise ValueError('fixture coverage')
    for n,(es,(label,rs),case) in enumerate(zip(entries,returns,CASES),1):
        name,selector,cl,eid,cb,ref,sys,error,outcb,outref=case
        e,r=fields(es),fields(rs);paired(e,r,n)
        if label!=name or e['selector']!=selector or r['result']!=error:raise ValueError('fixture selection/result')
        base=e['sp']+20
        pointer=base+0x104 if cb is None else (e['a5']+cb if cb else 0)
        refarg=base+0x108 if cb is None else ref
        if args(text,'AE_FIX_ARGS',n)!=struct.pack('>HIIIIH',sys*256,refarg,pointer,eid,cl,0xeeee):raise ValueError('fixture input readback')
        output=(e['a5']+outcb,outref) if outcb is not None else (0xcccccccc,0xdddddddd)
        if (r['handler'],r['refcon'])!=output or (r['before'],r['after'])!=(0xdeadbeef,0xfacefeed):raise ValueError('handler state/output extent')
def check_native_fixture(text,status):
    if status!=0 or any(x in text for x in ('FAIL','Error in','timeout')):raise ValueError('native fixture failed')
    for marker in ('ARM native Apple Event CPU fixture','AE_FIX_CLEANUP count=0 sources=0/0 lineA=0 result=0','[Inferior 1 (Remote target) detached]'):
        if text.count(marker)!=1:raise ValueError('native fixture incomplete')
    check_fixture(text)

class Checks(unittest.TestCase):
    def test_incomplete(self):
        for status in (None,124,0):
            with self.assertRaises(ValueError):check('PASS original Apple Event registrations calls=4',status)

def rejections(text,fixture,native=False):
    changes=[('result=0','result=1'),('selector=91F','selector=921'),('trap=A816','trap=A817'),('PASS native Apple Event registrations calls=4' if native else 'PASS original Apple Event registrations calls=4','')]
    if fixture:changes += [('refcon=AABBCCDD','refcon=AABBCCDC'),('before=DEADBEEF','before=DEADBEEE'),('result=FFCE','result=0'),('data=0000','data=0100')]
    for old,new in changes:
        if old not in text:raise ValueError('rejection test lacked positive control '+old)
        try:check(text.replace(old,new,1),0,fixture,native)
        except ValueError:continue
        raise ValueError('corruption accepted '+old)
    for value,status in ((text,124),(text,None),(text+text,0)):
        try:check(value,status,fixture,native)
        except ValueError:continue
        raise ValueError('timeout/missing status/duplicate accepted')
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('log',type=Path,nargs='?');p.add_argument('--status',type=int);p.add_argument('--fixture',action='store_true');p.add_argument('--native',action='store_true');p.add_argument('--fixture-only',action='store_true');p.add_argument('--selftest',action='store_true');a=p.parse_args()
    if a.selftest:raise SystemExit(not unittest.TextTestRunner().run(unittest.defaultTestLoader.loadTestsFromTestCase(Checks)).wasSuccessful())
    try:
        original(Path('tmp/runtime-data/Alone In The Dark'));text=a.log.read_text()
        if a.fixture_only:
            check_native_fixture(text,a.status)
            for bad,status in ((text,124),(text,None),(text+text,0),(text.replace('refcon=AABBCCDD','refcon=AABBCCDC',1),0),(text.replace('result=FFCE','result=0',1),0),(text.replace('before=DEADBEEF','before=DEADBEEE',1),0)):
                try:check_native_fixture(bad,status)
                except ValueError:continue
                raise ValueError('native fixture corruption accepted')
            print('PASS native CPU-executed Apple Event fixture: 17 paired contracts, inputs, stack/registers, output bounds')
            raise SystemExit(0)
        check(text,a.status,a.fixture,a.native)
        rejections(text,a.fixture,a.native)
        print(('PASS native Apple Event registrations:' if a.native else 'PASS original Apple Event registrations:')+' four calls, original bytes, stack/registers'+('; 17 table-state fixture calls, input readback and output bounds' if a.fixture else ''))
    except (ValueError,OSError,KeyError,AttributeError) as e:raise SystemExit('FAIL Apple Events: '+str(e))
