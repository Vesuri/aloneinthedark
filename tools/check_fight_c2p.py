#!/usr/bin/env python3
"""Independent coordinate/coverage check for fight_c2p.gdb (not a timing run)."""
import argparse
import re
from pathlib import Path


def check(text):
    rows = []
    for line in text.splitlines():
        m = re.fullmatch(r'BOUNDS scene=(\d+) crop=(\d+),(\d+) dirty=(\d+) converted=(\d+)', line)
        if m:
            scene, top, left, nd, nc = map(int, m.groups())
            rows.append(dict(scene=scene, top=top, left=left, nd=nd, nc=nc, dirty=[], converted=[]))
        elif line.startswith(('DIRTY ', 'CONVERTED ')):
            kind, *values = line.split()
            rows[-1][kind.lower()].append(tuple(map(int, values)))
    assert 'FAIL' not in text and re.search(r'PASS fight C2P bounds frames=40 verified=\d+ partial=\d+ failures=0', text)
    assert len(rows) == 40
    assert all(b['scene'] > a['scene'] for a, b in zip(rows, rows[1:])), 'repeated/reordered frames'
    areas = []
    multi = 0
    for row in rows:
        dirty, converted = row['dirty'], row['converted']
        assert len(dirty) == row['nd'] and len(converted) == row['nc']
        multi += len(dirty) > 1
        for t, l, b, r in converted:
            assert 0 <= t < b <= 200 and 0 <= l < r <= 320
            assert l % 16 == 0 and (r-l) % 32 == 0
        area = 0
        for y in range(200):
            # Mark word columns touched by actual clipped draw coordinates.
            required = [False] * 20
            for t, l, b, r in dirty:
                if t <= y + row['top'] < b:
                    lo, hi = max(0, l-row['left']), min(320, r-row['left'])
                    for x in range(lo, hi):
                        required[x//16] = True
            coverage = [0] * 20
            for t, l, b, r in converted:
                if t <= y < b:
                    for x in range(l//16, r//16):
                        coverage[x] += 1
            assert max(coverage) <= 1, ('overlap', row['scene'], y)
            assert all(not need or coverage[x] for x, need in enumerate(required))
            # Exhaust the legal interval lengths, independently of the sweep.
            best = [100] * 21
            best[20] = 0
            for x in range(19, -1, -1):
                if not required[x]:
                    best[x] = best[x+1]
                for end in range(x+2, 21, 2):
                    best[x] = min(best[x], end-x+best[end])
            assert sum(coverage) == best[0], ('nonminimal', row['scene'], y)
            area += sum(coverage)*16
        areas.append(area)
    assert multi > 0, 'did not exercise combined actor rectangles'
    return areas, multi


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('log', type=Path)
    p.add_argument('--status', required=True, type=int)
    a = p.parse_args()
    assert a.status == 0, f'runner status {a.status}'
    areas, multi = check(a.log.read_text())
    print(f'PASS fight C2P: 40 complete frames, {multi} multi-rectangle inputs; '
          f'no overlap, minimum aligned row coverage; pixels min/mean/max='
          f'{min(areas)}/{sum(areas)/len(areas):.1f}/{max(areas)}')
