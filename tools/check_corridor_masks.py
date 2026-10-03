#!/usr/bin/env python3
"""Compare fully bracketed natural mask calls and exact polygon/region captures.

The earlier native observer also reported internal stages during a later scene
transition. Count file ordinals globally but exclude unbracketed stages from
all timing and geometry claims. No original game data is embedded here.
"""
import argparse
from collections import Counter
import hashlib
from pathlib import Path
import re
import struct


def require(ok, message):
    if not ok:
        raise SystemExit('FAIL ' + message)


def load(root, side, status):
    log = (root / (side + '.log')).read_text()
    require(status == 0 and 'PASS natural corridor mask stages' in log
            and not re.search(r'FAIL|[Tt]imeout|Error in|Protocol error', log), side + ' completion')
    require(('Exited via the debugger' if side == 'mac' else
             '[Inferior 1 (Remote target) detached]') in log, side + ' natural exit')
    calls, active, ordinal, excluded = [], None, 0, 0
    for step, number, actor, stage, ticks in re.findall(
            r'MASK_STAGE step=(\d+) call=(\d+) actor=(-?\d+) stage=(\S+) ticks=(\d+)', log):
        key = (int(step), int(number), int(actor))
        if stage == 'polygon':
            ordinal += 1
        if stage == 'begin':
            require(active is None, side + ' non-nested call')
            active = {'key': key, 'stages': [], 'polygons': []}
        if active is None:
            excluded += 1
            continue
        require(active['key'] == key, side + ' stable call identity')
        active['stages'].append((stage, int(ticks)))
        if stage == 'polygon':
            active['polygons'].append(ordinal)
        if stage == 'end':
            counts = Counter(label for label, _ in active['stages'])
            require(counts['polygon'] == counts['polygon-done'] == counts['close-done']
                    == counts['inset-done'], side + ' balanced construction')
            require(counts['copy'] == counts['copy-done'], side + ' balanced copies')
            require(all(b[1] >= a[1] for a, b in zip(active['stages'], active['stages'][1:])),
                    side + ' monotonic ticks')
            calls.append(active)
            active = None
    require(active is None and len(calls) >= 10, side + ' complete calls')
    geometry = {}
    for call in calls:
        call['hashes'] = []
        for index in call['polygons']:
            polygon = (root / f'{side}-poly-{index:03d}.bin').read_bytes()
            region = (root / f'{side}-region-{index:03d}.bin').read_bytes()
            require(26 <= len(polygon) <= 270 and struct.unpack_from('>H', polygon)[0] == len(polygon),
                    side + ' polygon extent')
            require(10 <= len(region) <= 4096 and struct.unpack_from('>H', region)[0] == len(region),
                    side + ' region extent')
            key = hashlib.sha256(polygon).hexdigest()
            require(key not in geometry or geometry[key] == region, side + ' stable polygon result')
            geometry[key] = region
            call['hashes'].append(key)
    print(f'{side}: {len(calls)} complete calls; {excluded} unbracketed stages excluded')
    return calls, geometry


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('folder', type=Path)
    parser.add_argument('--mac-status', type=int, required=True)
    parser.add_argument('--amiga-status', type=int, required=True)
    args = parser.parse_args()
    mac, mg = load(args.folder, 'mac', args.mac_status)
    amiga, ag = load(args.folder, 'amiga', args.amiga_status)
    require(mg and mg == ag, 'identical polygon keys and exact resulting region bytes')
    cold = [max(calls, key=lambda call: len(call['polygons'])) for calls in (mac, amiga)]
    require(cold[0]['hashes'] == cold[1]['hashes'], 'identical ordered cold-call polygons')
    for side, call in zip(('mac', 'amiga'), cold):
        stages = call['stages']
        parts = Counter()
        for a, b in zip(stages, stages[1:]):
            parts[(a[0], b[0])] += b[1] - a[1]
        print(f"{side}: cold call {call['key']}, {len(call['polygons'])} polygons, "
              f"{stages[-1][1]-stages[0][1]} ticks")
        for (start, end), ticks in sorted(parts.items()):
            if ticks:
                print(f'  {start} -> {end}: {ticks}')
    print(f'PASS {len(mg)} identical polygon geometries and byte-exact expanded regions; matched cold construction')


if __name__ == '__main__':
    main()
