#!/usr/bin/env python3
"""Verify the paired cabinet key Use, saber Take and equipped gameplay route."""
import argparse
from pathlib import Path
import re
import struct
from check_menu_keyboard import require, rgb
from check_video_transfer import native as display_transfer
from check_firstfloor_session import check as check_prefix


def check(mac, native, folder, mac_status, native_status):
    for label, text, status, marker in [
        ('Mac', mac, mac_status, 'PASS original cabinet unlock, saber Take and Use'),
        ('Amiga', native, native_status, 'PASS SABER SESSION cabinet unlock, saber Take and Use')]:
        require(status == 0 and text.count(marker) == 1, label + ' normal saber completion')
        require(not re.search(r'FAIL|TIMEOUT|LUA ERROR|Error in|Program received signal', text), label + ' no diagnostic failure')
    # The maintained key prefix is preserved and independently checked, including
    # its captures. Filter only the additional exploration rows for that checker.
    prefix_end = mac.index('PASS original lamp Use, hallway and bedroom key pickup')
    mac_prefix = mac[:prefix_end] + '\n'.join(line for line in mac[prefix_end:].splitlines()
        if not line.startswith('EXPLORE phase='))
    native_prefix = '\n'.join(line for line in native.splitlines()
        if not (line.startswith(('EXPLORE_NATIVE stage=', 'ALIGN_NATIVE stage=')) and int(re.search(r'stage=(\d+)', line)[1]) > 64))
    check_prefix(mac_prefix, native_prefix, folder, mac_status, native_status, key=True)
    stages = [int(s) for s in re.findall(r'^EXPLORE_NATIVE stage=(\d+)', native, re.M)]
    require(stages == list(range(1, 99)), 'all 98 native route phases')
    approach = re.search(r'^EXPLORE_NATIVE stage=73 tick=\d+ x=-?\d+ z=(-?\d+)', native, re.M)
    require(approach is not None and 1200 <= int(approach[1]) <= 1380, 'native cabinet approach alignment')
    original = re.search(r'^EXPLORE phase=cabinet-east tick=\d+ x=-?\d+ z=(-?\d+)', mac, re.M)
    require(original is not None and 1200 <= int(original[1]) <= 1380, 'original cabinet approach alignment')
    def snapshot(name):
        data = (folder / name).read_bytes()
        require(len(data) == 75616, 'captured A5 extent')
        return lambda offset: struct.unpack_from('>h', data, 75616 + offset)[0]
    for label, before, used, taken, equipped in [
        ('Mac', 'key-session-lamp-use-cabinet-in-range-a5.bin', 'key-session-lamp-use-key-used-a5.bin',
         'key-session-lamp-use-saber-taken-a5.bin', 'key-session-lamp-use-saber-used-a5.bin'),
        ('Amiga', 'key-session-native-77-a5.bin', 'key-session-native-85-a5.bin',
         'key-session-native-89-a5.bin', 'key-session-native-98-a5.bin')]:
        actor = -0xb292 + 160
        b, u, t, e = map(snapshot, (before, used, taken, equipped))
        obj = -0x115f2 + 38 * 52
        require((b(obj+8), b(obj+10), b(obj+12)&65535) == (40, 208, 0x601), label + ' original saber record')
        require((b(-0xd8a6), b(-0xd8a4), b(-0xd8a2), b(-0xd8a0)) == (3, 2, 37, 13), label + ' inventory before unlock')
        require(1640<=b(actor+0x1c)<=1680 and b(actor+0x20)>=1200, label + ' actual cabinet approach')
        furniture=-0xb292+5*160
        require((b(furniture),b(furniture+2),b(furniture+0x1c),b(furniture+0x20)) == (32,33,-800,-570), label + ' approach leaves movable furniture in place')
        require((u(-0xd8a8),u(actor+2)) == (37,12), label + ' key Use selected actual key')
        for phase,w in [('taken',t),('equipped',e)]:
            require(tuple(w(i) for i in (-0xd8a6,-0xd8a4,-0xd8a2,-0xd8a0,-0xd89e)) == (4,2,38,37,13), label + ' saber inserted; key/lamp retained ' + phase)
            require(w(obj+12)&65535 == 0x8601 and w(-0x115f2+37*52+12)&65535 == 0x8601, label + ' taken flags ' + phase)
            require(tuple(w(actor+i) for i in (0,0x2e,0x30,0x3e,0x52)) == (1,1,2,4,1), label + ' manual bedroom gameplay ' + phase)
        require((e(actor+2),e(-0xd8a8)) == (44,38), label + ' equipped saber body and in-hand object')
    retries=re.findall(r'^SABER_ACTION attempt=(\d+) tick=(\d+) x=(-?\d+) z=(-?\d+) anim=(-?\d+) track=(-?\d+)$',native,re.M)
    require([int(r[0]) for r in retries]==list(range(2,2+len(retries))), 'ordered ordinary cabinet retries')
    require(all(tuple(map(int,r[4:]))==(4,1) for r in retries),'retries only from actual manual idle gameplay')
    publication = {int(s):int(f) for s,f in re.findall(r'^KEY_PUBLICATION stage=(\d+) frames=(\d+)',native,re.M)}
    require(publication[89]>publication[88] and publication[98]>publication[97], 'later native gameplay publication after Take and Use')
    original_raw=(folder/'key-session-lamp-use-mac-saber-find-painted-rgb.bin').read_bytes()
    require(len(original_raw) == 1228800, 'original painted Find capture')
    original_rgb=b''.join(original_raw[i:i+3][::-1] for i in range(0,len(original_raw),4))
    native_rgb=rgb((folder/'saber-find-native-screen.bin').read_bytes(),(folder/'saber-find-native-clut.bin').read_bytes(),display_transfer()[::256])
    def title_ink(pixels):
        return {(x,y) for y in range(192,233) for x in range(208,433)
                if pixels[(y*640+x)*3:(y*640+x)*3+3] == b'\xff\xff\xff'}
    expected=title_ink(original_rgb);actual=title_ink(native_rgb)
    require(len(expected)>50 and any(actual=={(x,y+dy) for x,y in expected} for dy in range(-4,5)),
            'native exact You Find / An Old Cavalry Saber text and horizontal placement')
    for label,name in [('Mac','key-session-lamp-use-saber-find-painted-a5.bin'),('Amiga','key-session-native-87-a5.bin')]:
        w=snapshot(name)
        require(w(-0xd864)==0 and w(-0xb292+160+0x52)==0 and w(-0xd8a6)==3,
                label+' actual Find state before Take')
    for phase in ('find','equipped'):
        pixels = (folder / ('saber-'+phase+'-native-screen.bin')).read_bytes()
        require(len(pixels)==307200 and len(set(pixels))>32, 'native '+phase+' frame population')
        require(len((folder/('saber-'+phase+'-native-clut.bin')).read_bytes())==2056, 'native '+phase+' palette extent')
    print('PASS saber: key Use unlocks cabinet, Take inserts saber 38 and retains key/lamp, Use equips body 44 with published manual gameplay')


if __name__ == '__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('mac',type=Path);p.add_argument('native',type=Path)
    p.add_argument('--mac-status',type=int,required=True);p.add_argument('--native-status',type=int,required=True)
    p.add_argument('--folder',type=Path,default=Path('tmp/m3-explore'))
    a=p.parse_args()
    try:check(a.mac.read_text(),a.native.read_text(),a.folder,a.mac_status,a.native_status)
    except (ValueError,OSError) as error:raise SystemExit('FAIL saber route: '+str(error))
