#!/usr/bin/env python3
"""Paired occupied-effect replacement, clock age, ABI and sample ownership."""
import argparse
import re
import struct
from pathlib import Path
from check_driver22 import fields, one, ROOT
from resource_fork import read_resource_fork


def complete(text, status, marker, terminal):
    if status != 0 or text.count(marker) != 1 or text.count(terminal) != 1:
        raise ValueError('completion')
    if re.search(r'FAIL|LUA ERROR|Error in|[Tt][Ii][Mm][Ee][Oo][Uu][Tt]|Program received signal', text):
        raise ValueError('failed evidence')


def blob(name):
    return (ROOT / 'tmp' / ('effectreplace-' + name + '.bin')).read_bytes()


def check(reference, status, native=None, native_status=None):
    complete(reference, status, 'COMPLETE original occupied effect replacement', 'Exited via the debugger')
    code = next(r.body for r in read_resource_fork(ROOT / 'tmp/runtime-data/Alone In The Dark')
                if r.kind == b'CODE' and r.rid == 3)
    raw = code[0x17ea:0x1800]
    if raw.hex() != '0064f8c467102f2e000848780011206df9544e90508f' or one(reference, r'^DRIVER17_BYTES (\w+)$') != raw.hex().upper():
        raise ValueError('original caller')
    driver = blob('reference-driver')
    original = (ROOT / 'tmp/plan/MDRV_11.bin').read_bytes()
    for a, b in ((0, 12), (0x78, 0x7c), (0x1b6, 0x1c2), (0x1fe0, 0x1fec), (0x3506, 0x3606)):
        if driver[a:b] != original[a:b]:
            raise ValueError('original implementation bytes')
    e, r = [fields(one(reference, r'^DRIVER17_' + p + r' (.*)$')) for p in ('ENTER', 'RETURN')]
    age = fields(one(reference, r'^EFFECT_AGE (.*)$'))
    if age['clock'] - age['started'] != age['elapsed'] or age['age'] != 0x7ffe - age['elapsed']:
        raise ValueError('callback age')
    config = fields(one(reference, r'^EFFECT_REPLACE (.*)$'))
    if (config['first'], config['count'], config['age0']) != (6, 1, age['age']):
        raise ValueError('sole occupied slot')
    if e['selector'] != 17 or e['sp'] != r['sp'] or r['d0'] or r['d1'] != (e['ignored'] & 0xffff0000) | age['age']:
        raise ValueError('reference result/stack')
    for reg in [f'd{i}' for i in range(2, 8)] + [f'a{i}' for i in range(7)]:
        if e[reg] != r[reg]:
            raise ValueError('reference preserved ' + reg)
    packet = blob('reference-packet')
    sample, size, rate, start, end, counter, ident = struct.unpack('>6IH', packet)
    if (size, rate, start, end, ident) != (31020, 8000 << 16, 0, 0, 0x8000):
        raise ValueError('actual request')
    if one(reference, r'^DRIVER17_PACKET (\w+)$') != packet.hex().upper():
        raise ValueError('packet evidence')
    before, after = [blob('reference-' + p + '-state') for p in ('enter', 'return')]
    if len(before) != 0x3048 or len(after) != len(before):
        raise ValueError('state extent')
    expected = bytearray(before)
    struct.pack_into('>IIH', expected, 0, 17, e['ignored'], 0)
    voice = 0x22d2 + 6 * 4
    longs = {0: sample, 0x40: ((rate >> 5) // 11127) << 5, 0x80: 0, 0x240: 0,
             0x280: sample + size, 0x2c0: 0, 0x300: 0,
             0x340: (e['entry'] | 0x80000000) + 0x4200 + 0x2ca6,
             0x3c0: 0, 0x540: counter, 0x640: 0x00800080}
    for offset, value in longs.items():
        struct.pack_into('>I', expected, voice + offset, value)
    for offset, value in {0x200: 0x7ffe, 0x440: ident, 0x500: 0x7fff, 0x580: struct.unpack_from('>H', before, 0x30)[0] & 1}.items():
        struct.pack_into('>H', expected, voice + offset, value)
    if after != expected:
        raise ValueError('complete original transition/music isolation')
    pcm = blob('reference-sample')
    if len(pcm) != size:
        raise ValueError('sample extent')
    if native is not None:
        text = native.read_text()
        complete(text, native_status, 'PASS native occupied effect replacement', '[Inferior 1 (Remote target) detached]')
        values = []
        for phase in ('ENTER', 'RETURN'):
            row = one(text, r'^EFFECT_NATIVE_' + phase + r' (.*)$')
            values.append(dict(re.findall(r'(\w+)=([^ ]+)', row)))
        ne, nr = values
        dec = lambda row, key: int(row[key], 10)
        hx = lambda row, key: int(row[key], 16)
        if hx(nr, 'sp') != hx(ne, 'sp') or hx(nr, 'd0') or hx(nr, 'd1') >> 16 != hx(ne, 'packet') >> 16:
            raise ValueError('native result/stack')
        low, high = (0x7ffe - (dec(row, 'ticks') - dec(ne, 'started')) for row in (nr, ne))
        if not low <= (hx(nr, 'd1') & 0xffff) <= high:
            raise ValueError('native callback age')
        if dec(nr, 'starts') != dec(ne, 'starts') + 1 or dec(nr, 'stops') != dec(ne, 'stops') + 1:
            raise ValueError('replacement lifetime')
        if nr['channel'] != ne['channel'] or nr['active'] != '1' or hx(nr, 'id') != ident or not hx(nr, 'chip') or nr['chip'] == ne['chip']:
            raise ValueError('native sample/channel ownership')
        p = blob('native-packet')
        if p[4:20] != packet[4:20] or p[24:] != packet[24:] or blob('native-sample') != pcm:
            raise ValueError('paired request/sample')
        if blob('native-chip') != bytes(b ^ 0x80 for b in pcm) + bytes(2):
            raise ValueError('converted sample and silent reload')
        if blob('native-songs-before') != blob('native-songs-after'):
            raise ValueError('native music isolation')
    print('PASS occupied effect: sole-slot replacement, callback age, full original state/ABI, sample conversion and music isolation')


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('reference', type=Path)
    p.add_argument('--status', type=int, required=True)
    p.add_argument('--native', type=Path)
    p.add_argument('--native-status', type=int)
    a = p.parse_args()
    try:
        check(a.reference.read_text(), a.status, a.native, a.native_status)
    except (ValueError, OSError, KeyError, struct.error) as e:
        raise SystemExit('FAIL occupied effect: ' + str(e))
