#!/usr/bin/env python3
"""Verify original and hidden native fixed-choice service contracts."""
import argparse
import hashlib
from pathlib import Path
import re
import unittest
from resource_fork import read_resource_fork
from check_screen_choice import original
from check_getgworld import fields
PRESERVED='d3 d4 d5 d6 d7 a2 a3 a4 a5 a6'.split()
def one(text,pattern):
    matches=re.findall('^'+pattern+'$',text,re.M)
    if len(matches)!=1:raise ValueError('missing/duplicate '+pattern)
    return matches[0]
def check(text,status,native=False):
    if status!=0 or any(x in text for x in ('FAIL','[LUA ERROR]','unknown command','Error in','timeout','Program received signal')):raise ValueError('failed observer')
    marker='PASS native fixed-choice services next=SETPALETTE' if native else 'PASS original fixed-choice services'
    if text.count(marker)!=1 or text.count('[Inferior 1 (Remote target) detached]' if native else 'Exited via the debugger')!=1:raise ValueError('completion')
    entries=re.findall(r'^SERVICE_ENTER label=(\w+) (.*)$',text,re.M)
    returns=re.findall(r'^SERVICE_RETURN label=(\w+) (.*)$',text,re.M)
    labels=['MODAL','ITEM','DISPOSE','WORLD'] if native else ['MODAL','MODAL','ITEM','DISPOSE','WORLD']
    if [k for k,_ in entries]!=labels or [k for k,_ in returns]!=labels:raise ValueError('call coverage')
    wm=fields(entries[0][1])['port'];dialog=fields(entries[0][1])['windows']
    if not wm or not dialog or wm==dialog:raise ValueError('real world/dialog')
    for (label,es),(_,rs) in zip(entries,returns):
        e,r=fields(es),fields(rs);seq=e['seq']
        args=bytes.fromhex(one(text,rf'SERVICE_ARGS seq={seq:X} data=([0-9A-F]{{48}})'))
        longs=[int.from_bytes(args[i:i+4],'big') for i in range(0,24,4)]
        pop={'MODAL':8,'ITEM':18,'DISPOSE':4,'WORLD':8}[label]
        if r['seq']!=seq or r['sp']!=e['sp']+pop or any(e[k]!=r[k] for k in PRESERVED):raise ValueError('stack/register preservation')
        if label=='MODAL':
            if not longs[0] or longs[1]!=e['a5']+0x372 or e['port']!=(wm if seq==1 else dialog) or e['windows']!=dialog or r['port']!=dialog or r['windows']!=dialog:raise ValueError('modal state')
            before=int(one(text,rf'MODAL_BEFORE seq={seq:X} data=([0-9A-F]{{8}})'),16)
            after=int(one(text,rf'MODAL_AFTER seq={seq:X} data=([0-9A-F]{{8}})'),16)
            if before&65535!=after&65535 or after>>16!=(2 if native or seq==2 else 0):raise ValueError('item write extent')
        elif label=='ITEM':
            if int.from_bytes(args[12:14],'big')!=2 or int.from_bytes(args[14:18],'big')!=dialog or any(not x for x in longs[:3]) or e['port']!=dialog or r['port']!=dialog or e['windows']!=dialog or r['windows']!=dialog:raise ValueError('item request state')
            req=fields(one(text,r'ITEM_REQUEST (.*)'));out=fields(one(text,r'ITEM_RESULT (.*)'))
            if req['number']!=2 or req['dialog']!=dialog or not req['handle'] or out!={'type':4,'handle':req['handle'],'rect':0x003c001d00500081}:raise ValueError('item result')
        elif label=='DISPOSE':
            if longs[0]!=dialog or e['port']!=dialog or e['windows']!=dialog or r['port']!=wm or r['windows']!=0:raise ValueError('dispose state')
        else:
            if longs[0]==0 or longs[1]!=wm or e['port']!=wm or r['port']!=wm or e['windows'] or r['windows'] or e['d0']!=0x80006 or r['d0']!=0x80000 or r['a0']!=wm or r['a1']!=longs[0]:raise ValueError('world restore')
    if native:
        if one(text,r'MODAL_POLICY visible=(\d+) filterOffset=([0-9A-F]+)')!=('0','372'):raise ValueError('hidden policy')
        if one(text,r'DISPOSE_OWNER (.*)')!='used=0 dialog=0 window=0 freeDelta=384 flags=00000000 owned=0000':raise ValueError('owned allocations')
        before=bytes.fromhex(one(text,r'CHOICE_PREF before=([0-9A-F]{20})'));after=bytes.fromhex(one(text,r'CHOICE_PREF after=([0-9A-F]{20})'))
        want=bytearray(before);want[7]=0
        result,old=one(text,r'CHOICE_RESULT d0=([0-9A-F]+) pref=([0-9A-F]+)')
        if before[7] not in (0,1) or after!=want or int(old,16)!=before[7] or int(result,16)&65535!=1-before[7]:raise ValueError('original preference mapping')
        if one(text,r'CHOICE_WINDOW id=([0-9A-F]+) opcode=([0-9A-F]+)')!=('80','AA46'):
            raise ValueError('original WIND 128 request')
        site=fields(one(text,r'WINDOW_SITE (.*)'))
        if site['offset']!=0x109a or site['pc']!=site['base']+0x109a or site['id']!=128 or site['builtin'] or site['service']:
            raise ValueError('original main-window call site')
        window=fields(one(text,r'WINDOW_REQUEST (.*)'))
        if window['storage'] or window['result'] or window['behind']!=0xffffffff or window['pref']:
            raise ValueError('original window arguments')
        code=bytearray.fromhex(one(text,r'WINDOW_BYTES data=([0-9A-F]+)'))
        if len(code)!=44 or int.from_bytes(code[2:6],'big')!=window['operand'] or window['operand']!=window['a5']-0x11b54:
            raise ValueError('window instruction relocation')
        code[2:6]=bytes.fromhex('fffee4ac')
        if hashlib.sha256(code).hexdigest()!='474f8a03c2ddd2d18c9367305105c552f8e79613077ee7cb114d754752f9e5fe':
            raise ValueError('live original window instructions')
        one(text,r'CHOICE_NEXT state=3 trap=AA95 selector=FFFFFFFF segment=9 offset=10FA manager=PALETTE MANAGER routine=SETPALETTE windows=(?:68|94) services=(?:124/124|132/132) reads=32 bytes=130692')
    return True

def check_selection(reference,status,native):
    from check_screen_choice import check as selection
    before=bytes.fromhex(one(native,r'CHOICE_PREF before=([0-9A-F]{20})'))
    after=bytes.fromhex(one(native,r'CHOICE_PREF after=([0-9A-F]{20})'))
    if selection(reference,status,before[7])!=(before,after):
        raise ValueError('paired original window-selection preferences')
    if one(reference,r'CHOICE_WINDOW id=([0-9A-F]+) opcode=([0-9A-F]+)')!=one(native,r'CHOICE_WINDOW id=([0-9A-F]+) opcode=([0-9A-F]+)'):
        raise ValueError('paired window request')


def bytecheck(path):
    original(path)
    body=next(r.body for r in read_resource_fork(path) if r.kind==b'CODE' and r.rid==13)
    if hashlib.sha256(body[0x344a:0x34fa]).hexdigest()!='4924dfc55f932aabd4d4cabe52aab96b5810f40573f68fc7fe823b0e71ce95b7':raise ValueError('original item/disposal bytes')
class Checks(unittest.TestCase):
    def test_paired_selection(self):
        from check_screen_choice import Checks as SelectionChecks
        for size in (0,1):
            reference=SelectionChecks().fixture(size)
            check_selection(reference,0,reference)
            for bad in (reference.replace('FF800001','FF800002'),reference.replace('id=80','id=84'),SelectionChecks().fixture(1-size)):
                with self.assertRaises(ValueError):check_selection(reference,0,bad)
            with self.assertRaises(ValueError):check_selection(reference,124,reference)
    def test_incomplete(self):
        for status in (None,124,0):
            with self.assertRaises(ValueError):check('PASS original fixed-choice services',status)
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('reference',type=Path,nargs='?');p.add_argument('--status',type=int);p.add_argument('--native',type=Path);p.add_argument('--native-status',type=int);p.add_argument('--selftest',action='store_true');p.add_argument('--selection-reference',type=Path);p.add_argument('--selection-status',type=int);a=p.parse_args()
    if a.selftest:raise SystemExit(not unittest.TextTestRunner().run(unittest.defaultTestLoader.loadTestsFromTestCase(Checks)).wasSuccessful())
    try:
        bytecheck(Path('tmp/runtime-data/Alone In The Dark'));ref=a.reference.read_text();check(ref,a.status)
        if a.native:
            native=a.native.read_text();check(native,a.native_status,True)
            corruptions=[native.replace('visible=0','visible=1'),native.replace('freeDelta=384','freeDelta=383'),native.replace('flags=00000000','flags=00000001'),native.replace('after=FF800001010101000000','after=FF800001000101000000'),native+native,native.replace('CHOICE_WINDOW id=80','CHOICE_WINDOW id=84'),native.replace('WINDOW_BYTES data=2079','WINDOW_BYTES data=2078'),native.replace('offset=109A','offset=1272')]
            for bad,status in [(n,0) for n in corruptions]+[(native,124),(native,None)]:
                try:check(bad,status,True)
                except ValueError:continue
                raise ValueError('native corruption accepted')
        if a.selection_reference:
            if not a.native:raise ValueError('selection comparison needs native capture')
            check_selection(a.selection_reference.read_text(),a.selection_status,native)
            print('PASS paired original WIND 128 selection and complete preference bytes')
        for old,new in [('type=4','type=5'),('rect=003C001D00500081','rect=003C001D00500082'),('PASS original fixed-choice services','')]:
            try:check(ref.replace(old,new),0)
            except ValueError:continue
            raise ValueError('corruption accepted')
        print('PASS fixed-choice services: original bytes, item 2, owned lookup/disposal, world restore, preserved registers and preferences')
    except (ValueError,OSError,KeyError,AttributeError) as e:raise SystemExit('FAIL fixed-choice services: '+str(e))
