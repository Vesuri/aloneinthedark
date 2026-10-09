#!/usr/bin/env python3
"""Check original frame boundaries and a lightweight FRAMEAUDIT WHDLoad core."""
import argparse
from pathlib import Path
import re
import struct


def require(ok, message):
    if not ok:
        raise ValueError(message)


def aligned(box):
    top, left, bottom, right = box
    left &= ~15
    right = left + ((right-left+31) & ~31)
    if right > 320:
        left -= right-320
        right = 320
    return top, left, bottom, right


def check_log(path):
    text = path.read_text()
    require('FAIL' not in text and 'PASS frame boundaries: logo=106 book=840' in text,
            'positive uninterrupted boundary completion')
    require('[Inferior 1 (Remote target) detached]' in text, 'normal debugger completion')
    logos = re.findall(r'^PACE_LOGO n=(\d+) fields=(\d+) waits=(\d+) publications=(\d+)$', text, re.M)
    require([int(r[0]) for r in logos] == list(range(1, 107)), '106 original logo steps')
    require(all(r[2:] == ('1', '1') for r in logos), 'one wait/publication per logo step')
    books = re.findall(r'^PACE_BOOK n=(\d+) mode=(\d+) column=(\d+) fields=(\d+) dirty=([\d,-]+) c2p=([\d,-]+)$', text, re.M)
    require([int(r[0]) for r in books] == list(range(1, 841)), '840 original book steps')
    areas = []
    for _, _, _, _, raw, converted in books:
        dirty, c2p = (tuple(map(int, item.split(','))) for item in (raw, converted))
        require(c2p == aligned(dirty), 'conversion is exactly coordinate bounds plus alignment')
        top, left, bottom, right = c2p
        require(0 <= top < bottom <= 200 and 0 <= left < right <= 320, 'viewport bounds')
        areas.append((bottom-top)*(right-left))
    print(f'PASS boundaries: 106 logo and 840 book steps; C2P pixels min/mean/max '
          f'{min(areas)}/{sum(areas)/len(areas):.1f}/{max(areas)}')


def check_core(path, require_field_rate=False):
    data = path.read_bytes()
    reports = []
    for match in re.finditer(b'AITDFRAM', data):
        offset = match.start()
        count, pal = struct.unpack_from('>2I', data, offset+8)
        if 840 <= count <= 1024 and pal in (0, 1):
            reports.append((offset, count, pal))
    require(len(reports) == 1, 'one complete frame-audit report')
    offset, count, pal = reports[0]
    rows = [struct.unpack_from('>14H', data, offset+16+n*28) for n in range(count)]
    logos = rows[1:107]
    require(len(logos) == 106 and all(r[1] == 0 for r in logos), '106 opening logo publications')
    logo_deltas = [(cur[0]-prev[0]) & 65535 for prev,cur in zip(logos,logos[1:])]
    require(min(logo_deltas) >= 1, 'no two logo publications in the same field')
    hz = 50 if pal else 60
    if require_field_rate:
        require(max(logo_deltas) == 1, 'logo reaches one displayed frame per field')
    print(f'LOGO: fields min/mean/max {min(logo_deltas)}/{sum(logo_deltas)/len(logo_deltas):.3f}/{max(logo_deltas)}; '
          f'{hz*len(logo_deltas)/sum(logo_deltas):.2f} publications/s')
    books = []
    for row in rows:
        if row[1] and (not books or row[1] != books[-1][1]):
            books.append(row)
    require([r[1] for r in books] == list(range(1, 841)), 'all book steps in core')
    for r in books:
        require(r[12] == 1 and tuple(r[8:12]) == aligned(tuple(r[4:8])), 'single coordinate-bounded conversion')
        require(r[13]*32 == (r[10]-r[8])*(r[11]-r[9]), 'actual C2P area')
    # Each authored fold restarts with the same first dirty bounds. Exclude
    # the original page-reading holds between folds from animation cadence.
    first = books[0][4:8]
    deltas = [(cur[0]-prev[0]) & 65535 for prev, cur in zip(books, books[1:]) if cur[4:8] != first]
    require(deltas and min(deltas) >= 1, 'no two book publications in the same field')
    hz = 50 if pal else 60
    if require_field_rate:
        require(max(deltas) == 1, 'book reaches one displayed frame per field')
    holds = [(cur[0]-prev[0]) & 65535 for prev,cur in zip(books,books[1:]) if cur[4:8] == first]
    print(f'PAGE TRANSITIONS: {len(holds)} gaps, {sum(holds)/hz:.2f}s total; whole book turns/holds {(books[-1][0]-books[0][0])%65536/hz:.2f}s')
    print(f'PASS core: {len(books)} book steps; {len(deltas)} within-fold intervals; '
          f'fields min/mean/max {min(deltas)}/{sum(deltas)/len(deltas):.3f}/{max(deltas)}; '
          f'{hz*len(deltas)/sum(deltas):.2f} publications/s')


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--log', type=Path)
    p.add_argument('--core', type=Path)
    p.add_argument('--require-field-rate', action='store_true', help='require one displayed frame per field on the unlimited-speed test machine')
    a = p.parse_args()
    if not a.log and not a.core:
        p.error('provide --log and/or --core')
    try:
        if a.log:
            check_log(a.log)
        if a.core:
            check_core(a.core, a.require_field_rate)
    except (OSError, ValueError, struct.error) as error:
        raise SystemExit(f'FAIL frame pacing: {error}')


if __name__ == '__main__':
    main()
