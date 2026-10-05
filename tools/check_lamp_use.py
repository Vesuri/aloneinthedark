#!/usr/bin/env python3
"""Require empty-lamp Use to execute and return to manual gameplay on both ports."""
import argparse
from pathlib import Path
import re
import struct
from check_menu_keyboard import require, rgb, glyph_mask
from check_video_transfer import native as display_transfer


def check(mac,native,folder,mac_status,native_status,session=False):
    def capture(name):
        if session:name='session-'+name.replace('-lamp-use-complete','-session-lamp-use-complete')
        return folder/name
    mac_marker='PASS original lamp Use, attic descent and first-floor room 0' if session else 'PASS original empty lamp Use returned gameplay'
    native_marker='PASS SESSION lamp Use and published first-floor room 0 through ordinary keys' if session else 'PASS LAMP USE selected empty lamp and returned gameplay publication'
    for label,text,status,marker in [('Mac',mac,mac_status,mac_marker),('Amiga',native,native_status,native_marker)]:
        require(status==0 and text.count(marker)==1,label+' normal completion')
        require(not re.search(r'FAIL|TIMEOUT|LUA ERROR|Error in|Program received signal',text),label+' no diagnostic failure')
    require(mac.count('Exited via the debugger')==1 and native.count('[Inferior 1 (Remote target) detached]')==1,'observer completion')
    nr=re.findall(r'^LAMP_NATIVE stage=(\d+) .*anim=(-?\d+) .*frames=(\d+)$',native,re.M)
    require([int(r[0]) for r in nr]==list(range(1,28)),'native complete pickup/use phases')
    require(int(nr[26][2])>int(nr[23][2]),'native publication after Use animation')
    phases=['initial','turned-left','lamp-x','facing-table','lamp-approach','open-mode','search-lamp','taken-lamp','inventory-open','lamp-selected','lamp-actions','lamp-first-action','lamp-feedback','lamp-use-complete']
    if session:phases[-1]='session-lamp-use-complete'
    if session:phases+=['back','east','partition-side','south','stair-opening','east-opening','inside-stairs','north-stairs','first-floor','stair-door-open','first-floor-room0']
    require(re.findall(r'^EXPLORE phase=(\S+)',mac,re.M)==phases,'Mac pickup/menu/Use phase order')
    for label,initial,animation,final in [('Mac','lamp-use-initial-a5.bin','lamp-use-lamp-first-action-a5.bin','lamp-use-lamp-use-complete-a5.bin'),('Amiga','lamp-use-native-2-a5.bin','lamp-use-native-24-a5.bin','lamp-use-native-27-a5.bin')]:
        for phase,name in [('initial',initial),('animation',animation),('final',final)]:
            data=capture(name).read_bytes();require(len(data)==75616,label+' A5 extent')
            def w(offset):return struct.unpack_from('>h',data,75616+offset)[0]
            actor=-0xb292+160;obj=-0x115f2+13*52
            require((w(actor),w(actor+0x2e),w(actor+0x30),w(actor+0x52))==(1,0,0,1),label+' attic actor/manual track')
            if phase=='initial':
                require((w(actor+2),w(-0xd8a6),w(-0xd8a4),w(obj+12))==(12,1,2,0x609),label+' pre-pickup state')
            else:
                require((w(actor+2),w(-0xd8a8),w(-0xd8a6),w(-0xd8a4),w(-0xd8a2),w(obj+12)&65535,w(obj+28),w(obj+30))==(11,13,2,2,13,0x8609,-1,-1),label+' selected lamp retained after Use')
                require(w(actor+0x3e)==287,label+' lamp stance')
            if phase=='final':require(w(actor+0x20)>=-3500,label+' ordinary movement after Use')
    for name in ('lamp-use-mac-lamp-first-action-rgb.bin','lamp-use-mac-lamp-use-complete-rgb.bin'):
        require(len(capture(name).read_bytes())==1228800,'Mac frame extent')
    for name in ('lamp-use-feedback','lamp-use-native'):
        pixels=capture(name+'-screen.bin').read_bytes()
        require(len(pixels)==307200 and len(set(pixels))>32,'native feedback/returned frame')
        require(len(capture(name+'-clut.bin').read_bytes())==2056,'native palette extent')
    raw=capture('lamp-use-mac-lamp-first-action-rgb.bin').read_bytes()
    original=b''.join(raw[i:i+3][::-1] for i in range(0,len(raw),4))
    foreground=max((original[(y*640+x)*3:(y*640+x)*3+3] for y in range(330,348) for x in range(260,380)),key=sum)
    expected=glyph_mask(b'The lamp has no oil')
    def bands(pixels):
        points={(x,y) for y in range(310,350) for x in range(260,380) if pixels[(y*640+x)*3:(y*640+x)*3+3]==foreground}
        rows=[]
        for y in sorted({y for x,y in points}):
            if not rows or y>rows[-1][-1]+1:rows.append([y])
            else:rows[-1].append(y)
        result=[]
        for group in rows:
            ink={(x,y) for x,y in points if y in group};left=min(x for x,y in ink);top=min(group)
            result.append((frozenset((x-left,y-top) for x,y in ink),left))
        return result
    mac_message=[band for band in bands(original) if band[0]==expected]
    require(len(mac_message)==1,'original exact empty-lamp feedback glyphs')
    native_rgb=rgb(capture('lamp-use-feedback-screen.bin').read_bytes(),capture('lamp-use-feedback-clut.bin').read_bytes(),display_transfer()[::256])
    require(mac_message[0] in bands(native_rgb),'native exact empty-lamp feedback glyphs, colour and centring')
    print('PASS empty lamp Use: original inventory selection, body 11/animation 287, retained lamp, movement and manual lamp stance and later native publication')


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('mac',type=Path);p.add_argument('native',type=Path)
    p.add_argument('--mac-status',type=int,required=True);p.add_argument('--native-status',type=int,required=True)
    p.add_argument('--folder',type=Path,default=Path('tmp/m3-explore'))
    a=p.parse_args()
    try:check(a.mac.read_text(),a.native.read_text(),a.folder,a.mac_status,a.native_status)
    except (ValueError,OSError) as error:raise SystemExit('FAIL lamp Use: '+str(error))
