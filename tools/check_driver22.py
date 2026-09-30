#!/usr/bin/env python3
"""Original effect-stop driver contract, including a nonplaying state fixture."""
import argparse,re,struct
from pathlib import Path
from resource_fork import read_resource_fork
ROOT=Path(__file__).resolve().parents[1]
def fields(s):return {k:int(v,16) for k,v in re.findall(r'(\w+)=([0-9A-Fa-f]+)(?= |$)',s)}
def one(text,pattern):
    matches=re.findall(pattern,text,re.M)
    if len(matches)!=1:raise ValueError('missing/duplicate '+pattern)
    return matches[0]
def check(text,status,native=None,native_status=None):
    if status!=0 or any(x in text for x in ('FAIL','LUA ERROR','timeout','Error in')) or text.count('PASS original driver22 stop-effects and isolated state fixture')!=1 or text.count('Exited via the debugger')!=1:raise ValueError('reference completion')
    code=next(r.body for r in read_resource_fork(ROOT/'tmp/runtime-data/Alone In The Dark') if r.kind==b'CODE' and r.rid==3)
    raw=code[0x1a6c:0x1a78]
    if raw.hex()!='48780016206df9544e90588f' or one(text,r'^DRIVER22_BYTES (\w+)$')!=raw.hex().upper():raise ValueError('original/live caller')
    driver=(ROOT/'tmp/driver22-reference-driver.bin').read_bytes()
    if driver[:12].hex()!='202f0004222f000848e73ffe' or one(text,r'^DRIVER22_ENTRY_BYTES (\w+)$')!=driver[:12].hex().upper():raise ValueError('original driver entry')
    if driver[0x8c:0x90].hex()!='60000134' or driver[0x1c2:0x1ca].hex()!='610034426000fee2' or driver[0x3606:0x3628].hex()!='43ec22d2382c11c0e544d2c4302c11c46700000e337cffff0200584951c8fff64e75':raise ValueError('selector dispatch/stop instructions')
    for fixture in (False,True):
        prefix='FIXTURE_' if fixture else ''
        e,r=[fields(one(text,r'^DRIVER22_'+prefix+phase+r' (.*)$')) for phase in ('ENTER','RETURN')]
        if e['selector']!=22 or r['sp']!=e['sp'] or r['d0']!=0 or r['d1']!=e['ignored']:raise ValueError('stack/result')
        for reg in [f'd{i}' for i in range(2,8)]+[f'a{i}' for i in range(7)]:
            if e[reg]!=r[reg]:raise ValueError('preserved '+reg)
        before=(ROOT/'tmp'/f'driver22-reference-{prefix.lower()}enter-state.bin').read_bytes();after=(ROOT/'tmp'/f'driver22-reference-{prefix.lower()}return-state.bin').read_bytes()
        if len(before)!=0x3048 or len(after)!=len(before):raise ValueError('complete driver state')
        expected=bytearray(before);struct.pack_into('>IIH',expected,0,22,e['ignored'],0)
        # The original DBRA also clears its following unused slot. Preserve all
        # sample pointers, music voice slots, mixer configuration and other data.
        for i in (6,7,8):struct.pack_into('>H',expected,0x24d2+i*4,0xffff)
        if expected!=after:raise ValueError('exact stop-effects transition')
    if native:
        t=native.read_text()
        from check_native_driver import check as startup
        startup(t,native_status)
        if native_status!=0 or any(x in t for x in ('FAIL','Error in','timeout')) or t.count('PASS native driver22 stop-effects ABI')!=1 or t.count('[Inferior 1 (Remote target) detached]')!=1:raise ValueError('native completion')
        if one(t,r'^DRIVER22_NATIVE_BYTES (\w+)$')!=raw.hex().upper():raise ValueError('native caller bytes')
        if 'DRIVER22_NATIVE_RETURN calls=3 initialized=1 rate=11 interpolation=1 limits=6/2/2 effects=0/0' not in t:raise ValueError('native state')
        if (ROOT/'tmp/driver22-native-enter-state.bin').read_bytes()!=(ROOT/'tmp/driver22-native-return-state.bin').read_bytes():raise ValueError('inactive native voice/config preservation')
    print('PASS driver22: original selector/caller bytes, exact original and fixture state changes, results and preserved ABI')
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('reference',type=Path);p.add_argument('--status',type=int,required=True);p.add_argument('--native',type=Path);p.add_argument('--native-status',type=int);a=p.parse_args()
    try:check(a.reference.read_text(),a.status,a.native,a.native_status)
    except (ValueError,OSError,KeyError) as e:raise SystemExit('FAIL driver22: '+str(e))
