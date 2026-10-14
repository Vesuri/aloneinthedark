#!/usr/bin/env python3
"""Check every byte of real-game pen-state fast-path captures."""
import argparse
import re
import struct
from pathlib import Path

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('log', type=Path)
p.add_argument('folder', type=Path)
p.add_argument('--status', type=int, required=True)
a = p.parse_args()
t = a.log.read_text()
assert a.status == 0 and t.count('PASS quick pen ABI') == 1
assert t.count('[Inferior 1 (Remote target) detached]') == 1
assert not re.search(r'FAIL|Error in|Program received signal|timeout', t)
counts = {0xa893: 0, 0xa89b: 0, 0xa89c: 0}
rows = re.findall(r'^QUICK_PEN n=(\d+) trap=([0-9A-F]+) first=(\d+) second=(\d+)$', t, re.M)
for index, (n, trap, first, second) in enumerate(rows, 1):
    assert int(n) == index
    trap, first, second = int(trap, 16), int(first), int(second)
    before = (a.folder / (n + '-before.bin')).read_bytes()
    after = (a.folder / (n + '-after.bin')).read_bytes()
    assert len(before) == len(after) == 108
    expected = bytearray(before)
    if trap == 0xa89c:
        struct.pack_into('>H', expected, 56, first)
    else:
        struct.pack_into('>HH', expected, 48 if trap == 0xa893 else 52, first, second)
        if trap == 0xa893 and struct.unpack_from('>H', before, 6)[0] & 0xc000:
            struct.pack_into('>H', expected, 14, 0x8000)
    assert after == expected, 'port mismatch at call ' + n
    counts[trap] += 1
assert min(counts.values()) >= 8
print('PASS quick pen state: %u full port comparisons, registers, CCR and Pascal stack' % len(rows))
