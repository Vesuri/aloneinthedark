#!/usr/bin/env python3
"""Check original startup menu calls, packed records and text mutations."""
import argparse
from pathlib import Path
import hashlib
import re
import unittest
from resource_fork import read_resource_fork

COMPLETE='PASS menu reference calls=21 inflight=0 secondTimes=14'
NATIVE_COMPLETE='PASS native menu calls=20 inflight=0 next=LOCALTOGLOBAL'
SITES={0xa950:(0x2dee,0x3a1f7601,4),0xa946:(0x2e0c,0x486eff00,10),0xa947:(0x2ec2,0x60027cff,10)}
PRESERVED=[f'd{n}' for n in range(3,8)]+[f'a{n}' for n in range(2,7)]
def fields(line):return {k:int(v,16) for k,v in re.findall(r'(\w+)=([0-9A-F]+)(?= |$)',line)}
def records(data):
    if len(data)<16 or 15+data[14]>=len(data):raise ValueError('short menu header/title')
    pos=15+data[14];items=[]
    while data[pos]:
        n=data[pos]
        if pos+5+n>=len(data):raise ValueError('short menu item/terminator')
        items.append((data[pos+1:pos+n+1],data[pos+n+1:pos+n+5]));pos+=n+5
    return data[:pos+1],items

def original(path):
    rows=read_resource_fork(path)
    core=next(r.body for r in rows if r.kind==b'CODE' and r.rid==7)
    if hashlib.sha256(core[0x2dea:0x2ed8]).hexdigest()!='c822f2345e89c14f43e95a7870f8f4d2c079523d4fc0bfdd1ef3f1f4d6ae3a68':
        raise ValueError('original menu-loop bytes')
    return {r.rid:r.body for r in rows if r.kind==b'MENU' and 128<=r.rid<=131}

def parse(text,status,native=False):
    complete=NATIVE_COMPLETE if native else COMPLETE
    arm="ARM native menu original Engine calls" if native else "ARM menu dispatcher bytes=2f0a2f02246f000a"
    if status!=0 or any(s in text for s in ('FAIL','unknown command','Error in breakpoint','Error in sourced command file','Program received signal','timeout')):
        raise ValueError('failed runner or debugger')
    if text.count(complete)!=1 or text.count(arm)!=1 or text.count('MENU_ARM count=A9503A1F get=A946486E set=A9476002')!=1 or text.count('[Inferior 1 (Remote target) detached]' if native else 'Exited via the debugger')!=1:
        raise ValueError('missing/duplicate positive completion')
    rows=[]
    for line in text.splitlines():
        if line.startswith('MENU_ENTER '):rows.append({'enter':fields(line)})
        elif line.startswith(('MENU_RETURN ','MENU_BEFORE ','MENU_AFTER ','TEXT_BEFORE ','TEXT_AFTER ')):
            if not rows:raise ValueError('return before entry')
            key=line.split()[0].lower();entry=rows[-1]
            if key in entry:raise ValueError('duplicate call evidence')
            if int(re.search(r'seq=([0-9A-F]+)',line)[1],16)!=entry['enter']['seq']:raise ValueError('call attribution')
            entry[key]=bytes.fromhex(line.split('data=')[1]) if 'data=' in line else fields(line)
    if len(rows)!=(32 if native else 33):raise ValueError('original call count')
    return rows

def check(text,status,menus,native=False):
    rows=parse(text,status,native);expected=[]
    for mid in range(128,132):
        _,items=records(menus[mid]);items=list(items)
        if mid==128 and not native:items.append((b'\0\0Control Panels',bytes(4)))
        expected.append((0xa950,mid,0))
        for number,(label,_) in enumerate(items,1):
            expected.append((0xa946,mid,number))
            if b'|' in label:expected.append((0xa947,mid,number))
    if len(expected)!=(32 if native else 33):raise ValueError('original menu definitions changed')
    last={};sets=0;gets=0
    for seq,(row,want) in enumerate(zip(rows,expected),1):
        e=row['enter'];r=row.get('menu_return',{});trap=e['trap'];offset,opcode,cleanup=SITES[trap]
        if e.get('seq')!=seq or (trap,e.get('menu'),e.get('item'))!=want or e.get('offset')!=offset or e.get('next')!=opcode:raise ValueError('original call sequence/bytes')
        if r.get('seq')!=seq or r.get('trap')!=trap or r.get('sp')!=e['sp']+cleanup or r.get('expected')!=r.get('sp') or r.get('d0')!=0:raise ValueError('result/stack contract')
        if any(e.get(k)!=r.get(k) for k in PRESERVED):raise ValueError('preserved register contract')
        before,items=records(row['menu_before']);after,changed=records(row['menu_after']);mid=e['menu']
        if int.from_bytes(before[:2],'big')!=mid or before[:2]+before[6:15+before[14]]!=after[:2]+after[6:15+after[14]]:raise ValueError('menu identity/title/flags/MDEF changed')
        if mid in last and before!=last[mid]:raise ValueError('menu continuity')
        if trap==0xa950:
            _,source=records(menus[mid]);extra=items[len(source):]
            if items[:len(source)]!=source or (extra and (native or mid!=128 or len(extra)!=1 or extra[0]!=(b'\0\0Control Panels',bytes(4)))):raise ValueError('original menu items/System addition')
            if r.get('result')!=len(items) or before!=after or (not native and r.get('a0')!=0):raise ValueError('count result or mutation')
        elif trap==0xa946:
            gets+=1;t=row['text_after'];label=items[e['item']-1][0]
            if t[:1+len(label)]!=bytes([len(label)])+label or before!=after:raise ValueError('GetMenuItemText result/mutation')
        else:
            sets+=1;t=row['text_before'];label=t[1:t[0]+1];n=e['item']-1
            if not label or label!=items[n][0].split(b'|')[0] or row['text_after'][:len(label)+1]!=t[:len(label)+1]:raise ValueError('SetMenuItemText argument/input preservation')
            expected_items=items[:];expected_items[n]=(label,items[n][1])
            if changed!=expected_items or after[2:6]!=b'\xff'*4:raise ValueError('SetMenuItemText record/attribute/size invalidation')
        last[mid]=after
    if gets!=(16 if native else 17) or sets!=12:raise ValueError('coverage')
    return rows

class Checks(unittest.TestCase):
    def test_records(self):
        data=bytes(14)+b'\x01M\x01A\x01\x02\x03\x04\0'
        body,items=records(data+b'ignored');self.assertEqual(body,data);self.assertEqual(items,[(b'A',b'\x01\x02\x03\x04')])
        for n in range(len(data)):
            with self.assertRaises(ValueError):records(data[:n])
    def test_incomplete(self):
        for data,status in (('',0),(COMPLETE,0),(COMPLETE,124),(COMPLETE,None)):
            with self.assertRaises(ValueError):parse(data,status)
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('log',nargs='?',type=Path);p.add_argument('--status',type=int);p.add_argument('--selftest',action='store_true');a=p.parse_args()
    if a.selftest:raise SystemExit(not unittest.TextTestRunner().run(unittest.defaultTestLoader.loadTestsFromTestCase(Checks)).wasSuccessful())
    try:
        check(a.log.read_text(),a.status,original(Path('tmp/runtime-data/Alone In The Dark')))
        print('PASS menu reference: 4 counts, 17 text reads, 12 exact mutations; original bytes, stack and preserved registers')
    except (OSError,ValueError,KeyError,AttributeError) as error:raise SystemExit('FAIL menu reference: '+str(error))
