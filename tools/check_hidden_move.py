#!/usr/bin/env python3
"""Pair hidden MoveWindow's old-style port and local/global region contracts."""
import argparse
import hashlib
from pathlib import Path
import re
import struct
import unittest
from resource_fork import read_resource_fork
from check_getgworld import fields,record
from check_hidden_dialog import portable,PRESERVED
SIZES=dict(record=170,items=116,vis=10,clip=10,struct=10,content=10,update=10,control1=50,control2=50,text3=51)
def original():
    b=next(r.body for r in read_resource_fork(Path('tmp/runtime-data/Alone In The Dark')) if r.kind==b'CODE' and r.rid==7)
    if hashlib.sha256(b[0x4858:0x48ac]).hexdigest()!='5a7840c7425412888a640e60c0e0409b25f0dce52805d03cd7c048839cc0e6d1':raise ValueError('original MoveWindow bytes')
def calls(text,status,native=False):
    if status!=0 or any(x in text for x in ('FAIL','[LUA ERROR]','unknown command','Error in','timeout','Program received signal')):raise ValueError('failed observer')
    markers=('PASS native hidden MoveWindow next=NEWGWORLD','[Inferior 1 (Remote target) detached]') if native else ('PASS original hidden MoveWindow','Exited via the debugger')
    if any(text.count(x)!=1 for x in markers):raise ValueError('missing/duplicate completion')
    rows=[]
    for name in ('MOVE_ENTER','MOVE_RETURN'):
        matches=re.findall('^'+name+r' (.*)$',text,re.M)
        if len(matches)!=1:raise ValueError('call coverage')
        rows.append(fields(matches[0]))
    e,r=rows;args=e['args'].to_bytes(10,'big')
    if args[0]!=0 or args[2:6]!=bytes.fromhex('00cd00b1') or int.from_bytes(args[6:],'big')!=e['windows']:raise ValueError('original positioning request')
    if r['sp']!=e['sp']+10 or not e['qdPort'] or any(e[k]!=r[k] for k in PRESERVED+['windows','qdPort']):raise ValueError('stack/preserved state')
    return rows

def records(text,native=False):
    return {(phase,name):(Path(f'tmp/move-native-{phase}-{name}.bin').read_bytes() if native else record(text,'MOVE_'+phase.upper()+'_'+name.upper(),size)) for phase in ('before','after') for name,size in SIZES.items()}
def contract(data):
    for (phase,name),b in data.items():
        if len(b)!=SIZES[name]:raise ValueError('record extent')
    a=data['before','record'];b=data['after','record']
    if a[110] or b[110] or a[6:8]!=b'\0P' or a[16:24]!=bytes.fromhex('00000000005a011d'):raise ValueError('hidden old-style port')
    if a[8:16]!=struct.pack('>hhhh',-187,-241,293,399) or b[8:16]!=struct.pack('>hhhh',-205,-177,275,463):raise ValueError('bitmap origin')
    portable(a,b,[(8,16)])
    if a[164:166]!=b'\xff\xff':raise ValueError('no active edit item')
    for name in ('items','vis','clip','control1','control2','text3'):
        if data['before',name]!=data['after',name]:raise ValueError('local state changed')
    for name in ('struct','content','update'):
        if data['before',name]!=struct.pack('>Hhhhh',10,0,0,0,0) or data['after',name]!=struct.pack('>Hhhhh',10,18,-64,18,-64):raise ValueError('global empty-region translation')
def compare(reference,native):
    for phase in ('before','after'):
        for name in SIZES:
            excluded={'record':[(2,6),(24,32),(114,138),(140,148),(156,164),(166,168)],'items':[(2,6),(26,30),(50,54)],'control1':[(0,8),(24,28)],'control2':[(0,8),(24,28)]}.get(name,[])
            portable(native[phase,name],reference[phase,name],excluded)
class Checks(unittest.TestCase):
    def test_incomplete(self):
        for status in (None,124,0):
            with self.assertRaises(ValueError):calls('PASS original hidden MoveWindow',status)
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('reference',type=Path,nargs='?');p.add_argument('--status',type=int);p.add_argument('--native',type=Path);p.add_argument('--native-status',type=int);p.add_argument('--selftest',action='store_true');a=p.parse_args()
    if a.selftest:raise SystemExit(not unittest.TextTestRunner().run(unittest.defaultTestLoader.loadTestsFromTestCase(Checks)).wasSuccessful())
    try:
        original();text=a.reference.read_text();calls(text,a.status);ref=records(text);contract(ref)
        edit=re.findall(r'^MOVE_CONSTRUCTOR_EDIT dialog=([0-9A-F]+) fields=([0-9A-F]{8})$',text,re.M)
        if len(edit)!=1 or bytes.fromhex(edit[0][1])!=ref['before','record'][164:168] or 'MOVE_EDIT_WRITE' in text:raise ValueError('constructor edit-state preservation')
        if a.native:
            n=a.native.read_text();calls(n,a.native_status,True);data=records(n,True);contract(data);compare(ref,data)
        for bad,status in ((text,124),(text,None),(text.replace('PASS original hidden MoveWindow',''),0),(text+text,0),(text.replace('00CD00B1','00CD00B2',1),0)):
            try:calls(bad,status)
            except ValueError:continue
            raise ValueError('bad capture accepted')
        for name in ('record','struct','content','update','items','vis','clip','control1','control2','text3'):
            bad=dict(ref);b=bytearray(bad['after',name]);b[8 if name=='record' else 2]^=1;bad['after',name]=bytes(b)
            try:contract(bad)
            except ValueError:continue
            raise ValueError('bad record accepted')
        print('PASS hidden MoveWindow: original bytes, ten-byte cleanup, preserved state, bitmap origin, local items and three translated empty regions')
    except (ValueError,OSError,KeyError,AttributeError) as e:raise SystemExit('FAIL hidden MoveWindow: '+str(e))
