#!/usr/bin/env python3
"""Check natural corridor model-render captures and compare identical inputs.

Observers read original Dark+$3ED4 through +$3EDA and Dark3 drawing stages.
They do not replay inputs. Model matches exclude the runtime header at 16:26;
surrounding actors, cache state and interrupt phase are not claimed identical.
"""
import argparse
from collections import defaultdict
import hashlib
from pathlib import Path
import re
import statistics
import struct

STAGES = ('draw', 'model-setup', 'vertices-done', 'surfaces-prepared',
          'sort-done', 'draw-list-done', 'draw-return')
SPANS = (('draw', 'draw-return'), ('model-setup', 'sort-done'),
         ('sort-done', 'draw-list-done'))


def require(ok, reason):
    if not ok:
        raise ValueError(reason)


def load(log_path, folder, status):
    log = log_path.read_text()
    require(status == 0 and not re.search(r'FAIL|Error in|TIMEOUT', log),
            'observer completion')
    original = log.count('PASS original natural corridor phases')
    native = log.count('PASS native natural corridor phases')
    require(original + native == 1, 'unique corridor completion')
    require(('Exited via the debugger' if original else
             '[Inferior 1 (Remote target) detached]') in log, 'natural detach')
    rows = re.findall(r'^CORRIDOR_PHASE sample=(\d+) phase=(\S+) ticks=(\d+) '
                      r'room=(\d+) camera=(\d+)$', log, re.M)
    samples, active = {}, None
    for number, phase, tick, room, camera in rows:
        number, tick, room, camera = map(int, (number, tick, room, camera))
        if phase == 'draw':
            require(active is None, 'nested or incomplete model call')
            if (room, camera) != (1, 2):
                continue
            require(number not in samples, 'duplicate model call')
            active = number
            samples[number] = []
        if active is not None:
            require(number == active and (room, camera) == (1, 2),
                    'model call changed identity or view')
            samples[active].append((phase, tick))
            if phase == 'draw-return':
                active = None
        # Other actors can reach the shared Dark3 checkpoints after this
        # person's return. Those rows are outside the measured call.
    require(active is None and len(samples) >= 5, 'complete corridor sample')
    records = []
    for number, phases in samples.items():
        require(tuple(p for p, t in phases) == STAGES, 'stage order')
        require(all(a[1] <= b[1] for a, b in zip(phases, phases[1:])),
                'monotonic game clock')
        def read(suffix, size):
            data = (folder / f'{number:03d}-{suffix}.bin').read_bytes()
            require(len(data) == size, 'capture extent: ' + suffix)
            return data
        body = read('body', 3438)
        args = read('args', 16)
        actor = read('actor', 160)
        require(struct.unpack_from('>HH', actor) == (288, 265), 'Carnby model')
        require(struct.unpack_from('>H', body)[0] == 3, 'model header')
        model = body[:16] + body[26:]
        key = hashlib.sha256(args[:12] + model).digest()
        records.append((number, dict(phases), key))
    return records


def describe(label, records):
    print(f'PASS {label}: {len(records)} complete natural Carnby render calls')
    for start, end in SPANS:
        values = [phases[end] - phases[start] for _, phases, _ in records]
        print(f'  {start} to {end}: ticks min/median/max '
              f'{min(values)}/{statistics.median(values):g}/{max(values)}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('log', type=Path)
    parser.add_argument('folder', type=Path)
    parser.add_argument('--status', type=int, required=True)
    parser.add_argument('--reference-log', type=Path)
    parser.add_argument('--reference-folder', type=Path)
    parser.add_argument('--reference-status', type=int)
    args = parser.parse_args()
    current = load(args.log, args.folder, args.status)
    describe('current', current)
    if args.reference_log:
        require(args.reference_folder is not None and args.reference_status is not None,
                'reference folder and exit status required')
        reference = load(args.reference_log, args.reference_folder, args.reference_status)
        describe('reference', reference)
        groups = []
        for records in (reference, current):
            index = defaultdict(list)
            for record in records:
                index[record[2]].append(record)
            groups.append(index)
        shared = groups[0].keys() & groups[1].keys()
        unique = [key for key in shared if all(len(g[key]) == 1 for g in groups)]
        print(f'Exact geometry/transform keys: {len(shared)} shared, '
              f'{len(unique)} unique pairs')
        for key in sorted(unique):
            left, right = (g[key][0] for g in groups)
            spans = ', '.join(f'{start}→{end} '
                              f'{left[1][end]-left[1][start]}→'
                              f'{right[1][end]-right[1][start]}' for start, end in SPANS)
            print(f'  reference {left[0]} / current {right[0]}: {spans} ticks')
        print('Model/transform agreement does not establish identical surrounding '
              'actors, cache state, interrupt phase or completed-frame pixels.')


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError, struct.error) as error:
        raise SystemExit('FAIL corridor phases: ' + str(error))
