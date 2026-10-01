#!/usr/bin/env python3
"""Paired evidence for SoundMusicSys targeted effect stop (selector 18)."""
import argparse
from pathlib import Path
import re
import struct
from check_driver22 import fields, one
ROOT=Path(__file__).resolve().parents[1]

def check(log,status,native=None,native_status=None):
    text=log.read_text()
    if status!=0 or text.count('COMPLETE original driver18 targeted stop')!=1 or text.count('Exited via the debugger')!=1 or re.search(r'FAIL|LUA ERROR|TIMEOUT|Timed out',text):raise ValueError('reference completion')
    raw=(ROOT/'tmp/segments/CODE_3_Core').read_bytes()[0x1820:0x182c]
    if raw.hex()!='48780012206df9544e90508f' or one(text,r'^DRIVER18_BYTES (\w+)$')!=raw.hex().upper():raise ValueError('caller bytes')
    driver=(ROOT/'tmp/driver18-reference-driver.bin').read_bytes()
    original=(ROOT/'tmp/plan/MDRV_11.bin').read_bytes()
    for start,end in [(0,12),(0x7c,0x80),(0x1ca,0x1d6),(0x36b0,0x36e2)]:
        if driver[start:end]!=original[start:end]:raise ValueError('live original driver instructions')
    e,r=[fields(one(text,rf'^DRIVER18_{phase} (.*)$')) for phase in ('ENTER','RETURN')]
    if e['selector']!=18 or r['sp']!=e['sp'] or r['d0']!=0 or r['d1']!=e['ignored']:raise ValueError('stack/result')
    for reg in [f'd{i}' for i in range(2,8)]+[f'a{i}' for i in range(7)]:
        if e[reg]!=r[reg]:raise ValueError('preserved '+reg)
    packet=(ROOT/'tmp/driver18-reference-packet.bin').read_bytes()
    if len(packet)!=26:raise ValueError('packet extent')
    identifier=struct.unpack_from('>H',packet,24)[0]
    before=(ROOT/'tmp/driver18-reference-enter-state.bin').read_bytes();after=(ROOT/'tmp/driver18-reference-return-state.bin').read_bytes()
    if len(before)!=0x3048 or len(after)!=len(before):raise ValueError('complete driver state')
    expected=bytearray(before);struct.pack_into('>IIH',expected,0,18,e['ignored'],0)
    first=struct.unpack_from('>H',before,0x11c0)[0];count=struct.unpack_from('>H',before,0x11c4)[0];stopped=[]
    if first+count>8:raise ValueError('effect slot bounds')
    for i in range(first,first+count):
        age=struct.unpack_from('>H',before,0x24d2+i*4)[0];stored=struct.unpack_from('>H',before,0x2712+i*4)[0]
        if age<0x8000 and stored==identifier:
            struct.pack_into('>H',expected,0x24d2+i*4,0xffff);stopped.append(i)
    if expected!=after:raise ValueError('targeted stop state differs')
    if native:
        t=native.read_text()
        if native_status!=0 or t.count('PASS native driver18 targeted stop and pond continuation')!=1 or t.count('[Inferior 1 (Remote target) detached]')!=1 or re.search(r'FAIL|Error in|TIMEOUT|Timed out',t):raise ValueError('native completion')
        a,b=[fields(one(t,rf'^DRIVER18_NATIVE_{phase} (.*)$')) for phase in ('ENTER','RETURN')]
        if b['sp']!=a['sp'] or b['d0']!=0 or b['d1']!=a['argument']:raise ValueError('native result/stack')
        for reg in [f'd{i}' for i in range(2,8)]+[f'a{i}' for i in range(7)]:
            if a[reg]!=b[reg]:raise ValueError('native preserved '+reg)
        stopped_native=0
        for slot in range(2):
            pattern=rf'^DRIVER18_EFFECT_{{}} slot={slot} id=(\w+) active=(\d+) channel=(-?\d+) chip=(\w+)$'
            before=one(t,pattern.format('ENTER'));after=one(t,pattern.format('RETURN'))
            ident,active,channel,chip=int(before[0],16),int(before[1]),int(before[2]),int(before[3],16)
            if active and ident==a['identifier']:
                stopped_native+=1
                if after!=(before[0],'0','-1','0'):raise ValueError('native targeted sample cleanup')
            elif before!=after:raise ValueError('native unrelated effect changed')
        if stopped_native<1:raise ValueError('native active-effect coverage absent')
        if (ROOT/'tmp/driver18-native-enter-songs.bin').read_bytes()!=(ROOT/'tmp/driver18-native-return-songs.bin').read_bytes():raise ValueError('native music changed')
    print(f'PASS driver18: original bytes, ABI, complete state; identifier={identifier:04X}, stopped={stopped}')

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('reference',type=Path);p.add_argument('--status',type=int,required=True);p.add_argument('--native',type=Path);p.add_argument('--native-status',type=int);a=p.parse_args();check(a.reference,a.status,a.native,a.native_status)
