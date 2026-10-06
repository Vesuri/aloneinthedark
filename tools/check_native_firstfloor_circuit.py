#!/usr/bin/env python3
"""Check actual native continuous destinations against the verified original route."""
import argparse
from pathlib import Path
import re
import struct
from check_menu_keyboard import require
from check_firstfloor_endurance import check as check_original


def check(original_log, original_folder, original_status, native_log, folder, native_status):
    check_original(original_log, original_folder, original_status)
    require(native_status == 0 and native_log.count('PASS native continuous firstfloor circuit') == 1,
            'normal native completion')
    require(not re.search(r'FAIL|TIMEOUT|Program received signal', native_log), 'no native failure')
    rows = []
    for line in native_log.splitlines():
        if line.startswith('CIRCUIT_NATIVE '):
            rows.append({k: int(v) for k, v in re.findall(r'(\w+)=(-?\d+)', line)})
    require(rows and rows[-1]['stage'] == 65534, 'terminal native gate')
    final = rows[-1]
    require(final['active'] >= 36000 and final['move'] > 0 and final['samples'] > 0, 'ten-minute native active input gate')
    require(final['move'] + final['turn'] + final['kick'] == final['active'], 'native activity accounting')
    require(all(r['hp'] > 0 and r['body'] == 12 and r['floor'] == 1 and r['drops'] == 0 for r in rows),
            'living first-floor identity and zero dropped transitions throughout')
    require(all(a['tick'] <= b['tick'] and a['frames'] <= b['frames'] and a['active'] <= b['active']
                for a, b in zip(rows, rows[1:])), 'continuous ordered clock, frames and activity')
    cycles = sorted({r['cycle'] for r in rows})
    require(cycles == list(range(1, final['cycle'] + 1)), 'contiguous native cycles')
    # Destinations follow the original bathroom-room4-room5-east hall-bedroom-return circuit.
    destinations = ((2, (1,)), (8, (4,)), (12, (5,)), (21, (1,)), (24, (2,)),
                    (36, (1, 2)), (41, (1,)), (45, (5,)), (54, (4,)), (61, (1,)), (72, (3,)))
    previous_tick = 0
    for cycle in cycles:
        phases = {r['stage']: r for r in rows if r['cycle'] == cycle}
        previous_frame = 0
        for stage, rooms in destinations:
            require(stage in phases, 'native destination reached in cycle ' + str(cycle))
            row = phases[stage]
            require(row['room'] in rooms and row['animation'] == 4 and row['track'] == 1,
                    'actual manual destination ' + str(stage))
            require(row['tick'] > previous_tick and row['frames'] > previous_frame, 'ordered fresh destination scene')
            previous_tick, previous_frame = row['tick'], row['frames']
            prefix = folder / f'cycle-{cycle}-stage-{stage}'
            data = Path(str(prefix) + '-a5.bin').read_bytes()
            require(len(data) == 75616, 'complete native world')
            word = lambda offset: struct.unpack_from('>h', data, 75616 + offset)[0]
            actor = -0xb292 + 160
            require(tuple(word(actor + o) for o in (0, 2, 0x2e, 0x30, 0x3e, 0x52)) ==
                    (1, 12, 1, row['room'], 4, 1), 'actual captured manual actor')
            require((word(actor + 0x1c), word(actor + 0x20), word(actor + 0x2a)) ==
                    (row['x'], row['z'], row['beta']), 'reported and captured coordinates agree')
            require(tuple(word(o) for o in (-0xd8a6, -0xd8a4, -0xd8a2, -0xd8a8)) == (2, 2, 13, 2),
                    'retained Actions/lamp inventory')
            raw_vars = Path(str(prefix) + '-vars.bin').read_bytes()
            require(len(raw_vars) == 400, 'complete native variables')
            variables = struct.unpack('>200h', raw_vars)
            require(variables[21] == row['hp'] > 0 and variables[90] == row['action'], 'health and action agree')
            require(variables[57] <= 0 and word(-0x115f2 + 62*52) == -1, 'room5 enemy remains removed')
            if stage >= 36:
                require(variables[40] <= 0 and variables[20] == 0, 'bedroom encounter completed')
                require(tuple(word(-0x115f2 + 35*52 + o) for o in (0, 28, 30)) == (-1, -1, -1),
                        'actual bedroom enemy removal')
            if stage == 61:
                require(word(actor + 0x1c) < 1300 and variables[90] == 64, 'western hall and actual Open/Search')
            pixels = Path(str(prefix) + '-screen.bin').read_bytes()
            require(len(pixels) == 307200 and len(set(pixels)) > 32 and
                    len(Path(str(prefix) + '-clut.bin').read_bytes()) == 2056, 'populated logical picture and palette')
        if cycle == 1:
            require(35 in phases, 'actual first bedroom door event')
            door = struct.unpack('>200h', (folder / 'cycle-1-stage-35-vars.bin').read_bytes())
            require(door[30] == 1 and door[90] == 16 and door[21] > 0, 'actual door reopen while walking in Fight')
    require(final['room'] == 3 and final['animation'] == 4 and final['track'] == 1, 'living final bathroom')
    print(f'PASS paired continuous first-floor route: native cycles={len(cycles)} active ticks={final["active"]}; living destinations, bedroom death, retained room-5 removal, inventory, actual door/action states and zero dropped input')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('original', type=Path)
    parser.add_argument('native', type=Path)
    parser.add_argument('--original-folder', type=Path, required=True)
    parser.add_argument('--folder', type=Path, required=True)
    parser.add_argument('--original-status', type=int, required=True)
    parser.add_argument('--native-status', type=int, required=True)
    args = parser.parse_args()
    try:
        check(args.original.read_text(), args.original_folder, args.original_status,
              args.native.read_text(), args.folder, args.native_status)
    except (ValueError, OSError, KeyError) as error:
        raise SystemExit('FAIL native continuous circuit: ' + str(error))
