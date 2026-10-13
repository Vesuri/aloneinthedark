#!/usr/bin/env python3
"""Check cached RGB traps' complete port mutations, register/CCR and stack ABI."""
import argparse
from pathlib import Path
import re
import struct
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('log',type=Path);p.add_argument('--status',type=int,required=True)
a=p.parse_args();text=a.log.read_text();root=Path(__file__).resolve().parents[1]
assert a.status==0 and 'PASS RGB cache ABI 64 calls' in text
assert not any(x in text for x in ('FAIL','Error in sourced command file','timeout'))
rows=re.findall(r'^RGBABI_(ENTER|RETURN) (.+)$',text,re.M)
assert len(rows)==128
hits=0;traps=set()
for i in range(64):
    assert rows[i*2][0]=='ENTER' and rows[i*2+1][0]=='RETURN'
    e=dict(re.findall(r'(\w+)=(\w+)',rows[i*2][1]))
    r=dict(re.findall(r'(\w+)=(\w+)',rows[i*2+1][1]))
    assert int(e['n'])==int(r['n'])==i+1
    op=int(e['trap'],16);assert op in (0xaa14,0xaa15);traps.add(op)
    assert int(r['sp'],16)==int(e['sp'],16)+4 and r['ccr']==e['ccr']
    for reg in ['d'+str(j) for j in range(2,8)]+['a'+str(j) for j in range(2,7)]:
        assert r[reg]==e[reg],(i,reg)
    assert r['a1']==r['expectedA1'],(i,'inverse collision pointer')
    index=int(r['d0'],16);assert int(r['d1'],16)==index and index<256
    offset=80 if op==0xaa14 else 84
    assert int(r['a0'],16)==int(e['port'],16)+offset
    before=bytearray((root/f'tmp/rgb-cache-abi-{i+1}-before.bin').read_bytes())
    after=(root/f'tmp/rgb-cache-abi-{i+1}-after.bin').read_bytes()
    assert len(before)==len(after)==108
    color=36 if op==0xaa14 else 42
    before[color:color+6]=bytes.fromhex(e['rgb'])
    struct.pack_into('>I',before,offset,index)
    assert before==after,(i,'port mutation')
    hits+=int(r['hit'])
assert hits>=32 and len(traps)==2,(hits,traps)
print(f'PASS RGB ABI: 64 real calls, {hits} assembly hits, both setters, full port/register/CCR/stack checks')
