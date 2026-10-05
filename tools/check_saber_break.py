#!/usr/bin/env python3
"""Verify original/native saber attacks, breakage and blade recovery."""
import argparse
from pathlib import Path
import re
import struct
from check_menu_keyboard import require, rgb
from check_video_transfer import native as display_transfer
from check_saber_route import check as check_prefix


def check(mac, native, folder, mac_status, native_status):
    for label, text, status, marker in (
        ('Mac', mac, mac_status, 'PASS original saber attacks, broken blade Take and manual gameplay'),
        ('Amiga', native, native_status, 'PASS SABER BREAK three attack directions, broken blade Take and published manual gameplay')):
        require(status == 0 and text.count(marker) == 1, label + ' normal blade completion')
        require(not re.search(r'FAIL|TIMEOUT|LUA ERROR|Error in|Program received signal', text), label + ' no diagnostic failure')
    prefix_end = mac.index('PASS original cabinet unlock, saber Take and Use')
    mac_prefix = mac[:prefix_end] + '\n'.join(line for line in mac[prefix_end:].splitlines()
        if not line.startswith('EXPLORE phase='))
    native_prefix = '\n'.join(line for line in native.splitlines()
        if not (line.startswith(('EXPLORE_NATIVE stage=', 'ALIGN_NATIVE stage='))
                and int(re.search(r'stage=(\d+)', line)[1]) > 98))
    check_prefix(mac_prefix, native_prefix, folder, mac_status, native_status)
    stages = list(map(int, re.findall(r'^EXPLORE_NATIVE stage=(\d+)', native, re.M)))
    require(stages == list(range(1, 116)), 'all 115 native route phases')
    def snapshot(name):
        data = (folder / name).read_bytes()
        require(len(data) == 75616, 'captured A5 extent')
        return lambda offset: struct.unpack_from('>h', data, 75616 + offset)[0]
    actor = -0xb292 + 160
    saber = -0x115f2 + 38*52
    blade = -0x115f2 + 41*52
    for direction, animation, stage in (('Up', 41, 100), ('Left', 37, 102), ('Right', 39, 104)):
        m = snapshot('key-session-lamp-use-saber-attack-'+direction+'-Arrow-a5.bin')
        n = snapshot('key-session-native-'+str(stage)+'-a5.bin')
        for label,w in (('Mac',m),('Amiga',n)):
            require(w(actor+2) in (44,45) and (w(actor+0x3e),w(-0xd8a8)) == (animation,38), label+' '+direction+' saber attack')
            if w(actor+2)==45:
                require(tuple(w(saber+i) for i in (8,10,12)) == (43,580,-31231), label+' attack with actual broken saber')
    for label,name in (('Mac','key-session-lamp-use-saber-broken-a5.bin'),('Amiga','key-session-native-105-a5.bin')):
        w=snapshot(name)
        require((w(actor+2),w(-0xd8a8)) == (45,38), label+' actual broken-saber body and equipped object')
    for label,find,done in (
        ('Mac', 'key-session-lamp-use-saber-blade-find-a5.bin', 'key-session-lamp-use-saber-blade-complete-a5.bin'),
        ('Amiga', 'key-session-native-113-a5.bin', 'key-session-native-115-a5.bin')):
        f,d = map(snapshot,(find,done))
        for w in (f,d):
            require(tuple(w(saber+i) for i in (8,10,12)) == (43,580,-31231), label+' actual broken saber')
        require(tuple(f(blade+i) for i in (8,10,12,28,30)) == (37,234,0x4600,1,2), label+' actual blade Find')
        require(f(-0xd8a6)==4, label+' blade absent before Take')
        require(tuple(d(blade+i) for i in (8,10,12,28,30)) == (37,234,-31232,-1,-1), label+' blade taken and removed from room')
        require(tuple(d(i) for i in (-0xd8a6,-0xd8a4,-0xd8a2,-0xd8a0,-0xd89e,-0xd89c)) == (5,2,41,38,37,13), label+' recovered blade with saber/key/lamp retained')
        require(tuple(d(actor+i) for i in (0,2,0x2e,0x30,0x3e,0x52)) == (1,12,1,2,4,1) and d(-0xd8a8)==2, label+' manual unarmed bedroom gameplay')
    retries=re.findall(r'^SABER_BREAK_ACTION attempt=(\d+) tick=(\d+) x=(-?\d+) z=(-?\d+) anim=(-?\d+) track=(-?\d+) var37=(-?\d+) var38=(-?\d+) var39=(-?\d+)$', native, re.M)
    require([int(r[0]) for r in retries] == list(range(4,4+len(retries))) and len(retries)<=13, 'bounded ordered ordinary attack retries')
    require(all(tuple(map(int,r[4:6]))==(4,1) for r in retries), 'attack retries start from actual manual idle')
    publication = {int(s):int(f) for s,f in re.findall(r'^KEY_PUBLICATION stage=(\d+) frames=(\d+)',native,re.M)}
    require(publication[115]>publication[114], 'later gameplay publication after blade Take')
    raw = (folder/'key-session-lamp-use-mac-saber-blade-find-rgb.bin').read_bytes()
    require(len(raw)==1228800, 'original blade Find frame extent')
    original = b''.join(raw[i:i+3][::-1] for i in range(0,len(raw),4))
    def native_frame(phase):
        p = (folder/('blade-'+phase+'-native-screen.bin')).read_bytes()
        c = (folder/('blade-'+phase+'-native-clut.bin')).read_bytes()
        require(len(p)==307200 and len(c)==2056 and len(set(p))>(16 if phase=='find' else 32), 'native populated '+phase+' frame')
        return rgb(p,c,display_transfer()[::256])
    found = native_frame('find'); returned = native_frame('taken')
    def ink(p):
        return {(x,y) for y in range(192,233) for x in range(208,433)
                if p[(y*640+x)*3:(y*640+x)*3+3] == b'\xff\xff\xff'}
    expected=ink(original);actual=ink(found)
    require(len(expected)>50 and any(actual=={(x,y+dy) for x,y in expected} for dy in range(-4,5)), 'exact original You Find / A Saber Blade text')
    require(ink(returned)!=actual and returned!=found, 'Find dismissed and gameplay republished')
    print('PASS saber break: three attack directions, actual broken saber, blade Take, retained inventory and published manual gameplay')


if __name__ == '__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('mac',type=Path);p.add_argument('native',type=Path)
    p.add_argument('--mac-status',type=int,required=True);p.add_argument('--native-status',type=int,required=True)
    p.add_argument('--folder',type=Path,default=Path('tmp/m3-explore'))
    a=p.parse_args()
    try:check(a.mac.read_text(),a.native.read_text(),a.folder,a.mac_status,a.native_status)
    except (ValueError,OSError) as error:raise SystemExit('FAIL saber break: '+str(error))
