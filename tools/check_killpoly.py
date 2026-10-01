#!/usr/bin/env python3
"""Paired original/native polygon disposal, heap ownership and isolation."""
import argparse,re,struct
from pathlib import Path
from check_driver22 import fields,one
ROOT=Path(__file__).resolve().parents[1]

def run(reference,status,native=None,native_status=None):
    text=reference.read_text()
    def complete(t,rc,marker,exit_marker):
        if rc!=0 or t.count(marker)!=1 or t.count(exit_marker)!=1 or re.search(r'FAIL|LUA ERROR|Error in|TIMEOUT|Timed out|Program received signal',t):raise ValueError('completion')
    complete(text,status,'COMPLETE original pond polygon disposal','Exited via the debugger')
    raw=(ROOT/'tmp/segments/CODE_4_Dark').read_bytes()[0x340e:0x3412]
    if raw.hex()!='2f0ca8cd' or one(text,r'^KILL_BYTES n=19 data=(\w+)$')!=raw.hex().upper():raise ValueError('original bytes')
    e,r=[fields(one(text,rf'^KILL_{phase} n=19 (.*)$')) for phase in ('ENTER','RETURN')]
    if e['trap']!=0xa8cd or e['args']!=e['poly'] or e['size']!=54 or r['size'] or r['sp']!=e['sp']+4 or r['d0'] or r['a0']!=e['poly'] or r['memerr']:raise ValueError('original ABI')
    preserved=[f'd{i}' for i in range(1,8)]+[f'a{i}' for i in range(2,7)]
    for reg in preserved:
        if e[reg]!=r[reg]:raise ValueError('original preserved '+reg)
    h0,h1=[fields(one(text,rf'^KILL_HEAP phase={phase} (.*)$')) for phase in ('ENTER','RETURN')]
    z0=(ROOT/'tmp/killpoly-reference-19-ENTER-zone.bin').read_bytes();z1=(ROOT/'tmp/killpoly-reference-19-RETURN-zone.bin').read_bytes()
    if h0['zone']!=h1['zone'] or h1['free']!=h0['free']+64 or h0['master']!=e['body'] or h1['master']!=struct.unpack_from('>I',z0,8)[0]:raise ValueError('original disposal/free master chain')
    expected=bytearray(z0);struct.pack_into('>II',expected,8,e['poly'],h0['free']+64)
    if expected!=z1:raise ValueError('original zone transition')
    for suffix in ('port','region'):
        if (ROOT/f'tmp/killpoly-reference-19-ENTER-{suffix}.bin').read_bytes()!=(ROOT/f'tmp/killpoly-reference-19-RETURN-{suffix}.bin').read_bytes():raise ValueError('original changed '+suffix)
    if (ROOT/'tmp/killpoly-reference-ENTER-pixels.bin').read_bytes()!=(ROOT/'tmp/killpoly-reference-RETURN-pixels.bin').read_bytes():raise ValueError('original drawing')
    owner=fields(one(text,r'^KILL_OWNER (.*)$'));size=fields(one(text,r'^KILL_SIZE (.*)$'));flags=fields(one(text,r'^KILL_FLAGS (.*)$'))
    if size['size']!=244 or size['memerr'] or flags['flags'] or flags['memerr'] or owner['owner']!=owner['zone'] or owner['memerr']:raise ValueError('preserved region ownership')
    if native:
        t=native.read_text();complete(t,native_status,'PASS native KillPoly and continuation','[Inferior 1 (Remote target) detached]')
        a,b=[fields(one(t,rf'^KILL_NATIVE_{phase} (.*)$')) for phase in ('ENTER','RETURN')]
        if a['size']!=54 or b['sp']!=a['sp']+4 or b['d0'] or b['a0']!=a['poly'] or b['memerr'] or b['master'] or b['flags'] or b['free']!=a['free']+a['span']:raise ValueError('native ABI/heap disposal')
        for reg in preserved:
            if a[reg]!=b[reg]:raise ValueError('native preserved '+reg)
        if (ROOT/'tmp/killpoly-native-ENTER-poly.bin').read_bytes()!=(ROOT/'tmp/killpoly-reference-19-ENTER-poly.bin').read_bytes():raise ValueError('native polygon input')
        for suffix in ('port','region','pixels'):
            if (ROOT/f'tmp/killpoly-native-ENTER-{suffix}.bin').read_bytes()!=(ROOT/f'tmp/killpoly-native-RETURN-{suffix}.bin').read_bytes():raise ValueError('native changed '+suffix)
        if (ROOT/'tmp/killpoly-native-RETURN-region.bin').read_bytes()!=(ROOT/'tmp/killpoly-reference-19-RETURN-region.bin').read_bytes():raise ValueError('native retained region')
        if not re.search(r'^KILL_NATIVE_ISOLATION frames=\d+ book=0$',t,re.M):raise ValueError('native drawing isolation')
        next_stop=one(t,r'^KILL_NEXT trap=(\w+) segment=(\w+) offset=(\w+) routine=(.+)$')
        if tuple(int(x,16) for x in next_stop[:3])==(0xa8cd,4,0x3410) or next_stop[3]=='UNKNOWN TRAP':raise ValueError('no named continuation')
    print('PASS KillPoly: original bytes/ABI, exact freed master/zone transition, retained region and pixels'+('; paired native ownership/ABI and continuation' if native else ''))

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--reference',type=Path,required=True);p.add_argument('--status',type=int,required=True);p.add_argument('--native',type=Path);p.add_argument('--native-status',type=int);a=p.parse_args()
    if a.native and a.native_status is None:p.error('--native requires --native-status')
    run(a.reference,a.status,a.native,a.native_status)
