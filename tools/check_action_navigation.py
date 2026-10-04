#!/usr/bin/env python3
"""Compare reached action choices, mouse hover and cancellation with the Mac."""
import argparse,re
from pathlib import Path
from check_menu_keyboard import require,rgb,display_transfer

def check(original,native,folder,original_status,native_status,stem="nav"):
    for name,text,status,marker in (("Mac",original,original_status,"PASS original action navigation returned attic"),("Amiga",native,native_status,"PASS native action navigation down up hover cancel quit")):
        require(status==0 and text.count(marker)==1,name+" normal completion")
        require(not re.search(r"^FAIL|TIMEOUT|Error in|Program received signal",text,re.M),name+" failure")
        require(re.search(r"ACTION_NAV_CANCEL tick=\d+ actions=0 room=0",text),name+" cancel without action, room zero")
    keys=re.findall(r"ACTION_NAV_KEY name=(.*?) tick=(\d+)",original)
    require([name for name,tick in keys]==["Right Arrow","Down Arrow","Up Arrow"],"original key route")
    draws=[(int(t),int(s)) for t,s in re.findall(r"ACTION_NAV_DRAW tick=(\d+) selection=(\d+)",original)]
    latencies=[]
    for (name,tick),wanted in zip(keys,[0,1,0]):
        press=int(tick);following=[t for t,s in draws if t>=press and s==wanted]
        require(following,"original selection positive control: "+name)
        latencies.append(min(following)-press)
    native_draws=[tuple(map(int,m)) for m in re.findall(r"ACTION_NAV_DRAW stage=(\d+) tick=(\d+) selection=(\d+) keyTick=(\d+)",native)]
    native_latencies=[]
    for stage,wanted,reference in zip([1,3,5],[0,1,0],latencies):
        matches=[tick-key for s,tick,selected,key in native_draws if s==stage and selected==wanted]
        require(matches and 0<=min(matches)<=max(2*reference,60),"native key/choice latency")
        native_latencies.append(min(matches))
    require(re.search(r"ACTION_NAV_PREVIEW tick=\d+ selection=0 mouse=4(?:0[0-9]|1[0-9]|20),28[0-9]",original),"original pointer over choices, no selection change")
    require(re.search(r"ACTION_NAV_HOVER tick=\d+ selection=0 mouse=410,285 samples=[1-9]\d*",native),"native VBI pointer sampling and same hover result")
    mac=(folder/f"mac-{stem}-rgb.bin").read_bytes()
    amiga=rgb((folder/f"native-{stem}-screen.bin").read_bytes(),(folder/f"native-{stem}-clut.bin").read_bytes(),display_transfer()[::256])
    require(len(mac)==len(amiga)==640*480*3,"frame extents")
    require(all(mac[(y*640+x)*3:(y*640+x)*3+3]==amiga[(y*640+x)*3:(y*640+x)*3+3] for y in range(250,350) for x in range(320,480)),"16000 exact selected-action pane pixels")
    print(f"PASS action navigation: original/native choices 0/1/0, same hover behavior, cancel executes no action, native quit restores OS/audio/files, exact action pane; key-to-choice ticks Mac={latencies} Amiga={native_latencies}")

if __name__=="__main__":
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("original",type=Path);p.add_argument("native",type=Path)
    p.add_argument("--original-status",type=int,required=True);p.add_argument("--native-status",type=int,required=True)
    p.add_argument("--folder",type=Path,default=Path("tmp/m3-action"));a=p.parse_args()
    try:check(a.original.read_text(),a.native.read_text(),a.folder,a.original_status,a.native_status)
    except (ValueError,OSError) as error:raise SystemExit("FAIL action navigation: "+str(error))
