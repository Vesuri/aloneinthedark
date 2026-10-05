#!/usr/bin/env python3
"""Verify ordinary-control oil-lamp pickup on original Mac and Amiga."""
import argparse
from pathlib import Path
import re
import struct
from check_menu_keyboard import require


def check(mac, native, folder, mac_status, native_status):
    for label, log, status, marker in (
        ('Mac', mac, mac_status, 'PASS original oil lamp pickup inventory and world state'),
        ('Amiga', native, native_status, 'PASS LAMP taken world object, inventory slot and returned gameplay publication'),
    ):
        require(status == 0 and log.count(marker) == 1, label+' normal completion')
        require(not re.search(r'FAIL|TIMEOUT|LUA ERROR|Error in|Program received signal', log), label+' diagnostic failure')
    require(mac.count('Exited via the debugger') == 1 and native.count('[Inferior 1 (Remote target) detached]') == 1, 'observer completion')
    phases = ['initial','turned-left','lamp-x','facing-table','lamp-approach','open-mode','search-lamp','taken-lamp']
    m = re.findall(r'^LAMP_STATE phase=(\S+) flags=([0-9A-F]+) count=(-?\d+) slot0=(-?\d+) slot1=(-?\d+) stage=(-?\d+) room=(-?\d+)$', mac, re.M)
    require([r[0] for r in m] == phases, 'Mac ordinary pickup phases')
    n = re.findall(r'^LAMP_NATIVE stage=(\d+) tick=(\d+) x=(-?\d+) z=(-?\d+) beta=(-?\d+) anim=(-?\d+) flags=([0-9A-F]+) count=(-?\d+) slot0=(-?\d+) slot1=(-?\d+) objectFloor=(-?\d+) objectRoom=(-?\d+) frames=(\d+)$', native, re.M)
    require([int(r[0]) for r in n] == list(range(1,16)), 'native movement/search/take phases')
    require(int(n[-1][-1]) > int(n[-2][-1]), 'native gameplay publication after Take')
    for label, initial, final in [('Mac','lamp-initial-a5.bin','lamp-taken-lamp-a5.bin'),('Amiga','lamp-native-2-a5.bin','lamp-native-15-a5.bin')]:
        states=[]
        for name in (initial, final):
            data=(folder/name).read_bytes();require(len(data)==75616, label+' captured A5 extent')
            def word(offset):return struct.unpack_from('>h',data,75616+offset)[0]
            obj=-0x115f2+13*52;actor=-0xb292+160
            states.append((word(obj+12)&65535,word(-0xd8a6),word(-0xd8a4),word(-0xd8a2),word(obj+28),word(obj+30)))
            require(tuple(word(actor+i) for i in (0,2,0x2e,0x30))==(1,12,0,0),label+' attic Carnby identity')
            if name==final:
                require((word(actor+0x3e),word(actor+0x52))==(4,1),label+' idle manual control returned')
                require(word(actor+0x1c)>=3600 and word(actor+0x20)<=-3800,label+' real approach to lamp')
        require(states==[(0x609,1,2,0,0,0),(0x8609,2,2,13,-1,-1)],label+' actual inventory insertion and world removal')
    require(tuple([int(m[-1][1],16)]+list(map(int,m[-1][2:])))==(0x8609,2,2,13,-1,-1),'Mac logged final inventory')
    require(tuple([int(n[-1][6],16)]+list(map(int,n[-1][7:12])))==(0x8609,2,2,13,-1,-1),'native logged final inventory')
    require(len((folder/'lamp-mac-taken-lamp-rgb.bin').read_bytes())==1228800,'Mac returned frame extent')
    pixels=(folder/'lamp-native-screen.bin').read_bytes()
    require(len(pixels)==307200 and len(set(pixels))>32,'native returned scene pixels')
    require(len((folder/'lamp-native-clut.bin').read_bytes())==2056,'native palette extent')
    print('PASS lamp pickup: ordinary controls, inventory 1→2, lamp slot 1, removed world object and returned gameplay on Mac/Amiga')


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('mac',type=Path);p.add_argument('native',type=Path)
    p.add_argument('--mac-status',type=int,required=True);p.add_argument('--native-status',type=int,required=True)
    p.add_argument('--folder',type=Path,default=Path('tmp/m3-explore'))
    a=p.parse_args()
    try:check(a.mac.read_text(),a.native.read_text(),a.folder,a.mac_status,a.native_status)
    except (OSError,ValueError) as error:raise SystemExit('FAIL lamp pickup: '+str(error))
