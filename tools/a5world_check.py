#!/usr/bin/env python3
"""Model CODE 1+$0118's below-A5 globals; compare an exact pre-main dump.

Dump [A5-75616, A5), before the first instruction of Core+$03E4. Supply the
actual A5 and STRS data addresses. Above-A5 jump entries and port shadows are
outside this initializer's range and require separate loader checks.
"""
import argparse
import hashlib
from pathlib import Path
import struct
import unittest
from resource_fork import parse_resource_fork

BELOW = 75616
INITIALIZER_SHA = 'a0eea67b5a5822fc521ccbcbb158356eaa8b36976f16fe831039a4940290154a'
GLOBALS_SHA = 'a7556b1297fbee4e62e31a4df1e089308ee1cf22361bf9d6528c937ad40990f4'
RELOCATED_SHA = 'bd3ecf2ccce98f2c707f7dca0b7f58f43a310266a39e2454e07bbac513bb2f1a'


def expand(data, zero, below):
    """MOVE.W, then DBRA clears exactly ZERO's count (including count zero)."""
    result = bytearray(below)
    pos = di = zi = runs = 0
    while pos < below:
        if di + 2 > len(data) or pos + 2 > below:
            raise ValueError('DATA exhausted or word overruns globals')
        word = data[di:di + 2]
        result[pos:pos + 2] = word
        di += 2
        pos += 2
        if word == b'\0\0':
            if zi + 2 > len(zero):
                raise ValueError('ZERO exhausted')
            count = int.from_bytes(zero[zi:zi + 2], 'big')
            zi += 2
            runs += 1
            pos += count
            if pos > below:
                raise ValueError('ZERO run overruns globals')
    if di != len(data) or zi != len(zero):
        raise ValueError('DATA/ZERO has unconsumed bytes')
    return result, runs


def offsets(drel, below):
    """EXT.L of a negative word, otherwise SWAP/MOVE.W/NEG.L; bit 0 tags STRS."""
    result = []
    pos = longs = 0
    while pos < len(drel):
        if pos + 2 > len(drel):
            raise ValueError('DREL truncated word')
        value = struct.unpack_from('>h', drel, pos)[0]
        pos += 2
        if value >= 0:
            if pos + 2 > len(drel):
                raise ValueError('DREL truncated long form')
            value = -((value << 16) | int.from_bytes(drel[pos:pos + 2], 'big'))
            pos += 2
            longs += 1
        target = below + (value & ~1)
        if not 0 <= target <= below - 4:
            raise ValueError(f'DREL target outside globals: A5{value & ~1:+d}')
        result.append(value)
    return result, longs


def relocate(globals_, relocations, a5, strs):
    result = bytearray(globals_)
    for offset in relocations:
        target = len(result) + (offset & ~1)
        value = struct.unpack_from('>I', result, target)[0]
        base = strs if offset & 1 else a5
        struct.pack_into('>I', result, target, (value + base) & 0xffffffff)
    return result


def load(path):
    resources = {(r.kind, r.rid): r.body for r in parse_resource_fork(path.read_bytes())}
    required = [(kind, 0) for kind in (b'CODE', b'DATA', b'ZERO', b'DREL', b'STRS')] + [(b'CODE', 1)]
    if any(key not in resources for key in required):
        raise ValueError('missing startup resource')
    code0 = resources[b'CODE', 0]
    if len(code0) != 3760 or code0[:16].hex() != '00000ec00001276000000ea000000020':
        raise ValueError('unsupported CODE 0 layout')
    if hashlib.sha256(resources[b'CODE', 1][0x118:0x194]).hexdigest() != INITIALIZER_SHA:
        raise ValueError('CODE 1 initializer byte mismatch')
    globals_, runs = expand(resources[b'DATA', 0], resources[b'ZERO', 0], BELOW)
    relocations, longs = offsets(resources[b'DREL', 0], BELOW)
    counts = (len(resources[b'DATA', 0]), len(resources[b'ZERO', 0]), runs,
              len(relocations), sum(o & 1 for o in relocations), longs)
    if counts != (11418, 560, 280, 276, 21, 63):
        raise ValueError(f'original-data census mismatch: {counts}')
    # Golden digests independently obtained from the planning model, after
    # checking the original instruction sequence. They are not runtime proof.
    if hashlib.sha256(globals_).hexdigest() != GLOBALS_SHA:
        raise ValueError('expanded globals differ from the 1.0 baseline')
    if hashlib.sha256(relocate(globals_, relocations, 0x100000, 0x200000)).hexdigest() != RELOCATED_SHA:
        raise ValueError('relocated globals differ from the planning baseline')
    return globals_, relocations


def differences(expected, actual):
    if len(actual) != len(expected):
        raise ValueError(f'dump length {len(actual)}, expected {len(expected)}')
    return [i for i, pair in enumerate(zip(expected, actual)) if pair[0] != pair[1]]


class ModelTests(unittest.TestCase):
    def test_expansion(self):
        result, runs = expand(bytes.fromhex('1234000056780000abcd'), bytes.fromhex('00040000'), 14)
        self.assertEqual(result.hex(), '123400000000000056780000abcd')
        self.assertEqual(runs, 2)

    def test_relocation(self):
        # Short A5 offset -8; long-form STRS tag -3 -> aligned offset -4.
        rel, longs = offsets(bytes.fromhex('fff800000003'), 8)
        self.assertEqual((rel, longs), ([-8, -3], 1))
        self.assertEqual(relocate(bytes.fromhex('fffffff000000005'), rel, 0x20, 0x1234).hex(),
                         '0000001000001239')

    def test_long_offset(self):
        self.assertEqual(offsets(bytes.fromhex('00012760'), BELOW), ([-BELOW], 1))

    def test_bad_streams(self):
        for data, zero, size in [(b'', b'', 2), (b'\0\0', b'', 2),
                                 (b'\0\0', b'\0\4', 4), (b'abcd', b'', 2),
                                 (b'ab', b'\0\0', 2)]:
            with self.subTest(data=data, zero=zero, size=size), self.assertRaises(ValueError):
                expand(data, zero, size)
        for raw in ('ff', '0000', '00000000', 'fff0', 'ffff'):
            with self.subTest(raw=raw), self.assertRaises(ValueError):
                offsets(bytes.fromhex(raw), 8)

    def test_comparison(self):
        self.assertEqual(differences(b'abc', b'abc'), [])
        self.assertEqual(differences(b'abc', b'axc'), [1])
        with self.assertRaises(ValueError):
            differences(b'abc', b'ab')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('resource', nargs='?', type=Path)
    parser.add_argument('--selftest', action='store_true')
    parser.add_argument('--a5', type=lambda n: int(n, 0))
    parser.add_argument('--strs', type=lambda n: int(n, 0))
    parser.add_argument('--dump', type=Path)
    parser.add_argument('--write', type=Path)
    args = parser.parse_args()
    if args.selftest:
        suite = unittest.defaultTestLoader.loadTestsFromTestCase(ModelTests)
        return int(not unittest.TextTestRunner().run(suite).wasSuccessful())
    if args.resource is None:
        parser.error('resource fork is required')
    if (args.dump or args.write) and (args.a5 is None or args.strs is None):
        parser.error('--dump/--write require actual --a5 and --strs addresses')
    for base in (args.a5, args.strs):
        if base is not None and not 0 <= base <= 0xffffffff:
            parser.error('base must fit an unsigned 32-bit address')
    try:
        globals_, rel = load(args.resource)
        print('PASS a5world-resource-check: bytes=75616 DATA=11418 ZERO=560 runs=280 DREL=276 A5=255 STRS=21 long=63')
        if args.dump or args.write:
            expected = relocate(globals_, rel, args.a5, args.strs)
            if args.write:
                args.write.write_bytes(expected)
            if args.dump:
                actual = args.dump.read_bytes()
                changed = differences(expected, actual)
                for index in changed[:20]:
                    print(f'A5{index-BELOW:+d}: expected={expected[index]:02x} actual={actual[index]:02x}')
                print(f'{"FAIL" if changed else "PASS"} a5world-dump: mismatches={len(changed)}/{BELOW}')
                return int(bool(changed))
    except (OSError, ValueError, struct.error) as exc:
        print(f'A5 WORLD / {exc}')
        return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
