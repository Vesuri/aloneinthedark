#!/usr/bin/env python3
"""Pair the original selector-4 status query with exact state and flag contracts."""
import argparse,struct
from pathlib import Path
from check_driver22 import fields,one,ROOT
from resource_fork import read_resource_fork

def expected(state,following):
    enabled,control=struct.unpack_from('>HH',state,0x36)
    if not enabled:return 0,following
    if control:return 0xffff,following
    for i in range(24):
        if state[0x1a28+4*i]:return 0xffff,23-i
    return 0,0xffff

def check(text,status):
    if status!=0 or any(x in text for x in ('FAIL','LUA ERROR','timeout','Error in')) or text.count('PASS original driver4 status cases=7')!=1 or text.count('Exited via the debugger')!=1:
        raise ValueError('reference completion')
    code=next(r.body for r in read_resource_fork(ROOT/'tmp/runtime-data/Alone In The Dark') if r.kind==b'CODE' and r.rid==3)
    if code[0x1fc0:0x1fcc].hex()!='48780004206df9544e90588f' or one(text,r'^DRIVER4_BYTES (\w+)$')!='48780004206DF9544E90588F':raise ValueError('original/live caller')
    driver=(ROOT/'tmp/driver4-reference-driver.bin').read_bytes()
    for offset,want in ((0,'202f0004222f000848e73ffe'),(0x44,'6000030e'),(0x354,'70ff610012e6394000086000fd4a'),(0x163e,'4a6c003667164a6c0038661443ec1a2872174a11660a584951c9fff870004e7570ff4e75')):
        if driver[offset:offset+len(want)//2].hex()!=want:raise ValueError('original query instructions')
    cases=[(0,0x1234,0,0x0f00),(0xff00,1,-1,0),(1,0,0,0x0f00),(0xff00,0,23,0x0100),(0xff00,0,-1,0),(0xff00,0,7,0x8000),(0xff00,0,0,0x00ff)]
    for n in range(8):
        prefix='' if not n else f'FIXTURE{n}_'
        e,r=[fields(one(text,r'^DRIVER4_'+prefix+phase+r' (.*)$')) for phase in ('ENTER','RETURN')]
        before=(ROOT/'tmp'/f'driver4-reference-{prefix.lower()}enter-state.bin').read_bytes()
        after=(ROOT/'tmp'/f'driver4-reference-{prefix.lower()}return-state.bin').read_bytes()
        if len(before)!=0x3048 or len(after)!=len(before):raise ValueError('complete driver state')
        if n:
            enabled,control,slot,word=cases[n-1]
            if struct.unpack_from('>HH',before,0x36)!=(enabled,control):raise ValueError('fixture gates')
            for i in range(24):
                if struct.unpack_from('>H',before,0x1a28+i*4)[0]!=(word if i==slot else 0):raise ValueError('fixture tracks')
            if e['following']!=0x12345678:raise ValueError('fixture following word')
        d0,d1=expected(before,e['following']);ccr=8 if d0 else 4
        if e['selector']!=4 or r['sp']!=e['sp'] or r['d0']!=d0 or r['d1']!=d1 or r['sr']&31!=ccr:raise ValueError('result/stack/condition codes')
        if (e['sr']^r['sr'])&0xffe0:raise ValueError('preserved status-register mode')
        for reg in [f'd{i}' for i in range(2,8)]+[f'a{i}' for i in range(7)]:
            if e[reg]!=r[reg]:raise ValueError('preserved '+reg)
        want=bytearray(before);struct.pack_into('>IIH',want,0,4,e['following'],d0)
        if want!=after:raise ValueError('exact state transition')
    print('PASS original driver4: actual call and seven gates/track fixtures, full state, D0/D1, stack, preserved registers and CCR')

def check_native(text,status):
    if status!=0 or any(x in text for x in ('FAIL','Error in','timeout','Cannot execute','Remote connection closed','Program received signal')) or text.count('PASS native driver4 status ABI')!=1 or text.count('[Inferior 1 (Remote target) detached]')!=1:
        raise ValueError('native completion')
    if one(text,r'^DRIVER4_NATIVE_BYTES (\w+)$')!='48780004206DF9544E90588F':raise ValueError('native caller bytes')
    row=fields(one(text,r'^DRIVER4_NATIVE_RETURN (.*)$'))
    if (row['d0'],row['d1'],row['ccr'],row['active'])!=(0xffff,23,8,1):raise ValueError('native active-track status/flags')
    before=(ROOT/'tmp/driver4-native-enter-config.bin').read_bytes()
    after=(ROOT/'tmp/driver4-native-return-config.bin').read_bytes()
    if len(before)!=18 or before!=after:raise ValueError('preserved driver configuration/epoch')
    if text.count('PASS menu-list checkpoint original-MDRV=absent')!=1:raise ValueError('original MDRV absence')
    print('PASS native driver4: actual one-parameter caller, active-track result, D0/D1/CCR, stack/register/config preservation, MDRV absent')

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('reference',type=Path);p.add_argument('--status',type=int,required=True);p.add_argument('--native',type=Path);p.add_argument('--native-status',type=int);a=p.parse_args()
    try:
        check(a.reference.read_text(),a.status)
        if a.native:check_native(a.native.read_text(),a.native_status)
    except (ValueError,OSError,KeyError) as e:raise SystemExit('FAIL driver4: '+str(e))
