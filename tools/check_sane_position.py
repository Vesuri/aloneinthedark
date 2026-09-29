#!/usr/bin/env python3
"""Verify the ten unchanged original positioning calls against exact arithmetic."""
import argparse
import hashlib
from pathlib import Path
import re
import unittest
from resource_fork import read_resource_fork
from check_getgworld import fields
from check_sane import vector
OFFSETS=(0x47c2,0x47d0,0x47de,0x47e8,0x47f6,0x481e,0x482c,0x483a,0x4844,0x4852)
OPS=(0x200e,0x1004,0x2000,0x16,0x2010)*2
REGS=[f'd{i}' for i in range(8)]+[f'a{i}' for i in range(7)]
def original(path):
    b=next(r.body for r in read_resource_fork(path) if r.kind==b'CODE' and r.rid==7)
    if hashlib.sha256(b[0x477a:0x48ac]).hexdigest()!='5d07d538726b48d9b72c1e7d20ce1f08fbb6bd29273b413959e26ac9fb2c405c':raise ValueError('original positioning bytes')
def check(text,status,native=False):
    if status!=0 or any(s in text for s in ('FAIL','[LUA ERROR]','unknown command','Error in','timeout','Cannot insert breakpoint','Program received signal')):raise ValueError('failed observer')
    marker='PASS native SANE positioning calls=A' if native else 'PASS original SANE positioning calls=A'
    end='[Inferior 1 (Remote target) detached]' if native else 'Exited via the debugger'
    if text.count(marker)!=1 or text.count(end)!=1:raise ValueError('missing/duplicate completion')
    position=re.findall(r'^POSITION_INPUT shadow=(\d+) instruction=([0-9A-F]+) rect=([0-9A-F]+) selected=([0-9A-F]+) main=([0-9A-F]+)$',text,re.M)
    if len(position)!=1:raise ValueError('position input coverage')
    height,instruction,rect,selected,main=position[0]
    if height!='20' or instruction!=('302D0F5C' if native else '30380BAA') or rect!='0000000001E00280' or selected!=main:raise ValueError('position input/low-memory instruction')
    rows={}
    for label in ('SANE_ENTER','SANE_RETURN','SANE_DEST_BEFORE','SANE_SOURCE','SANE_DEST_AFTER'):
        rows[label]=re.findall('^'+label+r' (.*)$',text,re.M)
        if len(rows[label])!=10:raise ValueError('call/record coverage')
    semantics=[]
    for i,op in enumerate(OPS):
        e=fields(rows['SANE_ENTER'][i]);r=fields(rows['SANE_RETURN'][i])
        if e['seq']!=i+1 or r['seq']!=i+1 or e['op']!=op or e['offset']!=OFFSETS[i]:raise ValueError('original call identity')
        if e['fp'] or r['fp'] or any(e[k]!=r[k] for k in REGS):raise ValueError('preserved state/registers')
        if r['sp']!=e['sp']+(6 if op==0x16 else 10):raise ValueError('stack cleanup')
        data=[]
        for label in ('SANE_DEST_BEFORE','SANE_SOURCE','SANE_DEST_AFTER'):
            m=re.fullmatch(r'seq=([0-9A-F]+) data=([0-9A-F]{24})',rows[label][i])
            if not m or int(m[1],16)!=i+1:raise ValueError('record identity/extent')
            data.append(bytes.fromhex(m[2]))
        before,source,after=data;v=vector(op,source,before)
        if not v['ok'] or after.hex()!=v['after']:raise ValueError(f'exact result/guard bytes call {i+1}')
        source_len=10 if op==0x2010 else 4 if op==0x1004 else 2
        semantics.append((op,source[:source_len] if op!=0x16 else b'',before[:10] if op in (0x1004,0x2000,0x16) else b'',after[:2 if op==0x2010 else 10]))
    if native:
        if text.count('SANE_POSITION front=0 vertical=205 horizontal=177')!=1:raise ValueError('positioning request')
        frames=[]
        for label in ('SANE_FRAME','SANE_FRAME_RETURN'):
            frame=re.findall('^'+label+r' seq=([0-9A-F]+) sr=([0-9A-F]+)$',text,re.M)
            if len(frame)!=10 or [int(x[0],16) for x in frame]!=list(range(1,11)):raise ValueError('native exception-frame coverage')
            frames.append(frame)
        if frames[0]!=frames[1]:raise ValueError('native exception-frame flags changed')
    return semantics
class Checks(unittest.TestCase):
    def test_incomplete(self):
        for native,marker in [(False,'PASS original SANE positioning calls=A'),(True,'PASS native SANE positioning calls=A')]:
            for status in (None,124,0):
                with self.assertRaises(ValueError):check(marker,status,native)
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('reference',nargs='?',type=Path);p.add_argument('--status',type=int);p.add_argument('--native',type=Path);p.add_argument('--native-status',type=int);p.add_argument('--selftest',action='store_true');a=p.parse_args()
    if a.selftest:raise SystemExit(not unittest.TextTestRunner().run(unittest.defaultTestLoader.loadTestsFromTestCase(Checks)).wasSuccessful())
    try:
        original(Path('tmp/runtime-data/Alone In The Dark'));ref=check(a.reference.read_text(),a.status)
        captures=[(a.reference.read_text(),False)]
        if a.native:
            native_text=a.native.read_text()
            if ref!=check(native_text,a.native_status,True):raise ValueError('paired semantic records')
            captures.append((native_text,True))
        for text,native in captures:
            marker='PASS native SANE positioning calls=A' if native else 'PASS original SANE positioning calls=A'
            bads=[(text,124),(text,None),(text.replace(marker,''),0),(text+marker,0),
                  (text.replace('shadow=20','shadow=0'),0),(text.replace('fp=0','fp=1',1),0),
                  (text.replace('offset=47C2','offset=47C4',1),0),
                  (re.sub(r'(SANE_DEST_AFTER seq=1 data=)[0-9A-F]',r'\g<1>F',text,count=1),0)]
            for bad,status in bads:
                try:check(bad,status,native)
                except ValueError:continue
                raise ValueError('corrupted capture accepted')
        print('PASS original SANE positioning: ten exact results, stack/registers, unchanged FPState, bounded writes, position 177/205')
    except (ValueError,OSError,KeyError,AttributeError) as e:raise SystemExit('FAIL SANE positioning: '+str(e))
