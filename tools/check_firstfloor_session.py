#!/usr/bin/env python3
"""Verify a paired lamp-to-first-floor session; this is not the ten-minute gate."""
import argparse
from pathlib import Path
import re
import struct
from check_menu_keyboard import require
from check_lamp_use import check as check_use


def check(mac,native,folder,mac_status,native_status,hallway=False,key=False):
    hallway=hallway or key
    prefix="key-session-" if key else ("hallway-session-" if hallway else "session-")
    check_use(mac,native,folder,mac_status,native_status,session="key" if key else ("hallway" if hallway else True))
    rows=re.findall(r'^EXPLORE_NATIVE stage=(\d+) tick=(\d+) x=(-?\d+) z=(-?\d+) beta=(-?\d+) anim=(-?\d+) room=(-?\d+) floor=(-?\d+) track=(-?\d+)$',native,re.M)
    require([int(r[0]) for r in rows]==list(range(1,65 if key else (40 if hallway else 27))),'native stair/passage input phases')
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
    if key:
        require(-350<=states[20][1]<=32 and (states[20][3]<=16 or states[20][3]>=1008),'native stair exit position/heading')
        require(3920<=states[11][2]<=4070 and 2720<=states[29][2]<=2900 and 2720<=states[42][1]<=2900,'native passage alignment margins')
        for phase,coordinate,low,high in [('east-opening',3,3920,4070),('room0-west',3,2720,2900),('hallway-north',2,2720,2900)]:
            row=re.search(r'^EXPLORE phase='+phase+r' tick=(\d+) x=(-?\d+) z=(-?\d+)',mac,re.M)
            require(row is not None and low<=int(row[coordinate])<=high,'Mac aligned '+phase)
        aligns=re.findall(r'^ALIGN_NATIVE stage=(\d+) state=(\d+) tick=(\d+) x=(-?\d+) z=(-?\d+) anim=(-?\d+)$',native,re.M)
        require(len(aligns)%3==0,'complete native consumed alignment steps')
        for index in range(0,len(aligns),3):
            start,release,end=[tuple(map(int,row)) for row in aligns[index:index+3]]
            require(start[0] in (10,19,28,41) and start[0]==release[0]==end[0],'same alignment waypoint')
            require((start[1],release[1],end[1]) in ((1,2,0),(3,4,0)) and start[5]==end[5]==4,'press/release/idle alignment states')
            require(release[5]==(256 if start[1]==1 else 254) and start[2]<release[2]<end[2],'actual consumed walking animation and time')
            axis=4 if start[0] in (10,28) else 3
            increases=(start[1]==3)==(start[0] in (10,19))
            require((end[axis]>start[axis]) if increases else (end[axis]<start[axis]),'actual correction movement direction')
        pub={int(s):int(f) for s,f in re.findall(r'^KEY_PUBLICATION stage=(\d+) frames=(\d+)$',native,re.M)}
        require(pub[64]>pub[63],'native scene publication after actual key Take')
        for label,before,after in [('Mac',prefix+'lamp-use-key-desk-approach-a5.bin',prefix+'lamp-use-bedroom-key-taken-a5.bin'),('Amiga',prefix+'native-57-a5.bin',prefix+'native-64-a5.bin')]:
            snapshots=[]
            for name in (before,after):
                data=(folder/name).read_bytes();require(len(data)==75616,label+' key A5 extent')
                def w(offset):return struct.unpack_from('>h',data,75616+offset)[0]
                obj=-0x115f2+37*52
                require((w(obj+8),w(obj+10))==(46,209),label+' original key artwork/name identity')
                snapshots.append((w(obj+12)&65535,w(-0xd8a6),w(-0xd8a4),w(-0xd8a2),w(-0xd8a0)))
            require(snapshots[0][:4]==(0x601,2,2,13) and snapshots[1]==(0x8601,3,2,37,13),label+' key inventory insertion retains lamp')
            actor=-0xb292+160
            require(tuple(w(actor+i) for i in (0,2,0x2e,0x30,0x3e,0x52))==(1,12,1,2,4,1),label+' key pickup room/manual identity')
            require(w(actor+0x1c)<=-500 and w(actor+0x20)<=-1000,label+' real desk approach')
        print('PASS bedroom key: ordinary room 1→2 and Search/Take, inventory 2→3 with key 37 and lamp retained, published manual gameplay')
    print('PASS session: lamp pickup/Use/movement, ordinary attic descent, floor 1 room 6→0, manual idle and published scenes')


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('mac',type=Path);p.add_argument('native',type=Path)
    p.add_argument('--mac-status',type=int,required=True);p.add_argument('--native-status',type=int,required=True)
    p.add_argument('--folder',type=Path,default=Path('tmp/m3-explore'))
    p.add_argument('--hallway',action='store_true')
    p.add_argument('--key',action='store_true')
    a=p.parse_args()
    try:check(a.mac.read_text(),a.native.read_text(),a.folder,a.mac_status,a.native_status,a.hallway,a.key)
    except (ValueError,OSError) as error:raise SystemExit('FAIL first-floor session: '+str(error))
