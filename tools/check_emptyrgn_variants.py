#!/usr/bin/env python3
"""Verify original EmptyRgn shape queries and exact word-register effects."""
import argparse
import struct
from pathlib import Path
from check_driver22 import ROOT, fields, one
from resource_fork import read_resource_fork

SHAPES = (
    '000A0000000000000000', '000AFFFDFFFE00040007',
    '000A0004FFFE00040007', '000A0005FFFE00040007',
    '000AFFFD000800040007',
    '00240001000200040008000100020004000600087FFF000400020004000600087FFF7FFF',
)


def check(text, status):
    if (status != 0 or any(x in text for x in ('FAIL', 'TIMEOUT', 'LUA ERROR'))
            or text.count('PASS original EmptyRgn variants cases=6') != 1
            or text.count('Exited via the debugger') != 1):
        raise ValueError('reference completion')
    code = next(r.body for r in read_resource_fork(ROOT/'tmp/runtime-data/Alone In The Dark')
                if r.kind == b'CODE' and r.rid == 4)
    raw = bytearray(code[0x417a:0x4188])
    if raw.hex() != '42272f39ffff4038a8e24a1f6608':
        raise ValueError('original caller')
    original = fields(one(text, r'^EMPTYRGN_ENTER (.*)$'))
    struct.pack_into('>I', raw, 4, (original['a5']-0xbfc8) & 0xffffffff)
    if one(text, r'^EMPTYRGN_BYTES (\w+)$') != raw.hex().upper():
        raise ValueError('live original caller')
    for i, shape in enumerate(SHAPES, 1):
        e, r = [fields(one(text, rf'^EMPTY_VARIANT_{phase} n={i} (.*)$'))
                for phase in ('ENTER', 'RETURN')]
        before, after = [(ROOT/'tmp'/f'emptyrgn-variants-reference-case{i}-{phase}.bin').read_bytes()
                         for phase in ('enter', 'return')]
        data = bytes.fromhex(shape)
        if before != data+bytes([0xa5])*(64-len(data)) or before != after:
            raise ValueError(f'case {i}: full region and guards')
        top, left, bottom, right = struct.unpack_from('>hhhh', data, 2)
        empty = top >= bottom or left >= right
        if r['result'] != (int(empty) << 8 | e['result'] & 255) or r['sp'] != e['sp']+4:
            raise ValueError(f'case {i}: Boolean/padding/stack')
        if r['d0'] != (e['d0'] & 0xffff0000 | top & 65535) or r['d1'] != (e['d1'] & 0xffff0000 | left & 65535):
            raise ValueError(f'case {i}: word-register effects')
        if r['a0'] != e['body']+(8 if top >= bottom else 10) or r['a1'] != e['call']+2:
            raise ValueError(f'case {i}: address-register effects')
        for key in ['handle', 'body', 'call', 'memerr']+[f'd{n}' for n in range(2, 8)]+[f'a{n}' for n in range(2, 7)]:
            if e[key] != r[key]:
                raise ValueError(f'case {i}: preserved {key}')
        if not e['handle'] or not e['body'] or e['memerr']:
            raise ValueError(f'case {i}: owned fixture allocation')
    print('PASS original EmptyRgn: six empty/nonempty/inverted/complex shapes, full guards, Boolean padding and exact register/stack effects')


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('reference', type=Path)
    p.add_argument('--status', type=int, required=True)
    a = p.parse_args()
    try:
        check(a.reference.read_text(), a.status)
    except (ValueError, OSError, KeyError) as error:
        raise SystemExit('FAIL EmptyRgn variants: '+str(error))
