#!/usr/bin/env python3
"""Verify a paired lamp-to-first-floor session; this is not the ten-minute gate."""
import argparse
from pathlib import Path
import re
import struct
from check_menu_keyboard import require
from check_lamp_use import check as check_use


def check(mac,native,folder,mac_status,native_status):
    check_use(mac,native,folder,mac_status,native_status,session=True)
    rows=re.findall(r'^EXPLORE_NATIVE stage=(\d+) tick=(\d+) x=(-?\d+) z=(-?\d+) beta=(-?\d+) anim=(-?\d+) room=(-?\d+) floor=(-?\d+) track=(-?\d+)$',native,re.M)
    require([int(r[0]) for r in rows]==list(range(1,27)),'native stair/passage input phases')
    states={int(r[0]):tuple(map(int,r[1:])) for r in rows}
    require(states[1][1]>=3600 and states[1][2]>=-3500 and states[1][4:]==(287,0,0,1),'native exploration starts after actual lamp Use movement')
    require(states[3][2]>=1000 and states[7][1]>=4100 and states[11][2]>=3600 and states[15][1]>=6650,'native actual attic waypoints')
    require(states[19][5:]==(6,1,1),'native completed manual stair entrance')
    require(states[26][4:]==(4,0,1,1),'native published first-floor room 0 idle manual actor')
    require(states[26][0]>states[19][0]>states[1][0],'native advancing first-floor session ticks')
    for label,name,offset in [('Mac','session-lamp-use-first-floor-room0-a5.bin',75616-0xb292+160),('Amiga','session-native-26-actor.bin',0)]:
        data=(folder/name).read_bytes()
        values=tuple(struct.unpack_from('>h',data,offset+i)[0] for i in (0,2,0x2e,0x30,0x3e,0x52))
        require(values==(1,12,1,0,4,1),label+' captured Carnby room 0/manual/idle identity')
    require(len((folder/'session-lamp-use-mac-first-floor-room0-rgb.bin').read_bytes())==1228800,'Mac first-floor frame extent')
    pixels=(folder/'session-stairs-native-screen.bin').read_bytes()
    require(len(pixels)==307200 and len(set(pixels))>32,'native first-floor frame population')
    require(len((folder/'session-stairs-native-clut.bin').read_bytes())==2056,'native first-floor palette')
    print('PASS session: lamp pickup/Use/movement, ordinary attic descent, floor 1 room 6→0, manual idle and published scenes')


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('mac',type=Path);p.add_argument('native',type=Path)
    p.add_argument('--mac-status',type=int,required=True);p.add_argument('--native-status',type=int,required=True)
    p.add_argument('--folder',type=Path,default=Path('tmp/m3-explore'))
    a=p.parse_args()
    try:check(a.mac.read_text(),a.native.read_text(),a.folder,a.mac_status,a.native_status)
    except (ValueError,OSError) as error:raise SystemExit('FAIL first-floor session: '+str(error))
