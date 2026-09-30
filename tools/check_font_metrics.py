#!/usr/bin/env python3
"""Validate the original startup's 25 FontInfo and 50 CharWidth contracts."""
import argparse
import hashlib
from pathlib import Path
import re
import struct
import unittest
from resource_fork import read_resource_fork
from check_getgworld import fields
from check_choice_services import one,PRESERVED
# Font/size, followed by (ascent, descent, widMax, leading, '0', space)
# for plain, bold, italic, condensed, bold+condensed respectively. Measured facts,
# not font artwork or a substitute for installed native font definitions.
STYLES=(0,1,2,32,33)
CASES=(
 (0,12,((12,3,14,1,8,4),(12,3,15,1,9,5),(12,3,14,1,8,4),(12,3,13,1,7,3),(12,3,14,1,8,4))),
 (3,9,((10,2,10,0,6,3),(10,2,11,0,7,4),(10,2,10,0,6,3),(10,2,9,0,5,2),(10,2,10,0,6,3))),
 (21,9,((7,3,11,0,5,2),(7,3,12,0,5,3),(7,3,11,0,5,2),(7,3,11,0,4,2),(7,3,11,0,5,2))),
 (21,18,((14,5,22,0,10,5),(14,5,23,0,11,6),(14,5,22,0,10,5),(14,5,21,0,9,4),(14,5,22,0,10,5))),
 (21,36,((28,10,44,0,20,10),(28,10,46,0,22,12),(28,10,44,0,20,10),(28,10,42,0,18,8),(28,10,44,0,20,10))))
def original(path):
    b=next(r.body for r in read_resource_fork(path) if r.kind==b'CODE' and r.rid==9)
    if hashlib.sha256(b[0x534:0x66c]).hexdigest()!='364f0d6ecb13463d7382b639f6d6dd460023ced401f22c52ee43f77a9f019f15':raise ValueError('original metric loop bytes')
def check(text,status,native=False):
    if status!=0 or any(x in text for x in ('FAIL','[LUA ERROR]','unknown command','Error in','timeout')):raise ValueError('failed observer')
    markers=('PASS native font metrics calls=4B next=PAINTRECT','[Inferior 1 (Remote target) detached]','ARM native metrics original bytes') if native else ('PASS original font metrics calls=4B','Exited via the debugger','ARM metrics dispatcher bytes=2f0a2f02246f000a')
    if any(text.count(x)!=1 for x in markers):raise ValueError('completion')
    entered=re.findall(r'^METRIC_ENTER label=(\w+) (.*)$',text,re.M)
    returned=re.findall(r'^METRIC_RETURN label=(\w+) (.*)$',text,re.M)
    labels=['INFO','ZERO','SPACE']*25
    if [x for x,_ in entered]!=labels or [x for x,_ in returned]!=labels:raise ValueError('75-call coverage/order')
    font_table=b''.join(struct.pack('>BBHH',i,0,font,size) for i,(font,size,_) in enumerate(CASES))
    style_table=b''.join(bytes((i,style)) for i,style in enumerate(STYLES))
    wanted=[(font,size,style,metrics) for font,size,values in CASES for style,metrics in zip(STYLES,values)]
    port=None;saved=None
    for i,((label,es),(_,rs)) in enumerate(zip(entered,returned)):
        e,r=fields(es),fields(rs);seq=i+1;font,size,style,metrics=wanted[i//3]
        if e['seq']!=seq or r['seq']!=seq:raise ValueError('sequence')
        if (e['font'],e['size'],e['face'],e['extra'])!=(font,size,style,0):raise ValueError('font/size/style selection')
        if port is None:port=e['port']
        if not port or e['port']!=port or r['port']!=port or any(e[k]!=r[k] for k in PRESERVED):raise ValueError('preserved port/registers')
        args=bytes.fromhex(one(text,rf'METRIC_ARGS seq={seq:X} data=([0-9A-F]{{24}})'))
        if r['sp']!=e['sp']+(4 if label=='INFO' else 2):raise ValueError('stack cleanup')
        if label=='INFO':
            if int.from_bytes(args[:4],'big')!=e['a2']:raise ValueError('FontInfo output pointer')
            before=bytes.fromhex(one(text,rf'METRIC_BEFORE seq={seq:X} data=([0-9A-F]{{24}})'))
            after=bytes.fromhex(one(text,rf'METRIC_AFTER seq={seq:X} data=([0-9A-F]{{24}})'))
            if after[:8]!=struct.pack('>4H',*metrics[:4]) or before[8:]!=after[8:]:raise ValueError('FontInfo result/extent')
            if bytes.fromhex(one(text,rf'METRIC_FONTS seq={seq:X} data=([0-9A-F]{{64}})'))[:30]!=font_table:raise ValueError('original font table')
            if bytes.fromhex(one(text,rf'METRIC_STYLES seq={seq:X} data=([0-9A-F]{{24}})'))[:10]!=style_table:raise ValueError('original style table')
            state=fields(one(text,rf'METRIC_SAVED seq={seq:X} (.*)'))
            if saved is None:saved=state
            if state!=saved:raise ValueError('saved text state')
        else:
            character=0x30 if label=='ZERO' else 0x20
            if args[:4]!=struct.pack('>HH',character,0) or r['result']!=metrics[4 if label=='ZERO' else 5]:raise ValueError('character/result slot')
    done=fields(one(text,r'METRIC_DONE (.*)'))
    if done!={**saved,'error':0}:raise ValueError('restored text state/result')
    if native:
        one(text,r'METRIC_NEXT state=3 trap=A8A2 selector=FFFFFFFF segment=13 offset=D52 manager=QUICKDRAW routine=PAINTRECT windows=(?:115|141) services=(?:433/433|441/441) app=64/294970 overlay=31/80650 prep=64/81222 resources=244')
        from build_overlay import definitions
        rows=re.findall(r'^FONT_INSTALLED type=([0-9A-F]+) id=(\d+) size=(\d+)$',text,re.M)
        expected=[(kind,rid,body) for kind,rid,_,body in definitions() if kind in (b'FOND',b'NFNT')]
        if len(rows)!=len(expected) or len(set(rows))!=len(rows):raise ValueError('installed font coverage')
        for kind,rid,body in expected:
            key=f'{int.from_bytes(kind,"big"):X}'
            if (key,str(rid),str(len(body))) not in rows or Path(f'tmp/metrics-font-{key}-{rid}.bin').read_bytes()!=body:raise ValueError('installed font bytes')
    return wanted
class Checks(unittest.TestCase):
    def test_incomplete(self):
        for status in (None,124,0):
            with self.assertRaises(ValueError):check('PASS original font metrics calls=4B',status)
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('log',type=Path,nargs='?');p.add_argument('--status',type=int);p.add_argument('--native',type=Path);p.add_argument('--native-status',type=int);p.add_argument('--selftest',action='store_true');a=p.parse_args()
    if a.selftest:raise SystemExit(not unittest.TextTestRunner().run(unittest.defaultTestLoader.loadTestsFromTestCase(Checks)).wasSuccessful())
    try:
        original(Path('tmp/runtime-data/Alone In The Dark'));text=a.log.read_text();check(text,a.status)
        if a.native:check(a.native.read_text(),a.native_status,True)
        for old,new in [('result=8','result=9'),('face=20','face=10'),('000C0003000E0001','000C0003000F0001'),('PASS original font metrics calls=4B','')]:
            try:check(text.replace(old,new,1),0)
            except ValueError:continue
            raise ValueError('corruption accepted')
        for bad,status in ((text,124),(text,None),(text+text,0)):
            try:check(bad,status)
            except ValueError:continue
            raise ValueError('incomplete/duplicate accepted')
        print('PASS '+('paired native font metrics (30 installed bodies): ' if a.native else 'original font metrics: ')+'25 records, 50 widths, original tables/bytes, output extents, stack/registers and restored text state')
    except (ValueError,OSError,KeyError,AttributeError) as e:raise SystemExit('FAIL font metrics: '+str(e))
