#!/usr/bin/env python3
"""Verify original-game PBRead payloads against the installed PAK files."""
import argparse
import hashlib
from pathlib import Path
import re
import struct
from resource_fork import read_resource_fork

ROOT = Path(__file__).resolve().parents[1]

def check(text, status, folder=ROOT/'tmp'):
    if status != 0 or re.search(r'FAIL|Error in|TIMEOUT|Program received signal', text):
        raise ValueError('observer did not finish normally')
    complete = re.findall(r'^PASS original native PAK reads calls=(\d+) itd_payloads=(\d+) present_payloads=(\d+) windows=(\d+) resources=(\d+) services=(\d+)/(\d+)$', text, re.M)
    if len(complete) != 1 or text.count('[Inferior 1 (Remote target) detached]') != 1:
        raise ValueError('missing or duplicate positive completion')
    random = re.findall(r'^PAK_RANDOM calls=(\d+) seed=([0-9A-F]+)$', text, re.M)
    if len(random) != 1 or int(random[0][0]) == 0:
        raise ValueError('deterministic original random-call coverage')
    calls, itd, present, windows, resources, entered, completed = map(int, complete[0])
    if not all((itd, present, windows, resources)) or entered != completed:
        raise ValueError('payload or service/window completion')
    rows = re.findall(r'^PAK_READ n=(\d+) name=([^\n]+?) segment=(\d+) offset=([0-9A-F]+) position=(\d+) requested=(\d+) actual=(\d+) windows=(\d+)$', text, re.M)
    if len(rows) != calls or [int(r[0]) for r in rows] != list(range(calls)):
        raise ValueError('incomplete or unordered read records')
    code = {r.rid: r.body for r in read_resource_fork(ROOT/'tmp/runtime-data/Alone In The Dark') if r.kind == b'CODE'}
    files = {p.name.lower(): p for p in (ROOT/'tmp/runtime-data/Alone Data').iterdir() if p.is_file() and not p.name.endswith(('.finfo', '.rsrc'))}
    totals, payloads = {}, {}
    previous_windows = 0
    for n, name, segment, offset, position, requested, actual, at_windows in rows:
        n, segment, offset = int(n), int(segment), int(offset, 16)
        position, requested, actual, at_windows = map(int, (position, requested, actual, at_windows))
        if code.get(segment, b'')[offset:offset+2] != bytes.fromhex('a002'):
            raise ValueError('caller is not an original PBRead instruction')
        if not previous_windows <= at_windows <= windows:
            raise ValueError('nonmonotonic system-window count')
        previous_windows = at_windows
        if name.lower() not in files or not 0 <= actual <= requested <= 1048576:
            raise ValueError('unknown file or invalid extent')
        before = (folder/f'pak-native-{n}-enter-pb.bin').read_bytes()
        after = (folder/f'pak-native-{n}-return-pb.bin').read_bytes()
        if len(before) != 80 or len(after) != 80:
            raise ValueError('parameter block extent')
        word = lambda b, p: struct.unpack_from('>H', b, p)[0]
        long = lambda b, p: struct.unpack_from('>I', b, p)[0]
        if word(after, 16) not in (0, 0xffd9) or word(before, 24) != word(after, 24) or not word(after, 24):
            raise ValueError('read status or open-fork identity')
        if long(before, 32) != long(after, 32) or not long(after, 32) or long(before, 36) != requested or long(after, 36) != requested or long(after, 40) != actual or long(after, 46) != position+actual:
            raise ValueError('destination, request, actual count or final mark')
        source = files[name.lower()].read_bytes()
        if actual != min(requested, max(0, len(source)-position)) or word(after, 16) != (0xffd9 if actual < requested else 0):
            raise ValueError('incorrect full/EOF read count or result')
        data = (folder/f'pak-native-{n}-bytes.bin').read_bytes() if actual else b''
        if len(data) != actual or data != source[position:position+actual]:
            raise ValueError(f'{name} read {n}: returned payload differs from installed bytes')
        totals[name.lower()] = totals.get(name.lower(), 0) + actual
        if actual >= 1024:
            payloads[name.lower()] = payloads.get(name.lower(), 0) + 1
        print(f'PAK verified {name} offset={position} bytes={actual} sha256={hashlib.sha256(data).hexdigest()}')
    if payloads.get('itd_ress.pak', 0) != itd or payloads.get('present.pak', 0) != present:
        raise ValueError('both original PAK payloads required')
    print(f'PASS original native PAK payloads: reads={calls} bytes={totals} windows={windows} resource_reads={resources} services={completed}')

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('log', type=Path)
    parser.add_argument('--status', type=int, required=True)
    args = parser.parse_args()
    try:
        check(args.log.read_text(), args.status)
    except (OSError, ValueError, KeyError, struct.error) as error:
        raise SystemExit('FAIL original native PAK payloads: '+str(error))
