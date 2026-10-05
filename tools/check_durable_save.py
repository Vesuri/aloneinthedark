#!/usr/bin/env python3
"""Verify saved bytes and restored state across an abrupt emulator restart."""
import argparse
from pathlib import Path
import re
import struct
from check_menu_keyboard import require


def check(saved, loaded, folder, save_status, load_status):
    require(save_status == load_status == 0, 'both runner exit statuses')
    for label, text, marker in (
        ('save', saved, 'PASS DURABLE SAVE abrupt restart boundary'),
        ('load', loaded, 'PASS DURABLE LOAD restored saved state after abrupt restart and Quit'),
    ):
        require(text.count(marker) == 1 and text.count('[Inferior 1 (Remote target) detached]') == 1, label+' normal observer completion')
        require(not re.search(r'FAIL|TIMEOUT|Error in|Program received signal', text), label+' diagnostic errors')
    require('MENU_EXIT' not in saved and 'DRIVER8_NATIVE_ENTER' not in saved, 'save run ended before normal Quit')
    boundary = re.findall(r'^PASS DURABLE SAVE abrupt restart boundary tick=(\d+) bytes=36254 frames=(\d+)$', saved, re.M)
    require(len(boundary) == 1 and int(boundary[0][1]) > 0, 'save closed and gameplay publication resumed')
    rows = re.findall(r'^SAVELOAD_STATE stage=(\d+) tick=(\d+) x=(-?\d+) z=(-?\d+) anim=(-?\d+) room=(-?\d+) floor=(-?\d+) saved=(-?\d+),(-?\d+) closed=(\d+) read=(\d+)$', loaded, re.M)
    require([int(r[0]) for r in rows] == [2, 3, 4, 5, 6], 'fresh boot move/load phases, no Save phase')
    states = {int(r[0]): tuple(map(int, r[1:])) for r in rows}
    require(all(row[8] == 0 for row in states.values()) and states[6][9] >= 10000, 'actual load without preceding save')
    require(abs(states[3][2]-states[2][2]) >= 300 and states[3][3] == 254 and states[4][3] == 4, 'fresh boot movement before load')
    before = (folder/'durable-save-before.itd').read_bytes()
    after = (folder/'durable-save-after.itd').read_bytes()
    require(len(before) == 36254 and before == after, 'identical durable file, no overwrite during load')
    a = (folder/'durable-saved-actor.bin').read_bytes()
    b = (folder/'durable-native-6-actor.bin').read_bytes()
    require(len(a) == len(b) == 160, 'actor capture extents')
    offsets = (0, 2, 0x1c, 0x20, 0x30, 0x2e, 0x3e)
    words = lambda data: tuple(struct.unpack_from('>h', data, offset)[0] for offset in offsets)
    require(words(a) == words(b) == (1, 12, 3231, -1548, 0, 0, 4), 'pre-restart saved actor/room restored')
    print('PASS durability: abrupt emulator restart after published Save success, unchanged file, real load and restored actor/room')


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('saved', type=Path); p.add_argument('loaded', type=Path)
    p.add_argument('--save-status', type=int, required=True); p.add_argument('--load-status', type=int, required=True)
    p.add_argument('--folder', type=Path, default=Path('tmp/m3-saveload'))
    a = p.parse_args()
    try:
        check(a.saved.read_text(), a.loaded.read_text(), a.folder, a.save_status, a.load_status)
    except (ValueError, OSError) as error:
        raise SystemExit('FAIL durability: '+str(error))
