#!/usr/bin/env python3
"""Require ordinary movement, natural death ABI and restored new-game state."""
import argparse
from pathlib import Path
import re
import struct
from check_menu_keyboard import require, rgb
from check_video_transfer import native as display_transfer


def check(original, native, folder, original_status, native_status, exact_pixels=False):
    for label, text, status, marker in (
        ('Mac', original, original_status, 'PASS original natural death music ABI and new-game restart'),
        ('Amiga', native, native_status, 'PASS DEATH ROUTE natural death music ABI and new-game restart'),
    ):
        require(status == 0 and text.count(marker) == 1, label+' normal completion')
        require(not re.search(r'FAIL|TIMEOUT|LUA ERROR|Error in|Program received signal', text), label+' diagnostic failure')
    require(native.count('[Inferior 1 (Remote target) detached]') == 1, 'native detach')
    back = re.findall(r'^DEATH_BACK tick=(\d+) x=(-?\d+) z=(-?\d+) anim=(-?\d+)$', original, re.M)
    require(len(back) == 1 and int(back[0][1]) == 3231 and int(back[0][2]) >= -1548 and int(back[0][3]) == 4,
            'original backward movement/release positive control')
    stages = list(map(int, re.findall(r'^DEATH_ROUTE_STAGE stage=(\d+)', native, re.M)))
    require(stages == sorted(stages) and list(dict.fromkeys(stages)) == [1, 2, 3, 4, 5], 'native movement/death/menu/restart phases')
    state = re.findall(r'^DEATH_STATE tick=(\d+) mode=(\d+) room=(-?\d+) floor=(-?\d+) anim=(-?\d+) x=(-?\d+) z=(-?\d+) word88=(-?\d+)$', native, re.M)
    movement = re.findall(r'^DEATH_ROUTE_STAGE stage=([123]) tick=\d+\nDEATH_STATE tick=\d+ mode=\d+ room=(-?\d+) floor=(-?\d+) anim=(-?\d+) x=(-?\d+) z=(-?\d+) word88=-?\d+$', native, re.M)
    start = next((tuple(map(int,row[1:])) for row in movement if row[0]=='1'), None)
    back_native = next((tuple(map(int,row[1:])) for row in movement if row[0]=='2'), None)
    idle = next((tuple(map(int,row[1:])) for row in movement if row[0]=='3'), None)
    require(start and back_native and idle and start[4] < -1548 <= back_native[4]
            and back_native[4]-start[4] > 300 and idle[:3] == (0,0,4), 'native backward movement/release')
    for label, text in (('Mac', original), ('Amiga', native)):
        require(len(re.findall(r'^DEATH_ENTER .*anim=261\b', text, re.M)) == 1, label+' natural death animation')
        returns = re.findall(r'^DEATH_RETURN tick=(\d+) preserved=13 result=0/12(?: resources=17 samples=9)?$', text, re.M)
        require(len(returns) == 1, label+' death music preserved-register/result ABI')
        restarted = re.findall(r'^DEATH_RESTART tick=(\d+) actor=1 body=12 x=3231 z=-1548 anim=4 room=0 floor=0(?: frames=(\d+))?$', text, re.M)
        require(len(restarted) == 1 and int(restarted[0][0]) > int(returns[0]), label+' fresh Carnby attic state')
        name = 'mac' if label == 'Mac' else 'native'
        data = (folder/f'death-restart-{name}-actor.bin').read_bytes()
        require(len(data) == 160, label+' actor capture extent')
        word = lambda offset: struct.unpack_from('>h', data, offset)[0]
        require(tuple(word(i) for i in (0, 2, 0x1c, 0x20, 0x30, 0x2e, 0x3e)) == (1, 12, 3231, -1548, 0, 0, 4),
                label+' captured restart identity')
    mac = (folder/'death-restart-mac-rgb.bin').read_bytes()
    amiga = rgb((folder/'death-restart-native-screen.bin').read_bytes(),
                (folder/'death-restart-native-clut.bin').read_bytes(), display_transfer()[::256])
    require(len(mac) == len(amiga) == 921600, 'restart frame extent')
    viewport = [i for y in range(150, 350) for i in range((y*640+160)*3, (y*640+480)*3)]
    require(len({amiga[(y*640+x)*3:(y*640+x)*3+3] for y in range(150,350) for x in range(160,480)}) > 32, 'rendered native restart viewport')
    differences = sum(mac[i] != amiga[i] for i in viewport)
    if exact_pixels:
        require(differences == 0, f'exact 320x200 restart viewport ({differences} differing components)')
    print(f'RESTART_PIXEL_COMPONENT_DIFFERENCES {differences}')
    print('PASS death route: real backward movement, natural death song ABI, menu/new-game restart, identical Carnby room/position and rendered viewport')


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('original', type=Path); p.add_argument('native', type=Path)
    p.add_argument('--original-status', type=int, required=True); p.add_argument('--native-status', type=int, required=True)
    p.add_argument('--folder', type=Path, default=Path('tmp/m3-death'))
    p.add_argument('--exact-pixels', action='store_true', help='Require equal idle pose/publication phase as an additional fidelity gate')
    a = p.parse_args()
    try:
        check(a.original.read_text(), a.native.read_text(), a.folder, a.original_status, a.native_status, a.exact_pixels)
    except (ValueError, OSError) as error:
        raise SystemExit('FAIL death route: '+str(error))
