#!/usr/bin/env python3
"""Verify original death-fade ABI and exact mixer lookup tables."""
import argparse,struct
from pathlib import Path
from check_driver22 import ROOT,fields,one
from resource_fork import read_resource_fork

def check(text,status):
    if status or any(s in text for s in ('FAIL','LUA ERROR','timeout')) or text.count('PASS original driver19 death fade and 33 gain fixtures')!=1 or text.count('Exited via the debugger')!=1:
        raise ValueError('reference completion')
    folder=ROOT/'tmp/m3-toolbox'
    code=next(r.body for r in read_resource_fork(ROOT/'tmp/runtime-data/Alone In The Dark') if r.kind==b'CODE' and r.rid==3)
    if one(text,r'^DRIVER19_BYTES (\w+)$')!=code[0x1f00:0x1f0e].hex().upper():raise ValueError('original/live caller')
    driver=(folder/'driver19-driver.bin').read_bytes()
    original=(ROOT/'tmp/plan/MDRV_11.bin').read_bytes()
    if driver[:0x41a8]!=original[:0x41a8] or driver[0x80:0x84].hex()!='6000017c' or driver[0x1fe:0x206].hex()!='61001c346000fea6':raise ValueError('original driver instructions')
    for prefix,gain in [('',248)]+[(f'FIXTURE_{i}_',256-(i-1)*8) for i in range(1,34)]:
        e,r=[fields(one(text,r'^DRIVER19_'+prefix+phase+r' (.*)$')) for phase in ('ENTER','RETURN')]
        if e['gain']!=gain or r['sp']!=e['sp'] or r['d0'] or r['d1']!=65535 or r['sr']&31!=4:raise ValueError('ABI result')
        for reg in [f'd{i}' for i in range(2,8)]+[f'a{i}' for i in range(7)]:
            if e[reg]!=r[reg]:raise ValueError('preserved '+reg)
        capture=lambda phase,kind:(folder/f'driver19-{prefix.lower()}{phase}-{kind}.bin').read_bytes()
        before=capture('enter','state');after=capture('return','state')
        expected=bytearray(before);struct.pack_into('>IIH',expected,0,19,gain,0)
        if expected!=after:raise ValueError('exact state transition '+prefix)
        before_table=capture('enter','table');after_table=capture('return','table')
        # Six music + twice one effect = eight inputs, normalized to three.
        start=128-gain//2
        values=[start+(i*gain//256) for i in range(256)]
        end=(start+gain)&255
        if not end:end=255
        expected_table=bytes([start])*640+bytes(v for v in values for _ in range(3))+bytes([end])*640+before_table[-4:]
        if after_table!=expected_table:raise ValueError('exact mixer gain table '+prefix)
    print('PASS driver19: original caller/instructions, 34 paired ABI/state captures and exact mixer tables')
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('reference',type=Path);p.add_argument('--status',required=True,type=int);a=p.parse_args()
    try:check(a.reference.read_text(),a.status)
    except (ValueError,OSError,KeyError) as e:raise SystemExit('FAIL driver19: '+str(e))
