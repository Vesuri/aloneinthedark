#!/usr/bin/env python3
"""Check measured RectRgn resizing, empty inputs and handle-state preservation."""
import argparse
import struct
from pathlib import Path
from check_driver22 import ROOT, fields, one
from resource_fork import read_resource_fork

RECTS = ('FFFDFFFE00040007', 'FFFDFFFE00040007', '0004FFFE00040007',
         '0005FFFE00040007', 'FFFD000800040007', 'FFFDFFFE00040007',
         'FFFDFFFE00040007')
FLAGS = (0, 0, 0, 0, 0, 0x80, 0x40)
COMPLEX = bytes.fromhex('00240001000200040008000100020004000600087FFF000400020004000600087FFF7FFF')


def check(text, status):
    if (status != 0 or any(x in text for x in ('FAIL', 'TIMEOUT', 'LUA ERROR'))
            or text.count('PASS original RectRgn variants cases=7') != 1
            or text.count('Exited via the debugger') != 1):
        raise ValueError('reference completion')
    code = next(r.body for r in read_resource_fork(ROOT/'tmp/runtime-data/Alone In The Dark')
                if r.kind == b'CODE' and r.rid == 4)
    raw = bytearray(code[0x3d36:0x3d48])
    if raw.hex() != '2f39ffff40342079ffff3db248680016a8df':
        raise ValueError('original caller')
    original = fields(one(text, r'^RECTRGN_ENTER (.*)$'))
    for at in (2, 8):
        struct.pack_into('>I', raw, at, (struct.unpack_from('>I', raw, at)[0]+original['a5']) & 0xffffffff)
    if one(text, r'^RECTRGN_BYTES (\w+)$') != raw.hex().upper():
        raise ValueError('live original caller')
    check_cases(text, 'reference')


def check_cases(text, side):
    for i, (rectangle, flags) in enumerate(zip(RECTS, FLAGS), 1):
        rows = {label: fields(one(text, rf'^RECT_VARIANT_{label} n={i} (.*)$'))
                for label in ('ENTER', 'RETURN', 'SIZE', 'FLAGS', 'OWNER')}
        e, r = rows['ENTER'], rows['RETURN']
        def data(phase, kind):
            return (ROOT/'tmp'/f'rectrgn-variants-{side}-case{i}-{phase}-{kind}.bin').read_bytes()
        rect = bytes.fromhex(rectangle)
        initial = bytes.fromhex('000a0000000000000000') if i == 1 else COMPLEX+bytes([0xa5])*28
        if data('enter', 'region') != initial:
            raise ValueError(f'case {i}: initial region allocation')
        if data('enter', 'rect') != bytes([0xa5])*4+rect+bytes([0xa5])*4 or data('return', 'rect') != data('enter', 'rect'):
            raise ValueError(f'case {i}: rectangle/guards')
        top, left, bottom, right = struct.unpack('>hhhh', rect)
        empty = top >= bottom or left >= right
        if data('return', 'region') != b'\0\x0a'+(bytes(8) if empty else rect):
            raise ValueError(f'case {i}: complete output region')
        expected_d0 = left if top < bottom and left >= right else top
        # The 24-bit Mac tags master pointers; the port stores flags separately.
        expected_a1 = r['body'] | (flags << 24 if side == 'reference' else 0)
        if r['d0'] != (expected_d0 & 65535) or r['a0'] != e['handle'] or r['a1'] != expected_a1 or r['sp'] != e['sp']+8:
            raise ValueError(f'case {i}: result registers/stack')
        for key in ('handle', 'body', 'rect', 'memerr', *[f'd{n}' for n in range(1, 8)], *[f'a{n}' for n in range(2, 7)]):
            if e[key] != r[key]:
                raise ValueError(f'case {i}: preserved {key}')
        if rows['SIZE'] != {'size': 10, 'memerr': 0} or rows['FLAGS'] != {'flags': flags, 'memerr': 0}:
            raise ValueError(f'case {i}: resize/handle state')
        owner = rows['OWNER']
        if not e['handle'] or not e['body'] or e['memerr'] or not owner['owner'] or owner['owner'] != owner['zone'] or owner['memerr']:
            raise ValueError(f'case {i}: owning zone/error')
    print(f'PASS {side} RectRgn: seven resize/empty/inverted/locked/purgeable cases, exact bytes, registers, guards and ownership')


def check_native(text, status):
    if (status != 0 or any(x in text for x in ('FAIL', 'TIMEOUT', 'Error in', 'Program received signal'))
            or text.count('PASS native RectRgn variants cases=7') != 1
            or text.count('[Inferior 1 (Remote target) detached]') != 1):
        raise ValueError('native completion')
    check_cases(text, 'native')


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
        raise SystemExit('FAIL RectRgn variants: '+str(error))
