#!/usr/bin/env python3
"""Check authorized original active-loop RAM fixtures against full driver state."""
import argparse,re,struct
from pathlib import Path
from check_driver22 import fields,one
ROOT=Path(__file__).resolve().parents[1]
def check(folder,status,native=None,native_status=None):
    text=(folder/'mac.log').read_text()
    if status or re.search(r'FAIL|TIMEOUT|LUA ERROR|Error in',text) or text.count('PASS original active loop stop/replacement contract')!=1 or text.count('Exited via the debugger')!=1:raise ValueError('normal completion')
    e,r=[fields(one(text,r'^LOOP_ACTION_'+phase+r' (.*)$')) for phase in ('ENTER','RETURN')]
    fixture=fields(one(text,r'^LOOP_ACTION_FIXTURE (.*)$'))
    action=e['action'];sample,size,rate,start,end,counter,ident=struct.unpack('>6IH',(folder/'packet.bin').read_bytes())
    if action not in (17,18) or r['action']!=action or r['packet']!=e['packet'] or r['sp']!=e['sp']+4 or r['d0'] or r['d1']!=(e['packet'] if action==18 else (e['packet']&0xffff0000)|0x7fff):raise ValueError('action ABI')
    if e['counter']!=65535 or r['counter']!=65535 or r['tick']!=e['tick']:raise ValueError('immediate action preserves loop counter')
    for reg in [f'd{i}' for i in range(2,8)]+[f'a{i}' for i in range(7)]:
        if e[reg]!=r[reg]:raise ValueError('preserved '+reg)
    if (size,rate,start,end,ident)!=(4096,8000<<16,0 if action==17 else 512,0 if action==17 else 1024,0x8001 if action==17 else 0x8000):raise ValueError('packet fixture')
    driver=(folder/'driver.bin').read_bytes();original=(ROOT/'tmp/plan/MDRV_11.bin').read_bytes()
    # Relocation changes absolute addresses; these entry/dispatch/selection bodies
    # contain no relocations and must remain byte-for-byte original instructions.
    for a,b in ((0,12),(0x3506,0x3606)):
        if driver[a:b]!=original[a:b]:raise ValueError('unchanged original instructions')
    before=(folder/'enter-state.bin').read_bytes();after=(folder/'return-state.bin').read_bytes()
    if len(before)!=0x3048 or len(after)!=len(before):raise ValueError('complete state')
    v=0x22d2+6*4
    if not sample+512<=struct.unpack_from('>I',before,v)[0]<sample+1024 or struct.unpack_from('>H',before,v+0x200)[0]!=0x7fff:raise ValueError('actively repeating source')
    expected=bytearray(before);struct.pack_into('>IIH',expected,0,action,e['packet'],0)
    if action==18:struct.pack_into('>H',expected,v+0x200,0xffff)
    else:
        if struct.unpack_from('>H',before,0x11c4)[0]!=1:raise ValueError('single occupied slot fixture')
        longs={0:sample,0x40:((rate>>5)//11127)<<5,0x80:0,0x240:0,0x280:sample+size,0x2c0:0,0x300:0,0x340:(fixture['entry']|0x80000000)+0x4200+0x2ca6,0x3c0:0,0x540:counter,0x640:0x00800080}
        for offset,value in longs.items():struct.pack_into('>I',expected,v+offset,value)
        for offset,value in {0x200:0x7ffe,0x440:ident,0x500:0x7fff,0x580:0}.items():struct.pack_into('>H',expected,v+offset,value)
    if expected!=after:raise ValueError('exact stop/replacement full-state transition')
    if native is not None:
        n=native.read_text()
        if native_status or re.search(r'FAIL|TIMEOUT|Error in|Program received signal',n) or n.count('PASS native active loop action ABI, counter, interrupt restoration and DMA/memory cleanup')!=1 or n.count('[Inferior 1 (Remote target) detached]')!=1:raise ValueError('native normal completion')
        values=tuple(map(int,one(n,r'^EFFECT_LOOP_ACTION action=(\d+) elapsed=(\d+) counter=(\d+) starts=(\d+) stops=(\d+)$')))
        if values[0]!=action or values[1]>1 or values[2:]!=(65535,2 if action==17 else 1,1):raise ValueError('native immediate action/counter/ownership')
        if action==17:
            expected_pcm=bytes(v^128 for v in (folder/'sample.bin').read_bytes())+b'\0\0'
            if (folder/'native-pcm.bin').read_bytes()!=expected_pcm:raise ValueError('replacement exact converted PCM and silent tail')
        print(f'PASS native paired loop action {action}: immediate return, preserved counter/ABI, restored interrupt and complete DMA/memory cleanup')
    print(f'PASS original active loop action {action}: immediate return, preserved ABI/counter, exact full-state transition')
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('folder',type=Path);p.add_argument('--status',type=int,required=True);p.add_argument('--native',type=Path);p.add_argument('--native-status',type=int);a=p.parse_args()
    try:check(a.folder,a.status,a.native,a.native_status)
    except (ValueError,OSError,KeyError) as e:p.exit(1,f'FAIL loop action: {e}\n')
