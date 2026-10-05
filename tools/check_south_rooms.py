#!/usr/bin/env python3
"""Verify paired ordinary entry into the southern first-floor room."""
import argparse
from pathlib import Path
import re
import struct
from check_menu_keyboard import require
from check_firstfloor_session import check as check_prefix


def check(mac, native, folder, mac_status, native_status):
    for label,text,status,marker in (
        ('Mac',mac,mac_status,'PASS original southern first-floor room5 manual gameplay'),
        ('Amiga',native,native_status,'PASS SOUTH ROOM first-floor room5 manual gameplay through ordinary keys')):
        require(status==0 and text.count(marker)==1, label+' normal southern-room completion')
        require(not re.search(r'FAIL|TIMEOUT|LUA ERROR|Error in|Program received signal',text), label+' no diagnostic failure')
    end=mac.index('PASS original lamp Use, stairs and first-floor hallway')
    mac_prefix=mac[:end]+'\n'.join(line for line in mac[end:].splitlines() if not line.startswith('EXPLORE phase='))
    native_prefix='\n'.join(line for line in native.splitlines()
        if not (line.startswith(('EXPLORE_NATIVE stage=','ALIGN_NATIVE stage='))
                and int(re.search(r'stage=(\d+)',line)[1])>39))
    check_prefix(mac_prefix,native_prefix,folder,mac_status,native_status,hallway=True)
    require(list(map(int,re.findall(r'^EXPLORE_NATIVE stage=(\d+)',native,re.M)))==list(range(1,53)), 'all 52 native southern-room phases')
    def snapshot(name):
        b=(folder/name).read_bytes();require(len(b)==75616,'captured A5 extent')
        return lambda o:struct.unpack_from('>h',b,75616+o)[0]
    actor=-0xb292+160
    for label,before,after in (
        ('Mac','hallway-session-lamp-use-room5-door-approach-a5.bin','hallway-session-lamp-use-first-floor-room5-a5.bin'),
        ('Amiga','hallway-session-native-45-a5.bin','hallway-session-native-52-a5.bin')):
        b,d=map(snapshot,(before,after))
        require((b(actor+0x2e),b(actor+0x30))==(1,1),label+' actual hallway approach')
        require(2720<=b(actor+0x1c)<=2900 and 496<=b(actor+0x2a)<=528,label+' southern doorway alignment')
        require(tuple(d(actor+i) for i in (0,2,0x2e,0x30,0x3e,0x52))==(1,12,1,5,4,1),label+' released manual southern-room gameplay')
        require(-2700<=d(actor+0x1c)<=-1700 and -2200<=d(actor+0x20)<=-1300,label+' measured room5 entrance opening')
        for w in (b,d):
            require(tuple(w(i) for i in (-0xd8a6,-0xd8a4,-0xd8a2,-0xd8a8))==(2,2,13,2),label+' inventory and ordinary walking stance retained')
            lamp=-0x115f2+13*52
            require(tuple(w(lamp+i) for i in (12,28,30))==(-31223,-1,-1),label+' taken lamp retained')
    pubs={int(s):int(f) for s,f in re.findall(r'^SOUTH_PUBLICATION stage=(\d+) frames=(\d+)',native,re.M)}
    require(pubs[52]>pubs[51], 'native later room5 gameplay publication')
    require(len((folder/'hallway-session-lamp-use-mac-first-floor-room5-rgb.bin').read_bytes())==1228800,'original room5 frame extent')
    p=(folder/'south-room5-native-screen.bin').read_bytes()
    require(len(p)==307200 and len(set(p))>32,'populated native room5 scene')
    require(len((folder/'south-room5-native-clut.bin').read_bytes())==2056,'native room5 palette extent')
    print('PASS southern room: ordinary hallway approach, actual room1 to room5 transition, retained lamp/inventory and published manual gameplay')


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('mac',type=Path);p.add_argument('native',type=Path)
    p.add_argument('--mac-status',type=int,required=True);p.add_argument('--native-status',type=int,required=True)
    p.add_argument('--folder',type=Path,default=Path('tmp/m3-explore'))
    a=p.parse_args()
    try:check(a.mac.read_text(),a.native.read_text(),a.folder,a.mac_status,a.native_status)
    except (ValueError,OSError) as error:raise SystemExit('FAIL southern rooms: '+str(error))
