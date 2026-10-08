#!/usr/bin/env python3
"""Validate a natural QuickDraw solid point's full pixel buffer and pen state.

Pass entry and return filename prefixes (before ``-port.bin``, etc.).
Captures must include the port, PixMap, rectangular vis/clip regions and pixels.
"""
import argparse
import struct
from pathlib import Path


def check(entry, returned):
    def read(prefix, name):
        return Path(str(prefix) + '-' + name + '.bin').read_bytes()
    def word(data, offset):
        return struct.unpack_from('>h', data, offset)[0]
    port, pm = read(entry, 'port'), read(entry, 'pm')
    before, after = read(entry, 'pixels'), read(returned, 'pixels')
    assert port == read(returned, 'port'), 'point changed port state'
    assert pm == read(returned, 'pm'), 'point changed PixMap'
    assert len(port) == 108 and len(pm) == 50
    assert word(port, 56) == 8 and word(port, 66) == 0, 'solid visible patCopy'
    assert word(pm, 32) == 8, 'indexed pixels'
    color = int.from_bytes(port[80:84], 'big')
    assert color <= 255
    stride = int.from_bytes(pm[4:6], 'big') & 0x3fff
    mt, ml, mb, mr = struct.unpack_from('>4h', pm, 6)
    y, x, height, width = struct.unpack_from('>4h', port, 48)
    assert width > 0 and height > 0
    assert len(before) == len(after) == stride * (mb-mt)
    bounds = [(mt, ml, mb, mr), struct.unpack_from('>4h', port, 16)]
    for name in ('region24', 'region28'):
        region = read(entry, name)
        assert region == read(returned, name) and len(region) == 10
        assert int.from_bytes(region[:2], 'big') == 10
        bounds.append(struct.unpack_from('>4h', region, 2))
    top, left, bottom, right = y, x, y+height, x+width
    for t, l, b, r in bounds:
        top, left, bottom, right = max(top,t), max(left,l), min(bottom,b), min(right,r)
    expected = bytearray(before)
    for row in range(top, bottom):
        for col in range(left, right):
            expected[(row-mt)*stride+col-ml] = color
    assert expected == after, 'full-buffer mismatch or writes outside clipped pen rectangle'
    changed = sum(a != b for a, b in zip(before, after))
    assert changed, 'capture must exercise a visible write'
    print(f'PASS solid point {width}x{height}: {len(after)} bytes, {changed} changed, port and regions preserved')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('entry', type=Path)
    parser.add_argument('returned', type=Path)
    args = parser.parse_args()
    check(args.entry, args.returned)
