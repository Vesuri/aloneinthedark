#!/usr/bin/env python3
"""Verify complete state-matched Actions previews and ordinary-cost timing."""
import argparse
import re
from pathlib import Path
from check_menu_keyboard import rgb, display_transfer, require

def check(reference, native, folder, reference_status, native_status):
    records=[]
    for name, text, status in (("Mac",reference,reference_status),("Amiga",native,native_status)):
        require(status==0 and text.count("PASS action timing")==1, name+" normal completion")
        require(not re.search(r"^FAIL|TIMEOUT|Error in|Program received signal",text,re.M),name+" failure")
        sequence=[tuple(map(int,m)) for m in re.findall(r"ACTION_PREVIEW n=(\d+) tick=(\d+) angle=(-?\d+) actor=(\d+)",text)]
        require(len(sequence)==21,name+" positive preview coverage")
        require([(n,angle,actor) for n,tick,angle,actor in sequence]==[(i+1,-8*i,2) for i in range(21)],name+" same actor/rotation")
        elapsed=int(re.search(r"PASS action timing elapsed=(\d+)",text)[1])
        require(elapsed==sequence[-1][1]-sequence[0][1] and elapsed>0,name+" tick accounting")
        records.append(elapsed)
    mac=(folder/"mac-menu-rgb.bin").read_bytes()
    native_rgb=rgb((folder/"native-menu-screen.bin").read_bytes(),(folder/"native-menu-clut.bin").read_bytes(),display_transfer()[::256])
    require(len(mac)==len(native_rgb)==640*480*3,"frame extents")
    different=sum(mac[(y*640+x)*3:(y*640+x)*3+3]!=native_rgb[(y*640+x)*3:(y*640+x)*3+3] for y in range(150,350) for x in range(160,480))
    require(different==0,f"complete Actions viewport: {different} differing pixels")
    print(f"PASS action menu: 64000 exact viewport pixels; same actor and 21 rotations; Mac={records[0]} ticks Amiga={records[1]} ticks")

if __name__=="__main__":
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--reference",type=Path,required=True)
    parser.add_argument("--native",type=Path,required=True)
    parser.add_argument("--folder",type=Path,default=Path("tmp/m3-action"))
    parser.add_argument("--reference-status",type=int,required=True)
    parser.add_argument("--native-status",type=int,required=True)
    args=parser.parse_args()
    check(args.reference.read_text(),args.native.read_text(),args.folder,args.reference_status,args.native_status)
