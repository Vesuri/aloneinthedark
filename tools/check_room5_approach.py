#!/usr/bin/env python3
"""Verify original ordinary-input room5 retreat, walking approaches and victory."""
import argparse
from pathlib import Path
import re
import struct
from check_menu_keyboard import require


def check(log, folder, status):
    require(status == 0 and log.count('PASS original room5 ordinary retreat and combat approach') == 1,
            'normal original route completion')
    require(not re.search(r'FAIL|TIMEOUT|LUA ERROR|VP ERROR|Program received signal', log), 'no observer failure')
    rows = {label: [int(v) for v in values.split(',')]
            for label, values in re.findall(r'ROOM5_VARS phase=(\S+) values=([0-9,-]+)', log)}
    retreat = rows['combat-retreat-gap']
    require(retreat[20] == 1 and retreat[21] > 0 and retreat[57] == 10 and retreat[90] == 16,
            'living retreat with active enemy and actual Fight')
    approaches = [label for label in rows if re.fullmatch(r'combat-approach-\d+', label)]
    require(approaches and re.search(r'ROOM5_KICK .*animation=262', log), 'walking approaches and actual kicks')
    positions = []
    for label in ['combat-retreat-gap', *approaches, 'room5-combat-result']:
        data = (folder / ('hallway-session-lamp-use-' + label + '-a5.bin')).read_bytes()
        require(len(data) == 75616, 'complete original world capture')
        word = lambda offset: struct.unpack_from('>h', data, 75616 + offset)[0]
        hero = -0xb292 + 160
        require(tuple(word(hero + offset) for offset in (0, 2, 0x2e, 0x30, 0x3e, 0x52)) ==
                (1, 12, 1, 5, 4, 1), 'living manual room5 actor: ' + label)
        require(rows[label][21] > 0 and rows[label][90] == 16, 'positive health and real Fight: ' + label)
        require(tuple(word(offset) for offset in (-0xd8a6, -0xd8a4, -0xd8a2, -0xd8a8)) == (2, 2, 13, 2),
                'retained Actions/lamp inventory: ' + label)
        positions.append((word(hero + 0x1c), word(hero + 0x20)))
        if label == 'room5-combat-result':
            enemy = -0x115f2 + 62 * 52
            require(tuple(word(enemy + offset) for offset in (0, 28, 30)) == (-1, -1, -1), 'actual enemy removal')
    require(len(set(positions)) > 1, 'actual movement after retreat')
    final = rows['room5-combat-result']
    require(final[20] == 0 and final[57] <= 0 and final[21] > 0, 'victory and living hero after death completes')
    print('PASS original combat approach: active retreat, actual walking/kicks, living manual room5, retained inventory and completed enemy removal')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('log', type=Path)
    parser.add_argument('--folder', type=Path, default=Path('tmp/m3-combat-approach'))
    parser.add_argument('--status', type=int, required=True)
    args = parser.parse_args()
    try:
        check(args.log.read_text(), args.folder, args.status)
    except (ValueError, OSError, KeyError) as error:
        raise SystemExit('FAIL original combat approach: ' + str(error))
