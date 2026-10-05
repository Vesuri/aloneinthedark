#!/usr/bin/env python3
"""Verify a paired lamp-to-first-floor session; this is not the ten-minute gate."""
import argparse
from pathlib import Path
import re
import struct
from check_menu_keyboard import require
from check_lamp_use import check as check_use


def check(mac,native,folder,mac_status,native_status,hallway=False):
    prefix="hallway-session-" if hallway else "session-"
    check_use(mac,native,folder,mac_status,native_status,session="hallway" if hallway else True)
    rows=re.findall(r'^EXPLORE_NATIVE stage=(\d+) tick=(\d+) x=(-?\d+) z=(-?\d+) beta=(-?\d+) anim=(-?\d+) room=(-?\d+) floor=(-?\d+) track=(-?\d+)$',native,re.M)
    require([int(r[0]) for r in rows]==list(range(1,40 if hallway else 27)),'native stair/passage input phases')
    states={int(r[0]):tuple(map(int,r[1:])) for r in rows}
    require(states[1][1]>=3600 and states[1][2]>=-3500 and states[1][4:]==((4 if hallway else 287),0,0,1),'native exploration starts after actual lamp Use movement')
    require(states[3][2]>=1000 and states[7][1]>=4100 and states[11][2]>=3600 and states[15][1]>=6650,'native actual attic waypoints')
    require(states[19][5:]==(6,1,1),'native completed manual stair entrance')
    require(states[26][4:]==(4,0,1,1),'native published first-floor room 0 idle manual actor')
    require(states[26][0]>states[19][0]>states[1][0],'native advancing first-floor session ticks')
    for label,name,offset in [('Mac',prefix+'lamp-use-first-floor-room0-a5.bin',75616-0xb292+160),('Amiga',prefix+'native-26-actor.bin',0)]:
        data=(folder/name).read_bytes()
        values=tuple(struct.unpack_from('>h',data,offset+i)[0] for i in (0,2,0x2e,0x30,0x3e,0x52))
        require(values==(1,12,1,0,4,1),label+' captured Carnby room 0/manual/idle identity')
    require(len((folder/(prefix+'lamp-use-mac-first-floor-room0-rgb.bin')).read_bytes())==1228800,'Mac first-floor frame extent')
    pixels=(folder/(prefix+'stairs-native-screen.bin')).read_bytes()
    require(len(pixels)==307200 and len(set(pixels))>32,'native first-floor frame population')
    require(len((folder/(prefix+'stairs-native-clut.bin')).read_bytes())==2056,'native first-floor palette')
    if hallway:
        require(states[39][4:]==(4,1,1,1),'native final hallway idle manual control')
        for label,before,after in [('Mac',prefix+'lamp-use-room0-west-approach-a5.bin',prefix+'lamp-use-first-floor-hallway-a5.bin'),('Amiga',prefix+'native-32-a5.bin',prefix+'native-39-a5.bin')]:
            values=[]
            for name in (before,after):
                data=(folder/name).read_bytes();require(len(data)==75616,label+' hallway A5 extent')
                actor=75616-0xb292
                values.append(tuple(struct.unpack_from('>h',data,actor+i)[0] for i in (0,2,0x2a,0x2e,0x30)))
            require(values[0]==(22,25,256,1,0),label+' original closed room-0 door actor')
            require(values[1][:2]==(22,25) and values[1][2]>=480 and values[1][3:]==(1,0),label+' rotated door actor after Open/Search')
            hero=75616-0xb292+160
            require(tuple(struct.unpack_from('>h',data,hero+i)[0] for i in (0,2,0x2e,0x30,0x3e,0x52))==(1,12,1,1,4,1),label+' published hallway/manual identity')
        print('PASS hallway: original door actor 22 rotated, actual room 0→1, released controls and manual idle')
    print('PASS session: lamp pickup/Use/movement, ordinary attic descent, floor 1 room 6→0, manual idle and published scenes')


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('mac',type=Path);p.add_argument('native',type=Path)
    p.add_argument('--mac-status',type=int,required=True);p.add_argument('--native-status',type=int,required=True)
    p.add_argument('--folder',type=Path,default=Path('tmp/m3-explore'))
    p.add_argument('--hallway',action='store_true')
    a=p.parse_args()
    try:check(a.mac.read_text(),a.native.read_text(),a.folder,a.mac_status,a.native_status,a.hallway)
    except (ValueError,OSError) as error:raise SystemExit('FAIL first-floor session: '+str(error))
