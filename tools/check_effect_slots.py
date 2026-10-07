#!/usr/bin/env python3
"""Verify RAM-only original effect-slot fixtures, including exact state and D1."""
import argparse
from pathlib import Path
import re
import struct
from check_driver22 import fields
from resource_fork import read_resource_fork
ROOT=Path(__file__).resolve().parents[1]

def check(folder,status,native=None,native_status=None):
    text=(folder/'mac.log').read_text()
    if status or re.search(r'FAIL|TIMEOUT|LUA ERROR|Error in',text) or text.count('PASS original isolated effect slot allocation')!=1 or text.count('Exited via the debugger')!=1:
        raise ValueError('normal completion')
    entries=[fields(v) for v in re.findall(r'^DRIVER17_ENTER (.*)$',text,re.M)]
    returns=[fields(v) for v in re.findall(r'^DRIVER17_RETURN (.*)$',text,re.M)]
    if len(entries)!=4 or len(returns)!=4:raise ValueError('four fixture calls')
    code=next(r.body for r in read_resource_fork(ROOT/'tmp/runtime-data/Alone In The Dark') if r.kind==b'CODE' and r.rid==3)
    if re.findall(r'^DRIVER17_BYTES (\w+)$',text,re.M)!=[code[0x17ea:0x1800].hex().upper()]*4:raise ValueError('four unchanged original callers')
    driver=(folder/'driver.bin').read_bytes();original=(ROOT/'tmp/plan/MDRV_11.bin').read_bytes()
    if driver[0x3506:0x3606]!=original[0x3506:0x3606]:raise ValueError('unchanged original selection code')
    for i,(e,r,slot,age) in enumerate(zip(entries,returns,(6,7,6,7),(0x7fff,0x7ffe,0x7ff0,0x7ff0)),1):
        if r['sp']!=e['sp'] or e['selector']!=17 or r['d0'] or r['d1']!=((e['ignored']&0xffff0000)|age):raise ValueError(f'call {i} ABI/selection age')
        for reg in [f'd{n}' for n in range(2,8)]+[f'a{n}' for n in range(7)]:
            if e[reg]!=r[reg]:raise ValueError(f'call {i} preserved {reg}')
        before=(folder/f'{i}-enter-state.bin').read_bytes();after=(folder/f'{i}-return-state.bin').read_bytes()
        if len(before)!=0x3048 or len(after)!=len(before):raise ValueError('full state')
        if struct.unpack_from('>3H',before,0x11c0)!=(6,2,2):raise ValueError('voice limits')
        if i>=3 and tuple(struct.unpack_from('>H',before,0x24d2+n*4)[0] for n in (6,7))!=(0x7ff0,0x7ff5 if i==3 else 0x7ff0):raise ValueError('explicit age fixture')
        packet=(folder/f'{i}-packet.bin').read_bytes()
        sample,size,rate,start,end,counter,ident=struct.unpack('>6IH',packet)
        if (size,rate,start,end,ident)!=(4096,8000<<16,0,0,0x8000+i):raise ValueError('packet identity')
        expected=bytearray(before);struct.pack_into('>IIH',expected,0,17,e['ignored'],0)
        voice=0x22d2+slot*4
        longs={0:sample,0x40:((rate>>5)//11127)<<5,0x80:0,0x240:0,0x280:sample+size,0x2c0:0,0x300:0,0x340:(e['entry']|0x80000000)+0x4200+0x2ca6,0x3c0:0,0x540:counter,0x640:0x00800080}
        for offset,value in longs.items():struct.pack_into('>I',expected,voice+offset,value)
        for offset,value in {0x200:0x7ffe,0x440:ident,0x500:0x7fff,0x580:0}.items():struct.pack_into('>H',expected,voice+offset,value)
        if expected!=after:raise ValueError(f'call {i} exact selected-slot transition')
    if native is not None:
        n=native.read_text()
        if native_status or re.search(r'FAIL|TIMEOUT|Error in|Program received signal',n) or n.count('PASS native effect slots selection, replacement and cleanup')!=1:
            raise ValueError('native fixture completion')
        records=re.findall(r'^EFFECT_SLOTS stage=(\d+) index=(\d+) age=(\w+) channel=(\d+) starts=(\d+) stops=(\d+) live=(\d+)$',n,re.M)
        if len(records)!=4:raise ValueError('four native allocations')
        pcm=(folder/'sample.bin').read_bytes();expected_pcm=bytes(v^128 for v in pcm)+b'\0\0'
        for i,(row,index,age) in enumerate(zip(records,(0,1,0,1),(0x7fff,0x7ffe,0x7ff0,0x7ff0)),1):
            if int(row[0])!=i or int(row[1])!=index or int(row[2],16)!=age or int(row[4])!=i or int(row[5])!=max(0,i-2):raise ValueError('native allocation sequence')
            if (folder/f'native-chip-{i}.bin').read_bytes()!=expected_pcm:raise ValueError('native identical PCM/silence tail')
        cleanup=re.findall(r'^EFFECT_SLOTS_CLEANUP live=(\d+) baseline=(\d+) errors=(\d+)$',n,re.M)
        if len(cleanup)!=1 or cleanup[0][0]!=cleanup[0][1] or int(cleanup[0][2]):raise ValueError('native allocation cleanup')
        print('PASS native paired effect slots: identical PCM, exact selection/D1, retained channels and unselected buffers, released DMA and zero Chip leak')
    print('PASS original effect slots: first free, second free D1, oldest occupied, later tied slot; full state and preserved ABI')

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('folder',type=Path);p.add_argument('--status',type=int,required=True);p.add_argument('--native',type=Path);p.add_argument('--native-status',type=int);a=p.parse_args()
    try:check(a.folder,a.status,a.native,a.native_status)
    except (ValueError,OSError) as e:p.exit(1,f'FAIL effect slots: {e}\n')
