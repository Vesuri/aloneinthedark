#!/usr/bin/env python3
"""Verify one continuous original first-floor circuit, excluding idle waits."""
import argparse
from pathlib import Path
import re
import struct
from check_menu_keyboard import require


def check(log, folder, status):
    require(status == 0 and log.count('PASS original continuous firstfloor tenminute circuit') == 1,
            'normal continuous route completion')
    require(not re.search(r'FAIL|TIMEOUT|LUA ERROR|VP ERROR|Program received signal', log), 'no route failure')
    variables = {label: [int(v) for v in values.split(',')]
                 for label, values in re.findall(r'ROOM5_VARS phase=(\S+) values=([0-9,-]+)', log)}
    cycles = [(int(a), int(b), int(c), int(d)) for a, b, c, d in
              re.findall(r'CIRCUIT_CYCLE cycle=(\d+) tick=(\d+) active=(\d+) hp=(\d+)', log)]
    require(cycles and [c[0] for c in cycles] == list(range(1, len(cycles) + 1)), 'contiguous circuit cycles')
    require(all(a[1] < b[1] and a[2] < b[2] for a, b in zip(cycles, cycles[1:])), 'increasing clock and active coverage')
    checkpoints = (('circuit-bathroom-hallway', 1), ('circuit-enter-room4', 4), ('circuit-enter-room5', 5),
                   ('circuit-east-hallway', 1), ('circuit-bedroom-door-z', (1, 2)), ('circuit-bedroom-north', 2),
                   ('circuit-return-room5', 5), ('circuit-return-room4', 4), ('circuit-complete', 1),
                   ('circuit-repeat-bathroom-manual', 3))
    previous_tick = 0
    for cycle, tick, active, hp in cycles:
        require(hp > 0, 'living cycle endpoint')
        for suffix, room in checkpoints:
            label = f'cycle-{cycle}-' + suffix
            allowed_rooms = room if isinstance(room, tuple) else (room,)
            row = re.search(r'EXPLORE phase=' + re.escape(label) + r' tick=(\d+) .* anim=4 room=(\d+) floor=1 ', log)
            require(row is not None and int(row[2]) in allowed_rooms and previous_tick < int(row[1]) <= tick, 'ordered real destination ' + label)
            room = int(row[2])
            previous_tick = int(row[1])
            data = (folder / ('hallway-session-lamp-use-' + label + '-a5.bin')).read_bytes()
            require(len(data) == 75616, 'world extent ' + label)
            word = lambda offset: struct.unpack_from('>h', data, 75616 + offset)[0]
            hero = -0xb292 + 160
            require(tuple(word(hero + offset) for offset in (0, 2, 0x2e, 0x30, 0x3e, 0x52)) == (1, 12, 1, room, 4, 1),
                    'actual manual actor ' + label)
            require(variables[label][21] > 0, 'positive health ' + label)
            if suffix == 'circuit-bedroom-door-z' and room == 1:
                require(word(hero + 0x20) <= -850, 'actual hallway approach before bedroom doorway')
            require(tuple(word(offset) for offset in (-0xd8a6, -0xd8a4, -0xd8a2, -0xd8a8)) == (2, 2, 13, 2),
                    'retained Actions/lamp inventory ' + label)
            require(len((folder / ('hallway-session-lamp-use-mac-' + label + '-rgb.bin')).read_bytes()) == 1228800,
                    'logical image extent ' + label)
            if suffix == 'circuit-complete':
                require(word(hero + 0x1c) < 1300 and variables[label][90] == 64, 'western hallway and actual Open/Search')
                require(variables[label][20] == 0 and variables[label][40] <= 0 and variables[label][57] <= 0,
                        'completed deaths')
                for index in (35, 62):
                    enemy = -0x115f2 + index * 52
                    require(tuple(word(enemy + offset) for offset in (0, 28, 30)) == (-1, -1, -1), 'removed enemy ' + str(index))
        require(variables[f'cycle-{cycle}-circuit-repeat-bathroom-manual'][21] == hp, 'endpoint health agrees')
    require(variables['cycle-1-circuit-bedroom-reopened'][30] == 1, 'actual bedroom door reopened before fight')
    victory = variables['cycle-1-circuit-bedroom-victory']
    require(victory[20] == 0 and victory[40] <= 0 and victory[21] > 0 and victory[90] == 16, 'actual first bedroom victory')
    activity = re.search(r'ACTIVE_GAMEPLAY_FINAL route=firstfloor-endurance ticks=(\d+) move=(\d+) turn=(\d+) kick=(\d+) samples=(\d+) rooms=([\d,]+)', log)
    require(activity and int(activity[1]) >= 36000 and int(activity[1]) == cycles[-1][2], 'continuous ten-minute active gate')
    require(sum(int(activity[i]) for i in (2, 3, 4)) == int(activity[1]) and int(activity[2]) > 0,
            'activity accounting includes movement')
    require({1, 2, 3, 4, 5}.issubset({int(v) for v in activity[6].split(',')}), 'active coverage across connected rooms')
    print(f'PASS original continuous first-floor circuit: {len(cycles)} living cycles; active ticks={activity[1]}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('log', type=Path)
    parser.add_argument('--folder', type=Path, required=True)
    parser.add_argument('--status', type=int, required=True)
    args = parser.parse_args()
    try:
        check(args.log.read_text(), args.folder, args.status)
    except (ValueError, OSError, KeyError) as error:
        raise SystemExit('FAIL original continuous circuit: ' + str(error))
