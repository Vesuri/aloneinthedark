#!/usr/bin/env python3
"""Verify controlled Engine randomness; no wall-clock/frame-count pairing."""
import argparse
import re
from pathlib import Path

ROW = re.compile(r'^FIXED_RANDOM row=(\d+) seed=([0-9A-F]+) mixed=([0-9A-F]+) result=([0-9A-F]+) next=([0-9A-F]+) segment=(\d+) offset=([0-9A-F]+)$', re.M)


def capture(path, status, side):
    text = path.read_text()
    marker = 'COMPLETE ' + side + ' fixed random'
    terminal = 'Exited via the debugger' if side == 'original' else '[Inferior 1 (Remote target) detached]'
    if status != 0 or text.count(marker) != 1 or text.count(terminal) != 1 or re.search(r'FAIL|LUA ERROR|Error in|TIMEOUT|Timed out|Program received signal', text):
        raise ValueError(side + ' incomplete run')
    rows = [tuple(int(value, 10 if i in (0, 5) else 16) for i, value in enumerate(row)) for row in ROW.findall(text)]
    if len(rows) != 64 or [r[0] for r in rows] != list(range(64)):
        raise ValueError(side + ' row count/order')
    seed, mixed = 1, 1
    for n, before, accumulator, result, after, segment, offset in rows:
        if (before, accumulator) != (seed, mixed):
            raise ValueError(f'{side} input chain at {n}')
        # Independent arithmetic oracle: Park-Miller step for this positive seed.
        seed = seed * 16807 % 2147483647
        expected = seed & 65535
        if expected == 32768:
            expected = 0
        if (after, result) != (seed, expected):
            raise ValueError(f'{side} Random result at {n}')
        mixed = (mixed ^ result) & 32767
        if segment not in (4, 5, 13):
            raise ValueError(f'{side} unattributed caller at {n}')
    if rows[0][5:] != (4, 0x5250):
        raise ValueError(side + ' initial character selection caller')
    end = re.findall(r'^FIXED_RANDOM_END calls=(\d+) choice=(\d+) mixed=([0-9A-F]+) ticks=(\d+)', text, re.M)
    if len(end) != 1 or tuple(int(v, 16 if i == 2 else 10) for i, v in enumerate(end[0][:3])) != (64, 0, mixed):
        raise ValueError(side + ' original final accumulator/character')
    return rows


def run(reference, reference_status, native, native_status):
    raw = (Path(__file__).resolve().parents[1] / 'tmp/segments/CODE_7_Engine').read_bytes()
    if raw[0x4a22:0x4a44].hex() != '3038016c024001ffd179ffffef884267a861301fb179ffffef8802797fffffffef88':
        raise ValueError('original random-wrapper bytes')
    a = capture(reference, reference_status, 'original')
    b = capture(native, native_status, 'native')
    if a != b:
        first = next(i for i in range(64) if a[i] != b[i])
        raise ValueError(f'paired stream/caller differs at row {first}: {a[first]} != {b[first]}')
    print('PASS 64 paired Engine random inputs/results/callers; zero clock contribution; character 0')
    print('Sequence/frame comparisons still require original scene and script state keys.')


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--reference', type=Path, required=True)
    p.add_argument('--reference-status', type=int, required=True)
    p.add_argument('--native', type=Path, required=True)
    p.add_argument('--native-status', type=int, required=True)
    args = p.parse_args()
    try:
        run(args.reference, args.reference_status, args.native, args.native_status)
    except (ValueError, OSError) as error:
        raise SystemExit('FAIL ' + str(error))
