#!/usr/bin/env python3
"""Require actual attic movement and a published first-floor scene on both CPUs."""
import argparse
from pathlib import Path
import re
import struct
from check_menu_keyboard import require


def check(mac, native, folder, mac_status, native_status):
    for label, text, status, marker in (
        ('Mac', mac, mac_status, 'PASS original attic stairs reached first floor'),
        ('Amiga', native, native_status, 'PASS EXPLORE reached published first floor through ordinary keys'),
    ):
        require(status == 0 and text.count(marker) == 1, label+' normal completion')
        require(not re.search(r'FAIL|TIMEOUT|LUA ERROR|Error in|Program received signal', text), label+' diagnostic failure')
    require(mac.count('Exited via the debugger') == 1 and native.count('[Inferior 1 (Remote target) detached]') == 1, 'observer completion')
    original = re.findall(r'^EXPLORE phase=(\S+) tick=(\d+) x=(-?\d+) z=(-?\d+) beta=(-?\d+) anim=(-?\d+) room=(-?\d+) floor=(-?\d+) key=(-?\d+) action=(-?\d+)$', mac, re.M)
    phases = ['initial', 'back', 'east', 'partition-side', 'south', 'stair-opening', 'east-opening', 'inside-stairs', 'north-stairs', 'first-floor']
    require([r[0] for r in original] == phases, 'Mac waypoint order')
    m = {r[0]: tuple(map(int, r[1:])) for r in original}
    rows = re.findall(r'^EXPLORE_NATIVE stage=(\d+) tick=(\d+) x=(-?\d+) z=(-?\d+) beta=(-?\d+) anim=(-?\d+) room=(-?\d+) floor=(-?\d+) track=(-?\d+)$', native, re.M)
    require([int(r[0]) for r in rows] == list(range(1, 20)), 'native move/release/transition/publication phases')
    n = {int(r[0]): tuple(map(int, r[1:])) for r in rows}
    for label, states in [('Mac', m), ('Amiga', {name:n[stage] for name,stage in zip(phases,[1,3,5,7,9,11,13,15,17,19])})]:
        require(states['initial'][1:3] == (3231,-1548), label+' initial position')
        require(states['back'][2] >= 1000 and states['partition-side'][1] >= 4100, label+' real back/east movement')
        require(states['stair-opening'][2] >= 3600 and states['inside-stairs'][1] >= 6650, label+' actual stair opening approached')
        require(all(states[p][4:7] == (4,0,0) for p in phases[:-1]), label+' released attic movement')
        require(states['first-floor'][4:7] == (4,6,1), label+' first-floor idle room 6')
        require(all(states[b][0] > states[a][0] for a,b in zip(phases,phases[1:])), label+' advancing emulated ticks')
    require(m['first-floor'][7:] == (0,0), 'Mac released controls')
    require('EXPLORE_MANUAL track=1' in mac and n[19][7] == 1, 'manual control restored after original stair track')
    for label, file, offset in [('Mac', 'stairs-first-floor-a5.bin',75616-0xb292+160), ('Amiga','native-19-actor.bin',0)]:
        data = (folder/file).read_bytes()
        words = tuple(struct.unpack_from('>h',data,offset+i)[0] for i in (0,2,0x1c,0x20,0x2a,0x2e,0x30,0x3e,0x52))
        state=m['first-floor'] if label=='Mac' else n[19]
        require(words == (1,12,state[1],state[2],state[3],1,6,4,1), label+' captured position/heading/floor/room/manual identity')
    require(len((folder/'stairs-mac-first-floor-rgb.bin').read_bytes()) == 1228800, 'Mac first-floor frame extent')
    pixels = (folder/'stairs-native-screen.bin').read_bytes()
    require(len(pixels) == 307200 and len(set(pixels)) > 32, 'native published first-floor frame')
    require(len((folder/'stairs-native-clut.bin').read_bytes()) == 2056, 'native palette capture extent')
    print('PASS attic stairs: ordinary movement/turns, actual floor 0→1, room 6 idle actor and published scenes on Mac/Amiga')


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('mac',type=Path);p.add_argument('native',type=Path)
    p.add_argument('--mac-status',type=int,required=True);p.add_argument('--native-status',type=int,required=True)
    p.add_argument('--folder',type=Path,default=Path('tmp/m3-explore'))
    a=p.parse_args()
    try:check(a.mac.read_text(),a.native.read_text(),a.folder,a.mac_status,a.native_status)
    except (ValueError,OSError) as error:raise SystemExit('FAIL attic stairs: '+str(error))
