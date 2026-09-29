#!/usr/bin/env python3
"""Validate the original Core device-selection contract before native implementation."""
import argparse
import hashlib
from pathlib import Path
import re
import unittest
from resource_fork import read_resource_fork

COMPLETE='PASS device reference calls=4 inflight=0 secondTimes=14'
SITES={0x4b48:(0xaa29285f,0),0x4b8e:(0xaa2b285f,4),0x4d4a:(0xaa2c101f,6),0x4d70:(0xaaa2301f,10),0x4da2:(0xa8a8302e,8)}
ORDER=[0x4b48,0x4d70,0x4da2,0x4b8e]
PRESERVED=[f'd{n}' for n in range(2,8)]+[f'a{n}' for n in range(2,7)]
def fields(line):
    return {k:int(v,16) for k,v in re.findall(r'(\w+)=([0-9A-F]+)(?= |$)',line)}
def original(path):
    core=next(r.body for r in read_resource_fork(path) if r.kind==b'CODE' and r.rid==3)
    if hashlib.sha256(core[0x4b32:0x4dc2]).hexdigest()!='d9618f55f79a64a1fdb2146f8b88beb523b2bf08935e78fda14900141adb611e':
        raise ValueError('original Core selection bytes')
    for offset,(op,_) in SITES.items():
        if int.from_bytes(core[offset:offset+4],'big')!=op:raise ValueError('original trap-site bytes')
def check(text,status):
    if status!=0 or any(s in text for s in ('FAIL','[LUA ERROR]','unknown command','Error in','timeout')):raise ValueError('failed runner/debugger')
    for marker in (COMPLETE,'ARM device dispatcher bytes=2f0a2f02246f000a','Exited via the debugger'):
        if text.count(marker)!=1:raise ValueError('missing/duplicate completion')
    rows=[];sites={};pointers=None;selected=None
    for line in text.splitlines():
        if line.startswith('DEVICE_SITE '):
            f=fields(line)
            if f['offset'] in sites:raise ValueError('duplicate site')
            sites[f['offset']]=f['bytes']
        elif line.startswith('DEVICE_POINTERS '):
            if pointers is not None:raise ValueError('duplicate pointers')
            pointers=fields(line)
        elif line.startswith('DEVICE_SELECTED '):
            if selected is not None:raise ValueError('duplicate selection')
            selected=fields(line)
        elif line.startswith('DEVICE_ENTER '):
            e=fields(line);e['args']=bytes.fromhex(re.search(r'args=([0-9A-F/]+)',line)[1].replace('/',''));rows.append({'enter':e})
        elif line.startswith(('DEVICE_RETURN ','DEVICE_RECORD ','PIXMAP_RECORD ','CTABLE_RECORD ','RECT_BEFORE ','RECT_AFTER ')):
            if not rows:raise ValueError('evidence before call')
            key=line.split()[0];row=rows[-1]
            if key in row or fields(line)['seq']!=row['enter']['seq']:raise ValueError('duplicate/misattributed evidence')
            row[key]=bytes.fromhex(line.split('data=')[1]) if 'data=' in line else fields(line)
    if sites!={o:v[0] for o,v in SITES.items()} or len(rows)!=4:raise ValueError('site/call coverage')
    for seq,(row,offset) in enumerate(zip(rows,ORDER),1):
        e=row['enter'];r=row['DEVICE_RETURN'];op,pop=SITES[offset]
        if e['seq']!=seq or e['offset']!=offset or e['trap']!=op>>16:raise ValueError('call order')
        if r['seq']!=seq or r['offset']!=offset or r['trap']!=e['trap'] or r['sp']!=e['sp']+pop or r['sp']!=r['expected']:raise ValueError('return/stack contract')
        if any(e[k]!=r[k] for k in PRESERVED):raise ValueError('preserved registers')
    first,depth,rect,last=rows
    handle=first['DEVICE_RETURN']['result']
    if not handle or not pointers or pointers['handle']!=handle or any(not v for v in pointers.values()):raise ValueError('device pointer chain')
    def u(data,off,size=2):return int.from_bytes(data[off:off+size],'big')
    gd=first['DEVICE_RECORD'];pm=first['PIXMAP_RECORD'];ct=first['CTABLE_RECORD']
    if (len(gd),len(pm),len(ct))!=(64,52,8):raise ValueError('record extents')
    if u(gd,22,4)&0xffffff!=pointers['pixmapHandle'] or u(pm,42,4)&0xffffff!=pointers['clutHandle']:raise ValueError('record pointer relationships')
    if u(gd,4)!=0 or u(gd,10)!=4 or u(gd,20)!=0xb921 or u(gd,30,4)!=0 or gd[34:42]!=bytes.fromhex('0000000001e00280') or u(gd,42,4)!=0x83:raise ValueError('GDevice layout/chain')
    if u(pm,0,4)!=0xf9000a00 or u(pm,4)!=0x8280 or pm[6:14]!=gd[34:42] or any(pm[14:22]) or u(pm,22,4)!=72<<16 or u(pm,26,4)!=72<<16 or pm[30:38]!=bytes.fromhex('0000000800010008') or any(pm[38:42])+any(pm[46:50]):raise ValueError('8-bit PixMap layout')
    if u(ct,4)!=0x8000 or u(ct,6)!=255:raise ValueError('256-entry device CLUT header')
    args=depth['enter']['args']
    if args[:6]!=bytes.fromhex('000000010008') or u(args,6,4)!=handle or depth['enter']['d0']&0xffff!=0xa14:raise ValueError('HasDepth request')
    if depth['DEVICE_RETURN']['result']!=0x83 or depth['DEVICE_RETURN']['d0']!=8:raise ValueError('HasDepth mode/result')
    if rect['enter']['args'][:4]!=bytes(4) or rect['RECT_BEFORE']!=gd[34:42] or rect['RECT_AFTER']!=gd[34:42]:raise ValueError('OffsetRect arguments/result')
    if u(last['enter']['args'],0,4)!=handle or last['DEVICE_RETURN']['result']!=0 or selected!={'result':handle,'count':1}:raise ValueError('single-device selection')
    for row in (first,last):
        if row['DEVICE_RETURN']['d0']!=row['enter']['d0']:raise ValueError('list call D0 preservation')
    return rows

def rejection_checks(text):
    changes=[(text,124),(text,None),(text.replace(COMPLETE,''),0),(text+'\n'+COMPLETE,0),
             (text.replace('bytes=AA29285F','bytes=AA29285E'),0),
             (text.replace('result=83','result=1'),0),
             (text.replace('F9000A008280','F9000A008100'),0),
             (text.replace('count=1','count=2'),0)]
    for changed,status in changes:
        try:check(changed,status)
        except (ValueError,KeyError):continue
        raise ValueError('corrupt acceptance fixture passed')
class Checks(unittest.TestCase):
    def test_incomplete(self):
        for text,status in (('',0),(COMPLETE,0),(COMPLETE,124),(COMPLETE,None)):
            with self.assertRaises(ValueError):check(text,status)
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('log',nargs='?',type=Path);p.add_argument('--status',type=int);p.add_argument('--selftest',action='store_true');a=p.parse_args()
    if a.selftest:raise SystemExit(not unittest.TextTestRunner().run(unittest.defaultTestLoader.loadTestsFromTestCase(Checks)).wasSuccessful())
    try:
        original(Path('tmp/runtime-data/Alone In The Dark'));text=a.log.read_text();check(text,a.status);rejection_checks(text)
        print('PASS device reference: original bytes, four paired calls, 640x480x8 layout, mode 0x83, rectangle and single-device selection; 8 rejection fixtures')
    except (OSError,ValueError,KeyError,AttributeError) as error:raise SystemExit('FAIL device reference: '+str(error))
