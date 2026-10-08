#!/usr/bin/env python3
"""Verify all four Book reading pages, backwards navigation and final Return."""
import argparse
from pathlib import Path
import re
import struct
from check_menu_keyboard import require, rgb
from check_video_transfer import native as display_transfer
from check_book_route import check as check_prefix


def check(mac,native,folder,mac_status,native_status):
    marker='PASS original book forward/backward pages, last-page Return and manual gameplay'
    require(mac_status==0 and mac.count(marker)==1,'actual original complete reading exit')
    require(native_status==0 and native.count('PASS BOOK PAGES forward/backward pages and last-page Return')==1,'actual native complete reading exit')
    # Retain all Take/Read/manual-gameplay and first-page pixel checks.
    check_prefix(mac.replace(marker,'PASS original book Take, Read and manual gameplay'),native,folder,mac_status,native_status)
    source=re.findall(r'^BOOK_PAGE visit=(\d+) page=(\d+) last=(true|false) tick=(\d+)$',mac,re.M)
    expected=[0,1,0,1,2,3]
    require([int(r[0]) for r in source]==list(range(1,7)) and [int(r[1]) for r in source]==expected,'original forward/backward page sequence')
    require([r[2] for r in source]==['false']*5+['true'],'original last-page flags')
    rows=re.findall(r'^BOOK_PAGE_NATIVE stage=(\d+) page=(\d+) last=(\d+) tick=(\d+) action=(-?\d+)$',native,re.M)
    require([int(r[0]) for r in rows]==list(range(1,20)),'all 19 native reading phases')
    visits={int(r[0]):tuple(map(int,r[1:])) for r in rows}
    labels=['book-reading','book-page1','book-previous-page','book-forward-1','book-forward-2','book-forward-3']
    stages=[1,4,7,10,13,16]
    transfer=display_transfer()[::256]
    def page(p):
        # Capture a paired arrow phase too: no viewport pixels are excluded.
        return b''.join(p[(y*640+160)*3:(y*640+480)*3] for y in range(150,350))
    for index,stage,label in zip(expected,stages,labels):
        require(visits[stage][0:2]==(index,int(index==3)) and visits[stage][3]==4,'actual native page/last/Read state')
        raw=(folder/('book-session-mac-'+label+'-rgb.bin')).read_bytes();require(len(raw)==1228800,'original page extent')
        source_rgb=b''.join(raw[i:i+3][::-1] for i in range(0,len(raw),4))
        pixels=(folder/('book-page-native-'+str(stage)+'-screen.bin')).read_bytes()
        clut=(folder/('book-page-native-'+str(stage)+'-clut.bin')).read_bytes()
        require(len(pixels)==307200 and len(clut)==2056,'native page/palette extents')
        require(page(source_rgb)==page(rgb(pixels,clut,transfer)),'exact original reading artwork/text for '+label)
        data=(folder/('book-page-native-'+str(stage)+'-a5.bin')).read_bytes();require(len(data)==75616,'native reading A5 extent')
        w=lambda o:struct.unpack_from('>h',data,75616+o)[0]
        require(tuple(w(o) for o in (-0xd8a6,-0xd8a4,-0xd8a2,-0xd8a0,-0xd8a8,-0xd868))==(3,2,12,13,2,4),'inventory/stance/Read retained across pages')
    require(visits[19][3]==0,'native normal reading completion')
    print('PASS complete Book: pages 0,1,0,1,2,3, original full-page artwork/text and last-page Return to gameplay')


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('mac',type=Path);p.add_argument('native',type=Path)
    p.add_argument('--mac-status',type=int,required=True);p.add_argument('--native-status',type=int,required=True)
    p.add_argument('--folder',type=Path,default=Path('tmp/m3-explore'))
    a=p.parse_args()
    try:check(a.mac.read_text(),a.native.read_text(),a.folder,a.mac_status,a.native_status)
    except (ValueError,OSError) as error:raise SystemExit('FAIL book pages: '+str(error))
