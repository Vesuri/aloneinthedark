#!/usr/bin/env python3
"""Require actual save IO, movement and loaded actor state on both machines."""
import argparse
from pathlib import Path
import re
import struct
from check_menu_keyboard import require


def check(mac, native, folder, mac_status, native_status):
    for label, text, status, marker in (
        ('Mac', mac, mac_status, 'PASS original save move load restored actor and quit'),
        ('Amiga', native, native_status, 'PASS SAVELOAD restored game state, keyboard quit and restoration'),
    ):
        require(status == 0 and text.count(marker) == 1, label+' normal completion')
        require(not re.search(r'FAIL|TIMEOUT|LUA ERROR|Error in|Program received signal', text), label+' diagnostic failure')
    require(native.count('[Inferior 1 (Remote target) detached]') == 1, 'native detach')
    rows = re.findall(r'^SAVELOAD_STATE stage=(\d+) tick=(\d+) x=(-?\d+) z=(-?\d+) anim=(-?\d+) room=(-?\d+) floor=(-?\d+) saved=(-?\d+),(-?\d+) closed=(\d+) read=(\d+)$', native, re.M)
    states = {int(r[0]): tuple(map(int, r[1:])) for r in rows}
    require([int(r[0]) for r in rows] == list(range(1, 7)), 'native ordered save/move/load phases')
    require(states[6][8] >= 10000 and states[6][9] >= 10000, 'native actual write/close and load reads')
    require(states[6][1:3] == states[1][1:3] and states[6][3:6] == (4, 0, 0), 'native restored position/room')
    require(abs(states[3][2]-states[1][2]) >= 300 and states[3][3] == 254 and states[4][3] == 4, 'native real walk/release')
    original = re.findall(r'^SAVELOAD_STATE phase=(\S+) tick=(\d+) x=(-?\d+) z=(-?\d+) anim=(-?\d+) room=(-?\d+) floor=(-?\d+) closed=(\d+) read=(\d+)$', mac, re.M)
    require([r[0] for r in original] == ['before-save', 'saved', 'moved', 'loaded'], 'Mac ordered save/move/load phases')
    m = {r[0]: tuple(map(int, r[1:])) for r in original}
    require(m['loaded'][6] >= 10000 and m['loaded'][7] >= 10000, 'Mac actual write/close and load reads')
    require(m['loaded'][1:6] == m['before-save'][1:6], 'Mac restored position/room')
    require(abs(m['moved'][2]-m['saved'][2]) >= 300 and m['moved'][3] == 4, 'Mac real walk/release')
    for label, phases in (('mac', ['before-save', 'saved', 'moved', 'loaded']), ('native', [1, 2, 3, 4, 5, 6])):
        captured = []
        for phase in phases:
            data = (folder/f'{label}-{phase}-actor.bin').read_bytes()
            require(len(data) == 160, label+' actor capture extent')
            words = tuple(struct.unpack_from('>h', data, offset)[0] for offset in (0, 2, 0x1c, 0x20, 0x30, 0x32, 0x3e))
            require(words[:2] == (1, 12) and words[4:6] == (0, 0), label+' Carnby attic identity')
            captured.append(words)
        require(captured[0] == captured[-1], label+' captured save/load identity')
    print('PASS saveload: paired actual save close/read, movement, restored actor/room and native Quit cleanup')


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('mac', type=Path); p.add_argument('native', type=Path)
    p.add_argument('--mac-status', type=int, required=True); p.add_argument('--native-status', type=int, required=True)
    p.add_argument('--folder', type=Path, default=Path('tmp/m3-saveload'))
    a = p.parse_args()
    try:
        check(a.mac.read_text(), a.native.read_text(), a.folder, a.mac_status, a.native_status)
    except (ValueError, OSError) as error:
        raise SystemExit('FAIL saveload: '+str(error))
