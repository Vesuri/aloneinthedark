#!/usr/bin/env python3
"""Pair original RGB colour calls and complete port/pattern state transitions."""
import argparse
from pathlib import Path
import re,struct
from resource_fork import read_resource_fork
ROOT=Path(__file__).resolve().parents[1]

def rows(text):
    lines=[s for s in text.splitlines() if s.startswith(('RGB_ENTER ','RGB_RETURN '))]
    if len(lines)%2:raise ValueError('unpaired colour call')
    result=[]
    for i in range(0,len(lines),2):
        if not lines[i].startswith('RGB_ENTER ') or not lines[i+1].startswith('RGB_RETURN '):raise ValueError('colour call order')
        result.append(tuple(dict(re.findall(r'(\w+)=([^ ]+)',s)) for s in lines[i:i+2]))
    return result

def check(text,status,side,window=False):
    if window and side=='native':
        text='\n'.join(line.replace('WRGB_','RGB_') for line in text.splitlines() if not line.startswith('RGB_'))
    if status!=0 or any(s in text for s in ('FAIL','LUA ERROR','Error in sourced command file','Program received signal','timeout')):raise ValueError(side+' completion')
    marker='PASS original RGB colours and 64 fixtures' if side=='reference' else ('PASS native original window RGB foreground/background' if window else 'PASS native original RGB foreground/background')
    ending='Exited via the debugger' if side=='reference' else '[Inferior 1 (Remote target) detached]'
    if text.count(marker)!=1 or text.count(ending)!=1:raise ValueError(side+' positive terminal control')
    pairs=rows(text)
    if len(pairs)!=(66 if side=='reference' else 2):raise ValueError(side+' call count')
    code=next(r.body for r in read_resource_fork(ROOT/'tmp/runtime-data/Alone In The Dark') if r.kind==b'CODE' and r.rid==(12 if window else 13))
    start=0x6244 if window else 0x2b8
    if code[start:start+16]!=bytes.fromhex('2f3cfffff002aa142f3cfffff008aa15'):raise ValueError('original colour call bytes')
    for i,(e,r) in enumerate(pairs):
        original,fixture=(i+1,0) if i<2 else (2,i-1)
        trap=0xaa14 if i%2==0 else 0xaa15
        if any(int(d['original'])!=original or int(d['fixture'])!=fixture or int(d['trap'],16)!=trap for d in (e,r)):raise ValueError('call attribution')
        if i<2:
            live=bytearray(code[start+8*i:start+8+8*i]);live[2:6]=((int.from_bytes(live[2:6],'big')+int(e['a5'],16))&0xffffffff).to_bytes(4,'big')
            if re.findall(rf'^RGB_BYTES original={i+1} data=([0-9A-F]+)$',text,re.M)!=[live.hex().upper()]:raise ValueError('live original/A5 bytes')
        if int(r['sp'],16)!=int(e['sp'],16)+4 or r['port']!=e['port'] or r['rgb']!=e['rgb']:raise ValueError('stack/port/input preservation')
        index=int(r['fore' if trap==0xaa14 else 'back'],16)
        if int(r['d0'],16)!=index or int(r['d1'],16)!=index or int(r['a0'],16)!=int(e['port'],16)+(80 if trap==0xaa14 else 84):raise ValueError('colour result registers')
        for reg in 'd3 d4 d5 d6 d7 a2 a3 a4 a5 a6'.split():
            if e[reg]!=r[reg]:raise ValueError('preserved register '+reg)
        name=str(original) if fixture==0 else 'fixture'+str(fixture)
        def data(phase,kind):return (ROOT/f'tmp/{"window-rgb" if window else "rgb"}-{side}-{name}-{phase}-{kind}.bin').read_bytes()
        before=data('enter','port');after=data('return','port');expected=bytearray(before)
        colorOffset=36 if trap==0xaa14 else 42;indexOffset=80 if trap==0xaa14 else 84
        expected[colorOffset:colorOffset+6]=bytes.fromhex(e['rgb']);struct.pack_into('>I',expected,indexOffset,index)
        if len(before)!=108 or after!=expected:raise ValueError('exact port colour mutation')
        if window and side=='native':
            if any(before[o:o+4]!=bytes(4) for o in (32,58,62)):raise ValueError('unsupported native window pattern')
            continue
        for kind in ('pen','back','fill'):
            if data('enter',kind)!=data('return',kind):raise ValueError('unexpected pattern mutation')
    return pairs

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('reference',type=Path);p.add_argument('--status',type=int,required=True);p.add_argument('--native',type=Path);p.add_argument('--native-status',type=int);a=p.parse_args()
    try:
        reference=check(a.reference.read_text(),a.status,'reference')
        print('PASS RGB reference: original bytes/A5 relocation, 2 calls and 64 fixtures, exact RGB/index writes, unchanged patterns and ABI')
        if a.native:
            text=a.native.read_text();native=check(text,a.native_status,'native')
            from check_native_driver import check as startup_check
            startup_check(text,a.native_status)
            for (e,r),(me,mr) in zip(native,reference):
                for key in ('rgb','fore','back','fields'):
                    if e[key]!=me[key] or r[key]!=mr[key]:raise ValueError('paired original colour '+key)
            print('PASS paired original RGB foreground/background: port colours, ABI, unchanged patterns, next stop and MDRV exclusion')
    except (ValueError,OSError,KeyError) as error:raise SystemExit('FAIL RGB colours: '+str(error))
