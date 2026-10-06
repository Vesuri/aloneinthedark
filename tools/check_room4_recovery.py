#!/usr/bin/env python3
"""Verify original living room-4 knockback, walking recovery and connecting-door exit."""
import argparse
from pathlib import Path
import re
import struct
from check_menu_keyboard import require


def check(log, folder, status):
    require(status == 0 and log.count('PASS original living room4 connecting-door recovery and enemy removal') == 1,
            'normal original recovery completion')
    require(not re.search(r'FAIL|TIMEOUT|LUA ERROR|VP ERROR|Program received signal', log), 'no recovery failure')
    variables = {label: list(map(int, values.split(','))) for label, values in
                 re.findall(r'ROOM5_VARS phase=(\S+) values=([0-9,-]+)', log)}
    phases = ('live-door-east', 'live-recovery-room4', 'live-recovery-resumed-fight',
              'live-recovery-approach-1', 'live-recovery-victory', 'live-recovery-open-request',
              'live-postcombat-door-aligned', 'live-recovery-room5-after-victory', 'live-recovery-room5-search')
    previous_tick = 0
    positions = {}
    captures = {}
    for phase in phases:
        row = re.search(r'EXPLORE phase=' + re.escape(phase) + r' tick=(\d+) x=(-?\d+) z=(-?\d+) beta=(\d+) anim=4 room=(\d+) floor=1 ', log)
        require(row is not None and int(row[1]) >= previous_tick, 'ordered real manual phase ' + phase)
        previous_tick = int(row[1])
        data = (folder / ('hallway-session-lamp-use-' + phase + '-a5.bin')).read_bytes()
        require(len(data) == 75616, 'complete original world ' + phase)
        captures[phase] = data
        word = lambda offset: struct.unpack_from('>h', data, 75616 + offset)[0]
        hero = -0xb292 + 160
        room = 5 if phase in (phases[0], *phases[-2:]) else 4
        require(tuple(word(hero + o) for o in (0, 2, 0x2e, 0x30, 0x3e, 0x52)) ==
                (1, 12, 1, room, 4, 1), 'actual living manual destination ' + phase)
        require((word(hero + 0x1c), word(hero + 0x20), word(hero + 0x2a), room) ==
                tuple(map(int, (row[2], row[3], row[4], row[5]))), 'captured position agrees ' + phase)
        positions[phase] = (word(hero + 0x1c), word(hero + 0x20))
        values = variables[phase]
        require(values[21] > 0 and tuple(word(o) for o in (-0xd8a6, -0xd8a4, -0xd8a2, -0xd8a8)) ==
                (2, 2, 13, 2), 'positive health and retained inventory ' + phase)
        if phase in phases[2:4]:
            require(values[90] == 16 and values[57] == 10, 'actual Fight before enemy damage ' + phase)
        if phase in phases[4:]:
            enemy = -0x115f2 + 62 * 52
            require(values[57] <= 0 and tuple(word(enemy + o) for o in (0, 28, 30)) == (-1, -1, -1),
                    'completed target enemy death/removal ' + phase)
        if phase == 'live-recovery-open-request':
            require(values[90] in (16, 64), 'actual Search or retained Fight after O')
        if phase == phases[-1]:
            require(values[90] == 64, 'actual final living room5 Open/Search')
        if phase == 'live-postcombat-door-aligned':
            require(650 <= word(hero + 0x20) <= 1050, 'actual released connecting-door alignment')
        require(len((folder / ('hallway-session-lamp-use-mac-' + phase + '-rgb.bin')).read_bytes()) == 1228800,
                'complete logical original frame ' + phase)
    require(positions[phases[2]] != positions[phases[3]], 'ordinary walking after living room4 transition')
    aim = re.search(r'RECOVERY_AIM attempt=1 room=4 enemyRoom=5 dx=(-?\d+) dz=(-?\d+) target=(\d+)', log)
    require(aim and max(abs(int(aim[1])), abs(int(aim[2]))) > 800 and int(aim[3]) % 128 == 0,
            'actual out-of-range adjacent-room enemy and reachable heading')
    data = captures['live-recovery-resumed-fight']
    word = lambda offset: struct.unpack_from('>h', data, 75616 + offset)[0]
    hero = -0xb292 + 160
    slot = word(-0x115f2 + 62 * 52)
    require(0 <= slot < 50, 'actual active target slot')
    enemy = -0xb292 + slot * 160
    require(tuple(word(enemy + o) for o in (0, 2, 0x2e, 0x30, 0x34)) == (62, 73, 1, 5, 84),
            'actual adjacent-room target actor')
    require((word(enemy + 0x22) - word(hero + 0x22), word(enemy + 0x26) - word(hero + 0x26)) ==
            (int(aim[1]), int(aim[2])), 'reported aim uses captured shared scene coordinates')
    require((word(enemy + 0x22) - word(enemy + 0x1c), word(enemy + 0x26) - word(enemy + 0x20)) ==
            (4500, 100), 'actual adjacent-room coordinate translation')
    print('PASS original room4 recovery: living transition, ordinary walking/Fight, actual enemy removal, released door alignment and living room5 Search')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('log', type=Path)
    parser.add_argument('--folder', type=Path, required=True)
    parser.add_argument('--status', type=int, required=True)
    args = parser.parse_args()
    try:
        check(args.log.read_text(), args.folder, args.status)
    except (ValueError, OSError, KeyError) as error:
        raise SystemExit('FAIL original room4 recovery: ' + str(error))
