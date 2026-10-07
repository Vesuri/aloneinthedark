#!/usr/bin/env python3
"""Verify the direct-combat continuous new-game first-floor route; recovery variants are separate."""
import argparse
from pathlib import Path
import re
import struct
from check_menu_keyboard import require
from check_native_room4_recovery import snapshot, records
from check_native_firstfloor_circuit import check as check_circuit


def check(original, original_folder, native, folder, original_status, native_status):
    require('DIALOG_STATE checkpoint-load-choice' not in original,
            'original session starts a new game rather than loading a checkpoint')
    check_circuit(original, original_folder, original_status, native, folder / 'circuit', native_status)
    starts = records(native, 'NEWGAME_NATIVE')
    require(len(starts) == 1, 'one captured native new-game start')
    hero = -0xb292 + 160
    word, values = snapshot(folder / 'prefix', 'newgame')
    # The earliest native input capture may precede the Actions inventory setup;
    # the original screenshot observer starts at its later idle room view.
    inventory = tuple(word(o) for o in (-0xd8a8, -0xd8a6, -0xd8a4, -0xd8a2))
    require(tuple(word(hero + o) for o in (0, 2, 0x2e, 0x30)) == (1, 12, 0, 0)
            and values[21] == 20 and (inventory == (-1, 0, 0, 0)
                                     or (inventory[1:3] == (1, 2))),
            'fresh native attic hero, health and empty or Actions-only inventory')
    initial = (original_folder / 'hallway-session-lamp-use-initial-a5.bin').read_bytes()
    require(len(initial) == 75616, 'complete original new-game capture')
    ow = lambda offset: struct.unpack_from('>h', initial, len(initial) + offset)[0]
    require(tuple(ow(hero + o) for o in (0, 2, 0x2e, 0x30)) == (1, 12, 0, 0)
            and ow(-0xd8a6) == 1 and ow(-0xd8a4) == 2, 'fresh original attic and inventory')
    rows = records(native, 'ROOM3_NATIVE')
    phases = {r['stage']: r for r in rows}
    require(rows and all(r['health'] > 0 and r['drops'] == 0 for r in rows), 'living prefix and zero dropped transitions')
    require(all(a['stage'] < b['stage'] and a['tick'] <= b['tick'] for a, b in zip(rows, rows[1:])),
            'continuous forward prefix')
    source = {label: list(map(int, raw.split(','))) for label, raw in
              re.findall(r'ROOM5_VARS phase=(\S+) values=([0-9,-]+)', original)}
    for stage, label, room, action in ((21, 'room5-fight-selected', 5, 16),
                                      (23, 'room5-combat-result', 5, 16),
                                      (42, 'room4-manual', 4, 64),
                                      (53, 'hallway-west-side', 1, 64),
                                      (66, 'room3-manual', 3, 64)):
        row = phases[stage]
        word, values = snapshot(folder / 'prefix', 'native-' + str(stage))
        require(tuple(word(hero + o) for o in (0, 2, 0x2e, 0x30, 0x3e, 0x52)) == (1, 12, 1, room, 4, 1)
                and values[21] == row['health'] > 0 and values[90] == action,
                'captured native manual destination/action ' + str(stage))
        require(tuple(word(o) for o in (-0xd8a6, -0xd8a4, -0xd8a2, -0xd8a8)) == (2, 2, 13, 2),
                'native retained Actions/lamp inventory')
        raw = (original_folder / ('hallway-session-lamp-use-' + label + '-a5.bin')).read_bytes()
        require(len(raw) == 75616, 'original prefix world extent')
        ow = lambda offset: struct.unpack_from('>h', raw, len(raw) + offset)[0]
        require(tuple(ow(hero + o) for o in (0, 2, 0x2e, 0x30, 0x3e, 0x52)) == (1, 12, 1, room, 4, 1)
                and source[label][21] > 0 and source[label][90] == action, 'actual original prefix state')
        if stage == 21:
            require(values[57] > 0 and 0 <= word(-0x115f2 + 62 * 52) < 50, 'actual active native target before combat')
        else:
            require(values[57] <= 0 and source[label][57] <= 0, 'target death on both systems')
            for w in (word, ow):
                require(tuple(w(-0x115f2 + 62 * 52 + o) for o in (0, 28, 30)) == (-1, -1, -1),
                        'actual target removal through return')
        if stage == 53:
            require(word(hero + 0x1c) < 1300 and ow(hero + 0x1c) < 1300, 'hallway west of fall zone')
    alignment = records(native, 'HALL_ALIGNMENT')
    for index, row in enumerate(alignment):
        if row['phase'] not in (1, 3):
            continue
        require(index + 2 < len(alignment), 'complete alignment press/release/idle sequence')
        released, idle = alignment[index + 1:index + 3]
        key = 'down' if row['phase'] == 1 else 'up'
        require(row[key] == 1 and released['phase'] == row['phase'] + 1
                and released['animation'] == (256 if key == 'down' else 254)
                and released[key] == 0 and idle['phase'] == 0 and idle['animation'] == 4,
                'held alignment key released during actual movement before idle')
        require(row['tick'] < released['tick'] < idle['tick'] and idle['z'] != row['z'],
                'positive ordered alignment movement')
    if alignment:
        require(alignment[-1]['room'] == 1 and -150 <= alignment[-1]['z'] <= 0,
                'actual released hallway alignment before bathroom turn')
    circuit = records(native, 'CIRCUIT_NATIVE')[0]
    require(starts[0]['tick'] < phases[21]['tick'] < phases[66]['tick'] <= circuit['tick']
            and phases[66]['frames'] <= circuit['frames'], 'continuous start/combat/return/circuit clock')
    print('PASS paired direct-combat new-game circuit: fresh attic, enemy death, room4/hallway/bathroom return and ten minutes of active first-floor gameplay')


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('original', type=Path); p.add_argument('native', type=Path)
    p.add_argument('--original-folder', type=Path, required=True); p.add_argument('--folder', type=Path, required=True)
    p.add_argument('--original-status', type=int, required=True); p.add_argument('--native-status', type=int, required=True)
    a = p.parse_args()
    try:
        check(a.original.read_text(), a.original_folder, a.native.read_text(), a.folder, a.original_status, a.native_status)
    except (ValueError, OSError, KeyError, struct.error) as error:
        raise SystemExit('FAIL new-game circuit: ' + str(error))
