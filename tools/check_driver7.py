#!/usr/bin/env python3
"""Verify the original song-release call against its exact driver state changes."""
import argparse
import re
import struct
from pathlib import Path
from check_driver22 import ROOT, fields, one
from resource_fork import read_resource_fork


def check(text, status):
    if (status != 0 or any(x in text for x in ('FAIL', 'LUA ERROR', 'Error in'))
            or text.count('PASS original driver7 natural call') != 1
            or text.count('Exited via the debugger') != 1):
        raise ValueError('reference completion')
    code = next(r.body for r in read_resource_fork(ROOT/'tmp/runtime-data/Alone In The Dark')
                if r.kind == b'CODE' and r.rid == 3)
    raw = code[0x1404:0x1410]
    if raw.hex() != '48780007206df9544e90588f' or one(text, r'^DRIVER7_BYTES (\w+)$') != raw.hex().upper():
        raise ValueError('original/live caller')
    driver = (ROOT/'tmp/driver7-reference-driver.bin').read_bytes()
    for offset, expected in ((0, '202f0004222f000848e73ffe'), (0x50, '60000326'),
                             (0x378, '61003b9e6000fd2c')):
        if driver[offset:offset+len(expected)//2].hex() != expected:
            raise ValueError('original release dispatch')
    e, r = [fields(one(text, r'^DRIVER7_'+phase+r' (.*)$')) for phase in ('ENTER', 'RETURN')]
    if e['selector'] != 7 or r['sp'] != e['sp'] or r['d0'] != 0 or r['d1'] != e['argument'] or r['sr'] & 31 != 4:
        raise ValueError('stack/result/flags')
    for reg in [f'd{i}' for i in range(2, 8)]+[f'a{i}' for i in range(7)]:
        if e[reg] != r[reg]:
            raise ValueError('preserved '+reg)
    before = (ROOT/'tmp/driver7-reference-enter-state.bin').read_bytes()
    after = (ROOT/'tmp/driver7-reference-return-state.bin').read_bytes()
    if len(before) != 0x3048 or len(after) != len(before):
        raise ValueError('complete state')
    expected = bytearray(before)
    struct.pack_into('>IIH', expected, 0, 7, e['argument'], 0)
    for offset in (0x36, 0x172, 0x182a):
        struct.pack_into('>H', expected, offset, 0)
    for offset in (0x6a, 0x6e, 0xd7c):
        struct.pack_into('>I', expected, offset, 0)
    expected[0x174:0x574] = bytes(0x400)
    offset = 0x57c
    while struct.unpack_from('>I', before, offset)[0]:
        if offset >= 0xd7c:
            raise ValueError('sample release list bound')
        struct.pack_into('>I', expected, offset, 0)
        offset += 4
    voices = struct.unpack_from('>H', before, 0x11c0)[0]
    if voices != 6:
        raise ValueError('measured music voice configuration')
    for i in range(voices):
        struct.pack_into('>I', expected, 0x24d2+4*i, 0xffffffff)
    if expected != after:
        raise ValueError('exact state transition')
    print('PASS original driver7: caller, resource-pointer release, effect preservation, stack/registers/CCR')


def check_native(text, status):
    if (status != 0 or any(x in text for x in ('FAIL', 'Error in', 'TIMEOUT', 'Program received signal'))
            or text.count('PASS native driver7 release ABI') != 1
            or text.count('[Inferior 1 (Remote target) detached]') != 1):
        raise ValueError('native completion')
    if one(text, r'^DRIVER7_NATIVE_BYTES (\w+)$') != '48780007206DF9544E90588F':
        raise ValueError('native caller')
    row = fields(one(text, r'^DRIVER7_NATIVE_RETURN (.*)$'))
    if (row['d0'], row['d1'], row['ccr'], row['active']) != (0, 0, 4, 0):
        raise ValueError('native results')
    for name in ('config', 'effects'):
        before = (ROOT/'tmp'/f'driver7-native-enter-{name}.bin').read_bytes()
        after = (ROOT/'tmp'/f'driver7-native-return-{name}.bin').read_bytes()
        if not before or before != after:
            raise ValueError('native preserved '+name)
    entries = re.findall(r'^DRIVER7_HANDLE_ENTER n=(\d+) (.*)$', text, re.M)
    returns = re.findall(r'^DRIVER7_HANDLE_RETURN n=(\d+) (.*)$', text, re.M)
    if not entries or len(entries) != len(returns):
        raise ValueError('owned handle coverage')
    seen = set()
    for i, ((en, es), (rn, rs)) in enumerate(zip(entries, returns)):
        e, r = fields(es), fields(rs)
        if (int(en) != i or int(rn) != i or not e['handle'] or not e['body']
                or not e['flag'] & 1 or r['handle'] != e['handle']
                or r['body'] or r['flag'] or e['handle'] in seen):
            raise ValueError('owned handle disposal')
        seen.add(e['handle'])
    print(f'PASS native driver7: {len(entries)} owned handles disposed, song stopped, effects/config/registers preserved')


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('reference', type=Path)
    p.add_argument('--status', type=int, required=True)
    p.add_argument('--native', type=Path)
    p.add_argument('--native-status', type=int)
    a = p.parse_args()
    try:
        check(a.reference.read_text(), a.status)
        if a.native:
            check_native(a.native.read_text(), a.native_status)
    except (ValueError, OSError, KeyError) as error:
        raise SystemExit('FAIL driver7: '+str(error))
