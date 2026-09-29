#!/usr/bin/env python3
"""Check original NewPalette records and independent ownership/lifecycle captures."""
import argparse
import hashlib
from pathlib import Path
import re
import struct
import unittest
from resource_fork import read_resource_fork
from check_getgworld import fields
from check_choice_services import one
from check_ctable import preserved
CASES=(('palette-size',0xa025,0,4112,0x8888,0),
 ('palette-state',0xa069,0,0,0x8888,0),('source-size',0xa025,0,2056,0x8888,0),
 ('source-state',0xa069,0,0,0x8888,0),('private-size',0xa025,0,4,0x8888,0),
 ('palette-attrs',0xa9a6,4,None,0xff40,0x7777),
 ('mutate-source',0xa069,0,0,0x8888,0),('mutate-palette',0xa069,0,0,0x8888,0),
 ('dispose-palette',0xaa93,4,0,0x8888,0),('source-survives',0xa025,0,2056,0x8888,0),
 ('disposed-palette-size',0xa025,0,0xffffff91,0x8888,0xff91),
 ('disposed-private-size',0xa025,0,0xffffff91,0x8888,0xff91))
def original(path):
    rows=read_resource_fork(path)
    code=next(r.body for r in rows if r.kind==b'CODE' and r.rid==7)[0x114a:0x1170]
    if hashlib.sha256(code).hexdigest()!='9c49481e014b240b50e4f2c2441e3382ae48f8955171df072cd946e7ae3b5d30':raise ValueError('original NewPalette bytes')
    return code,next(r.body for r in rows if r.kind==b'clut' and r.rid==128)
def check(text,status,folder,code,clut,fixture=False,native=False):
    if status!=0 or any(x in text for x in ('FAIL','Error in','[LUA ERROR]','timeout','unknown command')):raise ValueError('failed observer')
    end='PASS NewPalette ownership fixture calls=C' if fixture else 'PASS original NewPalette capture'
    markers=('ARM palette dispatcher bytes=2f0a2f02246f000a',end,'Exited via the debugger')
    if native:markers=('ARM native palette original bytes','PASS native NewPalette capture','PASS native palette original-MDRV=absent')
    if native and fixture:markers=('ARM native palette CPU fixture',end,'PASS native palette CPU fixture shutdown zones=0 sources=0/0 lineA=0 result=0')
    for marker in markers:
        if text.count(marker)!=1:raise ValueError('completion')
    if native and fixture:
        for marker in ('PASS native palette CPU binding retained before shutdown', 'PASS native palette CPU default binding cleared on shutdown'):
            if text.count(marker)!=1:raise ValueError('bound palette shutdown')
        if one(text,r'PALETTE_FIX_CODE data=([0-9A-F]+)')!='42A73F3C01002F2C01004878000AAA91':raise ValueError('fixture instruction bytes')
    elif bytes.fromhex(one(text,r'PALETTE_BYTES data=([0-9A-F]+)'))!=code:raise ValueError('live original bytes')
    e=fields(one(text,r'PALETTE_ENTER (.*)'));r=fields(one(text,r'PALETTE_RETURN (.*)'));preserved(e,r,10)
    args=bytes.fromhex(one(text,r'PALETTE_ENTER .*args=([0-9A-F/]+) .*').replace('/',''))
    if args!=struct.pack('>HHIHI',0,10,e['source'],256,0):raise ValueError('original arguments')
    prefix='palette-native-' if native else 'palette-reference-'
    def load(name):return (folder/(prefix+name+'.bin')).read_bytes()
    source=load('source');palette=load('body')
    expected=bytearray(clut);expected[:4]=source[:4];expected[4:6]=b'\0\0'
    for i in range(256):struct.pack_into('>H',expected,8+8*i,i)
    if source!=expected or load('source-after')!=source:raise ValueError('source changed by construction')
    if len(palette)!=4112 or palette[:12]!=bytes.fromhex('010000000000000200000000'):raise ValueError('palette extent/header')
    private=int.from_bytes(palette[12:16],'big')
    if not all((r['handle'],r['body'],e['source'],e['body'],private)) or len({r['handle'],e['source'],private})!=3 or r['body']==e['body']:raise ValueError('independent handles')
    entries=b''.join(source[10+8*i:16+8*i]+bytes.fromhex('000a0000000000000000') for i in range(256))
    if palette[16:]!=entries:raise ValueError('palette RGB/usage/tolerance/private fields')
    if native and not fixture:
        one(text,r'PALETTE_NEXT state=3 trap=A975 selector=FFFFFFFF segment=4 offset=41F4 manager=TIME MANAGER routine=TICKCOUNT windows=(?:72|98) services=(?:126/126|134/134)')
    if not fixture:
        if 'PALETTE_FIX_' in text or fields(one(text,r'PALETTE_SIZE (.*)'))!={'size':4112,'mem':0}:raise ValueError('allocated size')
        return
    p=fields(one(text,r'PALETTE_PRIVATE (.*)'))
    if p['handle']!=private or not p['body'] or len({p['body'],r['body'],e['body']})!=3 or load('private')!=bytes(4):raise ValueError('private allocation')
    enter=re.findall(r'^PALETTE_FIX_ENTER (.*)$',text,re.M)
    returned=re.findall(r'^PALETTE_FIX_RETURN label=([\w-]+) (.*)$',text,re.M)
    if len(enter)!=len(CASES) or [x[0] for x in returned]!=[x[0] for x in CASES]:raise ValueError('fixture coverage/order')
    base=None
    for n,(es,(label,rs),case) in enumerate(zip(enter,returned,CASES),1):
        x,y=fields(es),fields(rs);_,trap,pop,d0,res,mem=case;preserved(x,y,pop)
        if base is None:base=x['sp']
        if (x['seq'],y['seq'],x['trap'],x['d0'],y['res'],y['mem'])!=(n,n,trap,0x12345678,res,mem):raise ValueError('fixture input/errors')
        if d0 is not None and y['d0']!=d0:raise ValueError('fixture result')
        h=private if 'private' in label else e['source'] if label in ('source-size','source-state','mutate-palette','source-survives') else r['handle']
        arg=bytes.fromhex(one(es,r'.*args=([0-9A-F/]+) .*').replace('/',''))
        if trap in (0xa025,0xa069):
            if x['sp']!=base or x['a0']!=h:raise ValueError('handle query input')
        elif trap==0xa9a6:
            if x['sp']!=base-6 or arg[:6]!=struct.pack('>IH',h,0xcccc):raise ValueError('attributes input')
        elif x['sp']!=base-4 or arg[:4]!=struct.pack('>I',h):raise ValueError('disposal input')
    changed_source=bytearray(source);changed_source[10:12]=bytes.fromhex('1234')
    changed_palette=bytearray(palette);changed_palette[16:18]=bytes.fromhex('5678')
    for name,wanted in (('source-mutated',changed_source),('after-source',palette),('mutated',changed_palette),('source-after-palette',changed_source),('source-survives',changed_source)):
        if load(name)!=wanted:raise ValueError('independent ownership '+name)
class Checks(unittest.TestCase):
    def test_reject_incomplete(self):
        for status in (None,124,0):
            with self.assertRaises(ValueError):check('PASS original NewPalette capture',status,Path('tmp'),b'',b'')
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('log',type=Path,nargs='?');p.add_argument('--status',type=int);p.add_argument('--fixture',action='store_true');p.add_argument('--native',action='store_true');p.add_argument('--folder',type=Path,default=Path('tmp'));p.add_argument('--selftest',action='store_true');a=p.parse_args()
    if a.selftest:raise SystemExit(not unittest.TextTestRunner().run(unittest.defaultTestLoader.loadTestsFromTestCase(Checks)).wasSuccessful())
    try:
        code,clut=original(Path('tmp/runtime-data/Alone In The Dark'));text=a.log.read_text()
        check(text,a.status,a.folder,code,clut,a.fixture,a.native)
        for bad,status in ((text,124),(text,None),(text+text,0),(text.replace('args=0000000A','args=0000000B',1),0),(text.replace('PALETTE_FIX_CODE data=42A7','PALETTE_FIX_CODE data=42A6').replace('PALETTE_BYTES data=42A7','PALETTE_BYTES data=42A6'),0)):
            try:check(bad,status,a.folder,code,clut,a.fixture,a.native)
            except ValueError:continue
            raise ValueError('invalid capture accepted')
        print('PASS NewPalette: original bytes, arguments, stack/registers, exact records'+('; 12 ownership/disposal cases' if a.fixture else ''))
    except (OSError,ValueError,KeyError,AttributeError) as e:raise SystemExit('FAIL NewPalette: '+str(e))
