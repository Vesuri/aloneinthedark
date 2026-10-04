#!/usr/bin/env python3
"""Verify held mouse clicks and cancellation against the original Actions menu."""
import argparse,re
from pathlib import Path
from check_action_navigation import check as navigation
from check_menu_keyboard import require

def check(original,native,folder,original_status,native_status):
    require(re.search(r"ACTION_CLICK_BUTTON tick=\d+ mouse=4(?:0[0-9]|1[0-9]|20),28[0-9] mb=0",original),"Mac held-button trap positive control")
    for label,text in (("Amiga",native),):
        rows=[tuple(map(int,row)) for row in re.findall(
            r"ACTION_CLICK_DOWN tick=(\d+) selection=(-?\d+) mouse=(\d+),(\d+) key=(-?\d+) direction=(-?\d+)",text)]
        require(rows,label+" held-button positive control")
        require(all(selection==0 and 400<=x<=420 and 280<=y<=290 and key==0 and direction==0
                    for tick,selection,x,y,key,direction in rows),label+" click does not change choice or generate a keyboard command")
    pressed=int(re.search(r"ACTION_CLICK tick=(\d+)",original)[1])
    escaped=int(re.search(r"ACTION_NAV_ESCAPE tick=(\d+)",original)[1])
    previews=[(int(t),int(choice)) for t,choice in re.findall(
        r"ACTION_NAV_PREVIEW tick=(\d+) selection=(-?\d+)",original)]
    after=[choice for tick,choice in previews if pressed+120<=tick<escaped]
    require(after and all(choice==0 for choice in after),"Mac post-click unchanged choice")
    navigation(original.replace("PASS original action clicks returned attic","PASS original action navigation returned attic"),
               native.replace("PASS native action clicks down up hover click cancel quit","PASS native action navigation down up hover cancel quit"),
               folder,original_status,native_status,stem="click")
    print("PASS action clicks: sampled held button, unchanged action choice, cancellation and full native shutdown match the original")

if __name__=="__main__":
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("original",type=Path);p.add_argument("native",type=Path)
    p.add_argument("--original-status",type=int,required=True);p.add_argument("--native-status",type=int,required=True)
    p.add_argument("--folder",type=Path,default=Path("tmp/m3-action"));a=p.parse_args()
    try:check(a.original.read_text(),a.native.read_text(),a.folder,a.original_status,a.native_status)
    except (ValueError,OSError) as error:raise SystemExit("FAIL action clicks: "+str(error))
