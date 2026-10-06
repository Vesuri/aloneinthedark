#!/usr/bin/env python3
"""Check the original living circuit through connected first-floor rooms."""
import argparse
from pathlib import Path
import re
import struct
from check_menu_keyboard import require


def check(log, folder, status):
    require(status == 0 and log.count('PASS original connected firstfloor circuit') == 1, 'normal circuit completion')
    require(not re.search(r'FAIL|TIMEOUT|LUA ERROR|VP ERROR|Program received signal', log), 'no route failure')
    variables = {label: [int(v) for v in values.split(',')]
                 for label, values in re.findall(r'ROOM5_VARS phase=(\S+) values=([0-9,-]+)', log)}
    cases = (('circuit-bathroom-hallway', 1), ('circuit-enter-room4', 4),
             ('circuit-enter-room5', 5), ('circuit-east-hallway', 1),
             ('circuit-bedroom-door-z', 2), ('circuit-bedroom-reopened', 2),
             ('circuit-bedroom-victory', 2), ('circuit-bedroom-hallway', 1),
             ('circuit-return-room5', 5), ('circuit-return-room4', 4), ('circuit-complete', 1))
    ticks = []
    for label, room in cases:
        row = re.search(r'EXPLORE phase=' + re.escape(label) + r' tick=(\d+) .* anim=4 room=' + str(room) + r' floor=1 ', log)
        require(row is not None, 'reported real manual destination ' + label)
        ticks.append(int(row[1]))
        data = (folder / ('hallway-session-lamp-use-' + label + '-a5.bin')).read_bytes()
        require(len(data) == 75616, 'world extent ' + label)
        word = lambda offset: struct.unpack_from('>h', data, 75616 + offset)[0]
        hero = -0xb292 + 160
        require(tuple(word(hero + offset) for offset in (0, 2, 0x2e, 0x30, 0x3e, 0x52)) == (1, 12, 1, room, 4, 1),
                'actual living manual actor ' + label)
        require(variables[label][21] > 0, 'positive health ' + label)
        require(tuple(word(offset) for offset in (-0xd8a6, -0xd8a4, -0xd8a2, -0xd8a8)) == (2, 2, 13, 2),
                'retained Actions/lamp inventory ' + label)
        require(len((folder / ('hallway-session-lamp-use-mac-' + label + '-rgb.bin')).read_bytes()) == 1228800,
                'logical scene extent ' + label)
        if label == 'circuit-bedroom-reopened':
            require(variables[label][30] == 1, 'actual bedroom door reopen')
        if label == 'circuit-bedroom-victory':
            require(variables[label][20] == 0 and variables[label][40] <= 0 and variables[label][90] == 16,
                    'actual bedroom victory in Fight mode')
        if label == 'circuit-complete':
            require(word(hero + 0x1c) < 1300 and variables[label][90] == 64, 'real western hallway and Open/Search')
            for index in (35, 62):
                enemy = -0x115f2 + index * 52
                require(tuple(word(enemy + offset) for offset in (0, 28, 30)) == (-1, -1, -1), 'actual removed enemy ' + str(index))
    require(all(a < b for a, b in zip(ticks, ticks[1:])), 'ordered destination captures')
    activity = re.search(r'ACTIVE_GAMEPLAY_FINAL route=firstfloor-circuit ticks=(\d+) .*rooms=([\d,]+)', log)
    require(activity and int(activity[1]) > 0 and {1, 2, 3, 4, 5}.issubset({int(v) for v in activity[2].split(',')}),
            'measured first-floor activity across circuit rooms')
    print('PASS original connected circuit: living real destinations, reopened bedroom door, both enemies removed, retained inventory; active ticks=' + activity[1] + '; not the ten-minute gate')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('log', type=Path)
    parser.add_argument('--folder', type=Path, default=Path('tmp/m3-circuit'))
    parser.add_argument('--status', type=int, required=True)
    args = parser.parse_args()
    try:
        check(args.log.read_text(), args.folder, args.status)
    except (ValueError, OSError, KeyError) as error:
        raise SystemExit('FAIL original connected circuit: ' + str(error))
