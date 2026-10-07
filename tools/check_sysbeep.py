#!/usr/bin/env python3
"""Pair the authorized RAM-only Mac SysBeep fixture with the real native trap."""
import argparse
from pathlib import Path
import re
from check_driver22 import fields, one
from resource_fork import read_resource_fork
ROOT = Path(__file__).resolve().parents[1]

def check(original, native, folder, original_status, native_status):
    for text, status in ((original, original_status), (native, native_status)):
        if status or re.search(r'FAIL|TIMEOUT|LUA ERROR|Error in', text):
            raise ValueError('normal fixture completion')
    if original.count('PASS original isolated SysBeep duration 1') != 1 or original.count('Exited via the debugger') != 1:
        raise ValueError('original completion marker')
    code = next(r.body for r in read_resource_fork(ROOT/'tmp/runtime-data/Alone In The Dark') if r.kind == b'CODE' and r.rid == 7)
    expected = '3F2E0008A9C84E5E4E75'
    if code[0x4f44:0x4f4e].hex().upper() != expected or one(original, r'^SYSBEEP_BYTES (\w+)$') != expected:
        raise ValueError('original resource and live wrapper identity')
    if 'duration=1' not in one(original, r'^SYSBEEP_FIXTURE (.*)$'):
        raise ValueError('isolated duration fixture')
    enter, leave = [fields(one(original, r'^SYSBEEP_'+phase+r' (.*)$')) for phase in ('ENTER','RETURN')]
    if leave['sp'] != enter['sp']+2 or leave['d0'] or leave['tick']-enter['tick'] != 3:
        raise ValueError('original stack/result/duration')
    for reg in [f'd{i}' for i in range(1,8)]+[f'a{i}' for i in range(1,7)]:
        if enter[reg] != leave[reg]:
            raise ValueError('original preserved '+reg)
    if native.count('PASS native SysBeep actual trap, priority click, interrupt progress and cleanup') != 1:
        raise ValueError('native actual-trap completion')
    before, after, errors = map(int, one(native, r'^SYSBEEP_NATIVE_LEDGER before=(\d+) after=(\d+) errors=(\d+)$'))
    if before != after or errors:
        raise ValueError('native Chip memory cleanup')
    channel, _, allocated, period, _ = one(native, r'^SYSBEEP_NATIVE_STARTED channel=(\d+) chip=(\w+) allocated=(\d+) period=(\d+) dma=(\w+)$')
    if int(channel)>3 or int(allocated)!=130 or int(period)!=443:
        raise ValueError('native click descriptor')
    pcm = (folder/'native-chip.bin').read_bytes()
    if len(pcm)!=130 or pcm[-2:]!=b'\0\0' or not any(pcm[:128]):
        raise ValueError('bounded non-silent click with silence tail')
    signed = [v if v<128 else v-256 for v in pcm[:128]]
    if min(signed)>=0 or max(signed)<=0 or max(map(abs,signed[-16:]))>=max(map(abs,signed[:16])):
        raise ValueError('bipolar decaying click')
    effects = [(folder/f'native-effects-{phase}.bin').read_bytes() for phase in ('before','after')]
    if len(effects[0])!=16 or effects[0]!=effects[1]:
        raise ValueError('unchanged active effect ownership')
    print('PASS paired SysBeep duration 1: original ABI and three ticks; native actual trap, music interrupt progress, priority click, retained effect and zero Chip leak')

if __name__ == '__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('original',type=Path);p.add_argument('native',type=Path);p.add_argument('folder',type=Path)
    p.add_argument('--original-status',type=int,required=True);p.add_argument('--native-status',type=int,required=True)
    a=p.parse_args()
    try: check(a.original.read_text(),a.native.read_text(),a.folder,a.original_status,a.native_status)
    except (ValueError,OSError,StopIteration) as e: p.exit(1,f'FAIL SysBeep: {e}\n')
