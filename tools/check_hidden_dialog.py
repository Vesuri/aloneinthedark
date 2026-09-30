#!/usr/bin/env python3
"""Pair the original hidden size-dialog constructor with native logical records."""
import argparse
import hashlib
from pathlib import Path
import re
import unittest
from resource_fork import read_resource_fork
from check_getgworld import fields,record
PRESERVED=[f'd{i}' for i in range(3,8)]+[f'a{i}' for i in range(2,7)]

def original(path):
    rows=read_resource_fork(path)
    for kind,rid,digest in ((b'CODE',13,'4dcb88ed3fb619586acee9fff51be9321fb5fac1d5b3b0082c17b130100fdbc4'),(b'DLOG',1000,'6e296362d6821ef73541a4c84989f59b02d0888cf2d247f99a99149410cc1a1a'),(b'DITL',1000,'b6d1e820a3ab8f14e722f4bf3d3ed063c5d28c7d39c9ab822f95df81b26d6158')):
        b=next(r.body for r in rows if r.kind==kind and r.rid==rid)
        if kind==b'CODE':b=b[0x3410:0x341e]
        if hashlib.sha256(b).hexdigest()!=digest:raise ValueError('original constructor/resource bytes')

def calls(text,status,native=False):
    if status!=0 or any(s in text for s in ('FAIL','[LUA ERROR]','unknown command','Error in','timeout','Program received signal')):raise ValueError('failed run')
    markers=('PASS native hidden dialog next=DETACHRESOURCE','[Inferior 1 (Remote target) detached]') if native else ('PASS original hidden dialog constructor','Exited via the debugger')
    if any(text.count(s)!=1 for s in markers):raise ValueError('missing/duplicate completion')
    pairs=[]
    for label in ('DIALOG_ENTER','DIALOG_RETURN'):
        rows=re.findall('^'+label+r' (.*)$',text,re.M)
        if len(rows)!=1:raise ValueError('missing/duplicate call')
        pairs.append(fields(rows[0]))
    e,r=pairs
    if (e['behind'],e['storage'],e['id'],e['windows'])!=(0xffffffff,0,1000,0):raise ValueError('constructor arguments')
    if r['sp']!=e['sp']+10 or r['expected']!=r['sp'] or not r['dialog'] or r['dialog']!=r['windows'] or r['qdPort']!=e['qdPort']:raise ValueError('constructor state/stack')
    if any(e[k]!=r[k] for k in PRESERVED):raise ValueError('preserved register')
    return e,r

def portable(a,b,excluded):
    if len(a)!=len(b) or any(a[i]!=b[i] for i in range(len(a)) if not any(lo<=i<hi for lo,hi in excluded)):raise ValueError('portable record mismatch')
def be(b,pos):return int.from_bytes(b[pos:pos+4],'big')
def compare(ref,ref_status,native,native_status,folder):
    calls(ref,ref_status);_,ret=calls(native,native_status,True)
    port=(folder/'dialog-native-record.bin').read_bytes()
    # Pointers and opaque WDEF/TextEdit storage are runtime-owned, not portable.
    portable(port,record(ref,'DIALOG_RECORD',170),[(2,6),(24,32),(114,138),(140,148),(156,164),(166,168)])
    if len(port)!=170 or port[110] or port[164:166]!=b'\xff\xff' or not be(port,126):raise ValueError('hidden dialog/definition identity')
    if hashlib.sha256((folder/'dialog-native-source.bin').read_bytes()).hexdigest()!='b6d1e820a3ab8f14e722f4bf3d3ed063c5d28c7d39c9ab822f95df81b26d6158':raise ValueError('source DITL changed')
    items=(folder/'dialog-native-items.bin').read_bytes()
    portable(items,record(ref,'DIALOG_ITEMS',116),[(2,6),(26,30),(50,54)])
    for name,offset in [('control1',2),('control2',26)]:
        b=(folder/f'dialog-native-{name}.bin').read_bytes()
        portable(b,record(ref,'DIALOG_'+name.upper(),50),[(0,8),(24,28)])
        if be(b,4)!=ret['dialog'] or not be(b,24):raise ValueError('control owner/definition')
        if be(b,0)!=(0 if name=='control1' else be(items,2)):raise ValueError('control chain')
    if (folder/'dialog-native-text.bin').read_bytes()!=record(ref,'DIALOG_TEXT3',51):raise ValueError('text handle contents')
    if be(port,140)!=be(items,26) or len({be(items,x) for x in (2,26,50)})!=3 or any(not be(items,x) for x in (2,26,50)):raise ValueError('item/control list identities')
    for name in ('vis','clip','struct','content','update'):
        portable((folder/f'dialog-native-{name}.bin').read_bytes(),record(ref,'DIALOG_'+name.upper(),10),[])
    return True

class Checks(unittest.TestCase):
    def test_portable_fields(self):
        a=bytes(20);b=bytearray(a);b[3]=1;portable(a,b,[(2,6)])
        b[10]=1
        with self.assertRaises(ValueError):portable(a,b,[(2,6)])
        with self.assertRaises(ValueError):portable(a,b[:-1],[(2,6)])
    def test_incomplete_status(self):
        for text,status in [('',None),('',0),('PASS original hidden dialog constructor',0),('PASS original hidden dialog constructor\nExited via the debugger',124)]:
            with self.assertRaises(ValueError):calls(text,status)

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('reference',nargs='?',type=Path);p.add_argument('--status',type=int);p.add_argument('--native',type=Path);p.add_argument('--native-status',type=int);p.add_argument('--folder',type=Path,default=Path('tmp'));p.add_argument('--original',type=Path,default=Path('tmp/runtime-data/Alone In The Dark'));p.add_argument('--selftest',action='store_true');a=p.parse_args()
    if a.selftest:raise SystemExit(not unittest.TextTestRunner().run(unittest.defaultTestLoader.loadTestsFromTestCase(Checks)).wasSuccessful())
    try:
        original(a.original);calls(a.reference.read_text(),a.status)
        if a.native:compare(a.reference.read_text(),a.status,a.native.read_text(),a.native_status,a.folder)
        print('PASS hidden dialog: original bytes, hidden state, stack/registers, portable port/items/controls/text/regions')
    except (ValueError,OSError,AttributeError,KeyError) as e:raise SystemExit('FAIL hidden dialog: '+str(e))
