#!/usr/bin/env python3
"""Verify the original selector-13 word setter and native original-call ABI."""
import argparse, re, struct
from pathlib import Path
from check_driver22 import fields, one, ROOT
from resource_fork import read_resource_fork

def check(text,status,native=None,native_status=None):
    if status!=0 or any(x in text for x in ('FAIL','LUA ERROR','timeout','Error in')) or text.count('PASS original driver13 selector-13 parameter and isolated state fixture')!=1 or text.count('Exited via the debugger')!=1:
        raise ValueError('reference completion')
    code=next(r.body for r in read_resource_fork(ROOT/'tmp/runtime-data/Alone In The Dark') if r.kind==b'CODE' and r.rid==3)
    raw=code[0x1374:0x1382]
    if raw.hex()!='2f004878000d206df9544e90508f' or one(text,r'^DRIVER13_BYTES (\w+)$')!=raw.hex().upper(): raise ValueError('original/live caller')
    driver=(ROOT/'tmp/driver13-reference-driver.bin').read_bytes()
    for offset,expected in ((0,'202f0004222f000848e73ffe'),(0x68,'600002de'),(0x348,'202c0004394000386000fd58')):
        if driver[offset:offset+len(expected)//2].hex()!=expected: raise ValueError('driver instruction bytes')
    for fixture in (False,True):
        prefix='FIXTURE_' if fixture else ''
        e,r=[fields(one(text,r'^DRIVER13_'+prefix+phase+r' (.*)$')) for phase in ('ENTER','RETURN')]
        argument=0x12345678 if fixture else 0
        if e['selector']!=13 or e['argument']!=argument or r['sp']!=e['sp'] or r['d0']!=0 or r['d1']!=argument: raise ValueError('arguments/stack/result')
        for reg in [f'd{i}' for i in range(2,8)]+[f'a{i}' for i in range(7)]:
            if e[reg]!=r[reg]: raise ValueError('preserved '+reg)
        before=(ROOT/'tmp'/f'driver13-reference-{prefix.lower()}enter-state.bin').read_bytes()
        after=(ROOT/'tmp'/f'driver13-reference-{prefix.lower()}return-state.bin').read_bytes()
        if len(before)!=0x3048 or len(after)!=len(before): raise ValueError('complete state')
        expected=bytearray(before);struct.pack_into('>IIH',expected,0,13,argument,0);struct.pack_into('>H',expected,0x38,argument&0xffff)
        if expected!=after: raise ValueError('exact selector-13 transition')
    if native:
        t=native.read_text()
        if native_status!=0 or any(x in t for x in ('FAIL','Error in','timeout','Cannot execute','Remote connection closed')) or t.count('PASS native driver13 parameter ABI')!=1 or t.count('[Inferior 1 (Remote target) detached]')!=1: raise ValueError('native completion')
        call=fields(one(t,r'^DRIVER13_NATIVE_CALL (.*)$'))
        if call['selector']!=13 or call['argument']!=0: raise ValueError('native call arguments')
        if one(t,r'^DRIVER13_NATIVE_BYTES (\w+)$')!=raw.hex().upper(): raise ValueError('native caller')
        if (ROOT/'tmp/driver13-native-enter-state.bin').read_bytes()!=(ROOT/'tmp/driver13-native-return-state.bin').read_bytes(): raise ValueError('zero setter changed native state')
        if 'DRIVER13_NATIVE_RETURN argument=0 value=0' not in t: raise ValueError('native parameter')
    print('PASS driver13: original caller/dispatch bytes, exact word state/truncation, stack and preserved registers')
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('reference',type=Path);p.add_argument('--status',type=int,required=True);p.add_argument('--native',type=Path);p.add_argument('--native-status',type=int);a=p.parse_args()
    try: check(a.reference.read_text(),a.status,a.native,a.native_status)
    except (ValueError,OSError,KeyError) as e: raise SystemExit('FAIL driver13: '+str(e))
