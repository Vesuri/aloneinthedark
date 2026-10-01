#!/usr/bin/env python3
"""Verify the original menu click's selected-port inverse conversion."""
import argparse
import struct
from pathlib import Path
from check_driver22 import ROOT, fields, one
from resource_fork import read_resource_fork


def check(text, status):
    if (status != 0 or any(x in text for x in ('FAIL', 'TIMEOUT', 'LUA ERROR'))
            or text.count('PASS original GlobalToLocal call') != 1
            or text.count('Exited via the debugger') != 1):
        raise ValueError('reference completion')
    e = fields(one(text, r'^GL_ENTRY (.*)$'))
    r = fields(one(text, r'^GL_RETURN (.*)$'))
    code = next(x.body for x in read_resource_fork(ROOT/'tmp/runtime-data/Alone In The Dark')
                if x.kind == b'CODE' and x.rid == 7)
    raw = code[0x16e0:0x16ec]
    if raw.hex() != '27530004486b0004a871206e' or e['caller'] != int(raw.hex(), 16):
        raise ValueError('original/live caller')
    prefix = ROOT/'tmp/globallocal-reference-inverse-'
    before, after, port, pm = [Path(str(prefix)+x+'.bin').read_bytes()
                               for x in ('before', 'after', 'port', 'pm')]
    if tuple(map(len, (before, after, port, pm))) != (12, 12, 108, 50):
        raise ValueError('point guards and selected port capture sizes')
    if struct.unpack_from('>H', pm, 32)[0] != 8:
        raise ValueError('selected eight-bit port')
    bounds = struct.unpack_from('>hhhh', pm, 6)
    if bounds != (-150, -160, 330, 480) or e['bounds'] != int(pm[6:14].hex(), 16):
        raise ValueError('measured live screen origin')
    v, h = struct.unpack_from('>HH', before, 4)
    expected = bytearray(before)
    struct.pack_into('>HH', expected, 4, (v+bounds[0]) & 65535, (h+bounds[1]) & 65535)
    if expected != after or e['value'] != int(before[4:8].hex(), 16) or r['value'] != int(after[4:8].hex(), 16):
        raise ValueError('point conversion/adjacent bytes')
    if r['sp'] != e['args']+4:
        raise ValueError('argument cleanup')
    for reg in [f'd{i}' for i in range(8)]+[f'a{i}' for i in range(7)]:
        if e[reg] != r[reg]:
            raise ValueError('preserved '+reg)
    print('PASS original GlobalToLocal: Engine+16E8, selected live origin, point/guards, stack and all registers')


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('reference', type=Path)
    p.add_argument('--status', type=int, required=True)
    a = p.parse_args()
    try:
        check(a.reference.read_text(), a.status)
    except (ValueError, OSError, KeyError) as error:
        raise SystemExit('FAIL GlobalToLocal: '+str(error))
