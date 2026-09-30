#!/usr/bin/env python3
"""Verify the original selector-15 clock query and full-width return ABI."""
import argparse, struct, re
from pathlib import Path
from check_driver22 import fields, one, ROOT
from resource_fork import read_resource_fork

def check(text,status):
    if status!=0 or any(x in text for x in ('FAIL','LUA ERROR','timeout','Error in')) or text.count('PASS original driver15 selector-15 clock and isolated full-width fixture')!=1 or text.count('Exited via the debugger')!=1:
        raise ValueError('reference completion')
    code=next(r.body for r in read_resource_fork(ROOT/'tmp/runtime-data/Alone In The Dark') if r.kind==b'CODE' and r.rid==3)
    raw=code[0xfbe:0xfcc]
    if raw.hex()!='42a74878000f206df9544e90508f' or one(text,r'^DRIVER15_BYTES (\w+)$')!=raw.hex().upper(): raise ValueError('original/live caller')
    driver=(ROOT/'tmp/driver15-reference-driver.bin').read_bytes()
    for offset,expected in ((0,'202f0004222f000848e73ffe'),(0x70,'6000012a'),(0x19c,'202c18806000ff0e')):
        if driver[offset:offset+len(expected)//2].hex()!=expected: raise ValueError('driver instruction bytes')
    for fixture in (False,True):
        prefix='FIXTURE_' if fixture else ''
        e,r=[fields(one(text,r'^DRIVER15_'+prefix+phase+r' (.*)$')) for phase in ('ENTER','RETURN')]
        argument=0x12345678 if fixture else 0
        if e['selector']!=15 or e['argument']!=argument or r['sp']!=e['sp'] or r['d1']!=argument: raise ValueError('arguments/stack/result')
        for reg in [f'd{i}' for i in range(2,8)]+[f'a{i}' for i in range(7)]:
            if e[reg]!=r[reg]: raise ValueError('preserved '+reg)
        before=(ROOT/'tmp'/f'driver15-reference-{prefix.lower()}enter-state.bin').read_bytes()
        after=(ROOT/'tmp'/f'driver15-reference-{prefix.lower()}return-state.bin').read_bytes()
        if len(before)!=0x3048 or len(after)!=len(before): raise ValueError('complete state')
        expected=bytearray(before);struct.pack_into('>IIH',expected,0,15,argument,0)
        clock=struct.unpack_from('>I',before,0x1880)[0]
        if r['d0']!=clock or (fixture and clock!=0x89abcdef): raise ValueError('full-width clock result')
        if expected!=after: raise ValueError('exact selector-15 transition')
    print('PASS driver15: original caller/query bytes, full-width clock result, complete state and preserved registers')
def check_clock(text,status):
    if status!=0 or any(x in text for x in ('FAIL','LUA ERROR','timeout','Error in')) or text.count('PASS original driver clock observation')!=1 or text.count('Exited via the debugger')!=1:
        raise ValueError('clock observation completion')
    first=fields(one(text,r'^DRIVER_CLOCK_BEGIN (.*)$'))
    last=fields(one(text,r'^DRIVER_CLOCK_END (.*)$'))
    counts=fields(one(text,r'^DRIVER_CLOCK_COUNTS (.*)$'))
    delta=(last['clock']-first['clock'])&0xffffffff
    elapsed=(last['tick']-first['tick'])&0xffffffff
    if delta<1000 or delta!=counts['doublebuffer'] or counts['legacy'] or counts['device'] or abs(delta-elapsed)>1:
        raise ValueError('original callback clock versus Mac ticks')
    print(f'PASS original driver clock: {delta} double-buffer callbacks / {elapsed} Mac ticks')

def check_native(text,status):
    if status!=0 or any(x in text for x in ('FAIL','Error in','timeout','Cannot execute','Remote connection closed','Program received signal')) or text.count('PASS native driver15 clock ABI')!=1 or text.count('[Inferior 1 (Remote target) detached]')!=1:
        raise ValueError('native completion')
    if one(text,r'^DRIVER15_NATIVE_BYTES (\w+)$')!='42A74878000F206DF9544E90508F': raise ValueError('native caller bytes')
    result=fields(one(text,r'^DRIVER15_NATIVE_RETURN (.*)$'))
    low=(result['before']-result['origin'])&0xffffffff
    span=(result['after']-result['before'])&0xffffffff
    if not low or ((result['result']-low)&0xffffffff)>span: raise ValueError('native advancing clock')
    if (ROOT/'tmp/driver15-native-enter-state.bin').read_bytes()!=(ROOT/'tmp/driver15-native-return-state.bin').read_bytes(): raise ValueError('query changed driver state')
    if text.count('PASS menu-list next-stop original-MDRV=absent')!=1: raise ValueError('original MDRV absence')
    print('PASS native driver15: original caller/ABI, advancing full-width clock, unchanged driver state, MDRV absent')

def check_flags(reference,status,native=None,native_status=None):
    if status!=0 or any(x in reference for x in ('FAIL','LUA ERROR','timeout','Error in')) or reference.count('PASS original driver15 full-width condition codes cases=7')!=1 or reference.count('Exited via the debugger')!=1:
        raise ValueError('original flags completion')
    expected=[(i+1,value,value,0x12345678,flag) for i,(value,flag) in enumerate(zip((0,1,0x8000,0x10000,0x80000000,0x89abcdef,0xffffffff),(4,0,0,0,8,8,8)))]
    def rows(text,prefix):
        raw=re.findall(r'^'+prefix+r' n=(\d+) input=(\w+) result=(\w+) d1=(\w+) ccr=(\w+)$',text,re.M)
        return [(int(row[0]),*(int(x,16) for x in row[1:])) for row in raw]
    if rows(reference,'DRIVER15_FLAGS')!=expected: raise ValueError('original full-width flags')
    if native is not None:
        if native_status!=0 or any(x in native for x in ('FAIL','Error in','timeout','Cannot execute','Remote connection closed','Program received signal')) or native.count('PASS native driver15 condition-code fixture complete MDRV=absent')!=1 or native.count('[Inferior 1 (Remote target) detached]')!=1:
            raise ValueError('native flags completion')
        if rows(native,'DRIVER15_FLAGS_NATIVE')!=expected: raise ValueError('native full-width flags')
    print('PASS driver15 flags: seven 32-bit boundary results and X/N/Z/V/C')

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('reference',type=Path);p.add_argument('--status',type=int,required=True)
    p.add_argument('--clock',type=Path);p.add_argument('--clock-status',type=int)
    p.add_argument('--native',type=Path);p.add_argument('--native-status',type=int)
    p.add_argument('--flags',type=Path);p.add_argument('--flags-status',type=int)
    p.add_argument('--native-flags',type=Path);p.add_argument('--native-flags-status',type=int)
    a=p.parse_args()
    try:
        check(a.reference.read_text(),a.status)
        if a.clock:check_clock(a.clock.read_text(),a.clock_status)
        if a.native:check_native(a.native.read_text(),a.native_status)
        if a.flags:check_flags(a.flags.read_text(),a.flags_status,a.native_flags.read_text() if a.native_flags else None,a.native_flags_status)
    except (ValueError,OSError,KeyError) as e: raise SystemExit('FAIL driver15: '+str(e))
