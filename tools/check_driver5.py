#!/usr/bin/env python3
"""Verify the original song-stop call against its exact driver state changes."""
import argparse
import struct
from pathlib import Path
from check_driver22 import ROOT, fields, one
from resource_fork import read_resource_fork


def check(text, status):
    if (status != 0 or any(x in text for x in ('FAIL', 'LUA ERROR', 'Error in'))
            or text.count('PASS original driver5 natural call') != 1
            or text.count('Exited via the debugger') != 1):
        raise ValueError('reference completion')
    code = next(r.body for r in read_resource_fork(ROOT/'tmp/runtime-data/Alone In The Dark')
                if r.kind == b'CODE' and r.rid == 3)
    raw = code[0x13f8:0x1404]
    if raw.hex() != '48780005206df9544e90588f' or one(text, r'^DRIVER5_BYTES (\w+)$') != raw.hex().upper():
        raise ValueError('original/live caller')
    driver = (ROOT/'tmp/driver5-reference-driver.bin').read_bytes()
    for offset, expected in (
            (0, '202f0004222f000848e73ffe'),
            (0x48, '60000318'),
            (0x362, '426c003870ff610012ae6000fd3c'),
            (0x1618, '41ec1ba843ec1a2872173401e5424a406b06b070200066044271200051c9ffec61001a8a4e75'),
            (0x30c4, '302c11c06710534041ec24d220fcffffffff51c8fff84e75')):
        if driver[offset:offset+len(expected)//2].hex() != expected:
            raise ValueError('original stop instructions')
    e, r = [fields(one(text, r'^DRIVER5_'+phase+r' (.*)$')) for phase in ('ENTER', 'RETURN')]
    if e['selector'] != 5 or r['sp'] != e['sp'] or r['d0'] != 0 or r['d1'] != 0xffff or r['sr'] & 31 != 4:
        raise ValueError('stack/result/flags')
    for reg in [f'd{i}' for i in range(2, 8)]+[f'a{i}' for i in range(7)]:
        if e[reg] != r[reg]:
            raise ValueError('preserved '+reg)
    before = (ROOT/'tmp/driver5-reference-enter-state.bin').read_bytes()
    after = (ROOT/'tmp/driver5-reference-return-state.bin').read_bytes()
    if len(before) != 0x3048 or len(after) != len(before):
        raise ValueError('complete state')
    expected = bytearray(before)
    struct.pack_into('>IIH', expected, 0, 5, e['argument'], 0)
    struct.pack_into('>H', expected, 0x38, 0)
    for i in range(24):
        struct.pack_into('>H', expected, 0x1a28+4*i, 0)
    voices = struct.unpack_from('>H', before, 0x11c0)[0]
    if voices != 6:
        raise ValueError('measured music voice configuration')
    for i in range(voices):
        struct.pack_into('>I', expected, 0x24d2+4*i, 0xffffffff)
    if expected != after:
        raise ValueError('exact state transition')
    print('PASS original driver5: caller, stop instructions, all tracks/music voices, resource/effect preservation, stack/registers/CCR')


def check_native(text, status):
    if (status != 0 or any(x in text for x in ('FAIL', 'Error in', 'TIMEOUT', 'Program received signal'))
            or text.count('PASS native driver5 stop ABI') != 1
            or text.count('[Inferior 1 (Remote target) detached]') != 1):
        raise ValueError('native completion')
    if one(text, r'^DRIVER5_NATIVE_BYTES (\w+)$') != '48780005206DF9544E90588F':
        raise ValueError('native caller')
    row = fields(one(text, r'^DRIVER5_NATIVE_RETURN (.*)$'))
    if (row['d0'], row['d1'], row['ccr'], row['active']) != (0, 0xffff, 4, 0):
        raise ValueError('native results')
    for name in ('config', 'effects', 'resources'):
        before = (ROOT/'tmp'/f'driver5-native-enter-{name}.bin').read_bytes()
        after = (ROOT/'tmp'/f'driver5-native-return-{name}.bin').read_bytes()
        if not before or before != after:
            raise ValueError('native preserved '+name)
    print('PASS native driver5: original caller, DMA cleanup, retained resources/effects, stack/registers/CCR')


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
        raise SystemExit('FAIL driver5: '+str(error))
