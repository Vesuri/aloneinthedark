#!/usr/bin/env python3
"""Verify ordinary Book Take/Read and return to manual gameplay on Mac/Amiga."""
import argparse
from pathlib import Path
import re
import struct
from check_menu_keyboard import require, rgb
from check_video_transfer import native as display_transfer


def check(mac, native, folder, mac_status, native_status):
    for label,text,status,marker in (
        ('Mac',mac,mac_status,'PASS original book Take, Read and manual gameplay'),
        ('Amiga',native,native_status,'PASS BOOK Take, Read and published manual gameplay')):
        require(status==0 and text.count(marker)==1,label+' actual normal completion')
        require(not re.search(r'FAIL|TIMEOUT|LUA ERROR|Error in|Program received signal',text),label+' no diagnostic failure')
    require(mac.count('Exited via the debugger')==1 and native.count('[Inferior 1 (Remote target) detached]')==1,'both observers completed')
    require(list(map(int,re.findall(r'^LAMP_NATIVE stage=(\d+)',native,re.M)))==list(range(1,16)),'complete lamp pickup prefix')
    require(list(map(int,re.findall(r'^BOOK_NATIVE stage=(\d+)',native,re.M)))==list(range(1,40)),'all 39 book route phases')
    def snapshot(name):
        b=(folder/name).read_bytes();require(len(b)==75616,'captured A5 extent')
        return lambda o:struct.unpack_from('>h',b,75616+o)[0]
    actor=-0xb292+160;book=-0x115f2+12*52;lamp=-0x115f2+13*52
    for label,initial,find,reading,done in (
        ('Mac','book-session-initial-a5.bin','book-session-book-search-a5.bin','book-session-book-reading-a5.bin','book-session-book-read-complete-a5.bin'),
        ('Amiga','book-lamp-native-2-a5.bin','book-native-24-a5.bin','book-native-36-a5.bin','book-native-39-a5.bin')):
        i,f,r,d=map(snapshot,(initial,find,reading,done))
        require(tuple(i(lamp+o) for o in (12,28,30))==(0x609,0,0) and i(-0xd8a6)==1,label+' lamp absent initially')
        for w in (f,r,d):
            require(tuple(w(actor+o) for o in (0,2,0x2e,0x30))==(1,12,0,0),label+' attic Carnby identity')
            require(w(-0xd8a8)==2,label+' ordinary Actions stance')
            require(tuple(w(lamp+o) for o in (12,28,30))==(-31223,-1,-1),label+' taken lamp retained')
            require(-1850<=w(actor+0x1c)<=-1400 and -5000<=w(actor+0x20)<=-2500 and 240<=w(actor+0x2a)<=272,label+' actual bookcase west contact')
        require(tuple(f(book+o) for o in (8,10,12,28,30))==(21,205,0x604,-1,-1),label+' original unplaced Book Find record')
        require(tuple(f(o) for o in (-0xd8a6,-0xd8a4,-0xd8a2))==(2,2,13),label+' book absent before Take')
        for w in (r,d):
            require(tuple(w(o) for o in (-0xd8a6,-0xd8a4,-0xd8a2,-0xd8a0))==(3,2,12,13),label+' actual Book insertion with lamp retained')
            require(tuple(w(book+o) for o in (8,12,28,30))==(21,-31228,-1,-1),label+' taken Book record')
        require(r(book+10)==205 and r(-0xd868)==4,label+' actual Read action before name change')
        require(d(book+10)==550 and d(-0xd868)==0,label+' original Read completion name/result')
        require((d(actor+0x3e),d(actor+0x52))==(4,1),label+' returned idle/manual gameplay')
    pubs={int(s):int(f) for s,f in re.findall(r'^BOOK_NATIVE stage=(\d+).*frames=(\d+)$',native,re.M)}
    require(pubs[27]>pubs[26] and pubs[39]>pubs[38],'later gameplay publications after Take and Read')
    def mac_frame(phase):
        raw=(folder/('book-session-mac-'+phase+'-rgb.bin')).read_bytes();require(len(raw)==1228800,'original frame extent')
        return b''.join(raw[i:i+3][::-1] for i in range(0,len(raw),4))
    transfer=display_transfer()[::256]
    def native_frame(stage):
        p=(folder/('book-native-'+str(stage)+'-screen.bin')).read_bytes()
        c=(folder/('book-native-'+str(stage)+'-clut.bin')).read_bytes()
        require(len(p)==307200 and len(c)==2056 and len(set(p))>16,'populated native frame/palette')
        return rgb(p,c,transfer)
    def ink(p):
        return {(x,y) for y in range(192,233) for x in range(208,433) if p[(y*640+x)*3:(y*640+x)*3+3]==b'\xff\xff\xff'}
    expected=ink(mac_frame('book-search'));actual=ink(native_frame(24))
    require(len(expected)>50 and any(actual=={(x,y+dy) for x,y in expected} for dy in range(-4,5)),'exact original You Find / A Book title')
    # Compare all 320x200 reading pixels except the blinking arrow.
    def page(p):
        return b''.join(p[(y*640+x)*3:(y*640+x)*3+3]
            for y in range(150,350) for x in range(160,480)
            if not (420<=x<445 and y>=330))
    require(page(mac_frame('book-reading'))==page(native_frame(36)),'original first reading page artwork and text')
    require(ink(native_frame(39))!=actual,'Find dismissed in final gameplay')
    print('PASS book: ordinary west contact, actual Take/Read, original reading page, retained inventory and published manual gameplay')


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('mac',type=Path);p.add_argument('native',type=Path)
    p.add_argument('--mac-status',type=int,required=True);p.add_argument('--native-status',type=int,required=True)
    p.add_argument('--folder',type=Path,default=Path('tmp/m3-explore'))
    a=p.parse_args()
    try:check(a.mac.read_text(),a.native.read_text(),a.folder,a.mac_status,a.native_status)
    except (ValueError,OSError) as error:raise SystemExit('FAIL book: '+str(error))
