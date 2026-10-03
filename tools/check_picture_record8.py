#!/usr/bin/env python3
"""Pair the save recorder with mac_picture_record.lua's original Mac capture."""
import argparse
import os
from pathlib import Path
import struct
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def raster(path):
    data = path.read_bytes()
    assert data[10:16] == bytes.fromhex('001102ff0c00')
    assert data[52:54] == bytes.fromhex('0098')
    pos = 54
    stride = int.from_bytes(data[pos:pos+2], 'big') & 0x3fff
    top, left, bottom, right = struct.unpack_from('>4h', data, pos+2)
    pos += 46
    count = int.from_bytes(data[pos+6:pos+8], 'big')+1
    colors = data[pos+8:pos+8+count*8]
    pos += 8+count*8
    source = struct.unpack_from('>4h', data, pos)
    destination = struct.unpack_from('>4h', data, pos+8)
    mode = int.from_bytes(data[pos+16:pos+18], 'big')
    pos += 18
    rows = []
    for _ in range(bottom-top):
        prefix = 2 if stride > 250 else 1
        packed = int.from_bytes(data[pos:pos+prefix], 'big')
        pos += prefix
        end = pos+packed
        row = bytearray()
        while pos < end:
            code = data[pos]
            pos += 1
            if code < 128:
                row += data[pos:pos+code+1]
                pos += code+1
            elif code > 128:
                row += bytes([data[pos]])*(257-code)
                pos += 1
        assert pos == end and len(row) == stride
        rows.append(row)
    pos += pos & 1
    assert data[pos:pos+2] == bytes.fromhex('00ff') and pos+2 == len(data)
    return rows, (top, left, bottom, right), source, destination, mode, colors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--reference-dir', type=Path, required=True)
    args = parser.parse_args()
    prefix = args.reference_dir / 'pictrecord-reference-'
    with tempfile.TemporaryDirectory(prefix='aitd-picture8-') as folder:
        exe, picture = Path(folder)/'test', Path(folder)/'picture.bin'
        subprocess.run([os.environ.get('HOST_CXX', 'c++'), '-std=c++17', '-Wall', '-Wextra',
                        '-Werror', '-fsanitize=address,undefined',
                        str(ROOT/'tools/test_picture_record8.cpp'), '-o', str(exe)], check=True)
        subprocess.run([str(exe), str(args.reference_dir), str(picture)], check=True)
        original = raster(Path(str(prefix)+'picture.bin'))
        native = raster(picture)
        assert original[2:] == native[2:]
        top, left, bottom, right = original[2]
        for y in range(top, bottom):
            old = original[0][y-original[1][0]][left-original[1][1]:right-original[1][1]]
            new = native[0][y-native[1][0]][left-native[1][1]:right-native[1][1]]
            assert old == new, f'source row {y}'
        assert Path(str(prefix)+'enter-src-pixels.bin').read_bytes() == Path(str(prefix)+'return-src-pixels.bin').read_bytes()
    print('PASS PictureRecord8: original pixels, colours, rectangles, mode and suppressed visible copy')


if __name__ == '__main__':
    main()
