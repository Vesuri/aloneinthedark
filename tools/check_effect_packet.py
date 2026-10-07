#!/usr/bin/env python3
"""Check authorized isolated effect packet fixtures against the original driver."""
import argparse
from pathlib import Path
import re
import struct
from check_driver22 import fields, one
from resource_fork import read_resource_fork
ROOT=Path(__file__).resolve().parents[1]

def check(folder,status,native=None,native_status=None):
    text=(folder/'mac.log').read_text()
    if status or re.search(r'FAIL|TIMEOUT|LUA ERROR|Error in',text) or text.count('PASS original isolated effect packet and completion')!=1 or text.count('Exited via the debugger')!=1:
        raise ValueError('original completion')
    mode=one(text,r'^EFFECT_FIXTURE_CASE (loop3|fraction)$')
    code=next(r.body for r in read_resource_fork(ROOT/'tmp/runtime-data/Alone In The Dark') if r.kind==b'CODE' and r.rid==3)
    if one(text,r'^DRIVER17_BYTES (\w+)$')!=code[0x17ea:0x1800].hex().upper():raise ValueError('original caller')
    driver=(folder/'driver.bin').read_bytes(); original=(ROOT/'tmp/plan/MDRV_11.bin').read_bytes()
    if driver[0x3506:0x3606]!=original[0x3506:0x3606] or driver[:12].hex()!='202f0004222f000848e73ffe':raise ValueError('original driver')
    e,r=[fields(one(text,r'^DRIVER17_'+phase+r' (.*)$')) for phase in ('ENTER','RETURN')]
    if e['selector']!=17 or r['sp']!=e['sp'] or r['d0'] or r['d1']!=((e['ignored']&0xffff0000)|0x7fff):raise ValueError('original ABI')
    for reg in [f'd{i}' for i in range(2,8)]+[f'a{i}' for i in range(7)]:
        if e[reg]!=r[reg]:raise ValueError('original preserved '+reg)
    packet=(folder/'packet.bin').read_bytes()
    sample,size,rate,start,end,counter,ident=struct.unpack('>6IH',packet)
    if (size,rate,start,end,ident)!=(4096,(8000<<16)+(32768 if mode=='fraction' else 0),512 if mode=='loop3' else 0,1024 if mode=='loop3' else 0,0x8000):raise ValueError('fixture packet')
    if one(text,r'^DRIVER17_PACKET (\w+)$')!=packet.hex().upper():raise ValueError('packet capture')
    before=(folder/'enter-state.bin').read_bytes(); after=(folder/'return-state.bin').read_bytes()
    if len(before)!=0x3048 or len(after)!=len(before):raise ValueError('complete state')
    expected=bytearray(before);struct.pack_into('>IIH',expected,0,17,e['ignored'],0)
    voice=0x22d2+6*4
    longs={0:sample,0x40:((rate>>5)//11127)<<5,0x80:0,0x240:0,0x280:sample+size,
           0x2c0:sample+start if start else 0,0x300:sample+end if end else 0,
           0x340:(e['entry']|0x80000000)+0x4200+0x2ca6,0x3c0:0,0x540:counter,0x640:0x00800080}
    for offset,value in longs.items():struct.pack_into('>I',expected,voice+offset,value)
    for offset,value in {0x200:0x7ffe,0x440:ident,0x500:0x7fff,0x580:0}.items():struct.pack_into('>H',expected,voice+offset,value)
    if after!=expected:raise ValueError('exact original play state')
    complete=(folder/'complete-state.bin').read_bytes(); finish=fields(one(text,r'^DRIVER17_COMPLETE (.*)$'))
    if len(complete)!=len(before) or finish['cursor']!=sample+size or finish['loopword'] or struct.unpack_from('>H',complete,voice+0x200)[0]!=0xffff:raise ValueError('sample tail completion')
    observed=re.findall(r'^EFFECT_FIXTURE_TICK elapsed=(\d+) cursor=(\w+) end=(\w+) active=(\w+) counter=(-?\d+)$',text,re.M)
    counters=[int(row[4]) for row in observed]
    if not observed or set(counters)!=({0,1,2,3} if mode=='loop3' else {0}) or counters!=sorted(counters,reverse=True):raise ValueError('loop counter progression')
    if not 28<=finish['elapsed']<=(43 if mode=='loop3' else 34):raise ValueError('bounded original duration')
    pcm=(folder/'sample.bin').read_bytes()
    if len(pcm)!=size:raise ValueError('owned sample extent')
    if native is not None:
        n=native.read_text()
        if mode!='fraction' or native_status or re.search(r'FAIL|TIMEOUT|Error in|Program received signal',n) or n.count('PASS native fractional effect packet, playback and cleanup')!=1:raise ValueError('native completion')
        native_packet=(folder/'native-packet.bin').read_bytes()
        if native_packet[4:20]!=packet[4:20] or native_packet[24:]!=packet[24:]:raise ValueError('native packet')
        if (folder/'native-sample.bin').read_bytes()!=pcm or (folder/'native-chip.bin').read_bytes()!=bytes(v^128 for v in pcm)+b'\0\0':raise ValueError('native PCM and silence tail')
        period,duration,elapsed=map(int,one(n,r'^EFFECT_FRACTION period=(\d+) duration=(\d+) elapsed=(\d+)$'))
        if period!=443 or duration!=31 or not 31<=elapsed<=33 or abs(elapsed-finish['elapsed'])>3:raise ValueError('paired pitch/duration')
    print(f'PASS isolated {mode}: original full state/ABI, counter progression and sample-tail completion'+('; paired native PCM, pitch, duration and cleanup' if native else ''))

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('folder',type=Path);p.add_argument('--status',type=int,required=True);p.add_argument('--native',type=Path);p.add_argument('--native-status',type=int);a=p.parse_args()
    try:check(a.folder,a.status,a.native,a.native_status)
    except (ValueError,OSError,StopIteration) as e:p.exit(1,f'FAIL effect packet: {e}\n')
