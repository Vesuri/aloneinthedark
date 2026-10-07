#!/usr/bin/env python3
"""Validate and snapshot private original effect references before an audio run."""
import argparse
from pathlib import Path
import shutil
from check_effect_packet import check as packet
from check_effect_loop_action import check as action
from check_effect_slots import check as slots
ROOT=Path(__file__).resolve().parents[1]

def prepare(destination):
    for mode in ('loop0','loop1','loop3','loopnegative','long','fraction','action17','action18','slots'):
        source=ROOT/'tmp/m4/effects'/mode
        status=int((source/'exit-status').read_text().strip())
        checker=action if mode.startswith('action') else slots if mode=='slots' else packet
        checker(source,status)
        target=destination/mode;target.mkdir(parents=True,exist_ok=False)
        for path in source.iterdir():
            if path.name in ('mac.log','exit-status') or (path.suffix=='.bin' and not path.name.startswith('native-')):
                shutil.copy2(path,target/path.name)
    source=ROOT/'tmp/m4/sysbeep'
    if int((source/'mac-exit-status').read_text().strip()):raise ValueError('original SysBeep process status')
    text=(source/'mac.log').read_text()
    if text.count('PASS original isolated SysBeep duration 1')!=1 or text.count('Exited via the debugger')!=1 or any(v in text for v in ('FAIL','LUA ERROR','Error in')):
        raise ValueError('original SysBeep normal completion; full paired ABI checked after native run')
    target=destination/'sysbeep';target.mkdir(parents=True,exist_ok=False)
    for name in ('mac.log','mac-exit-status'):shutil.copy2(source/name,target/name)
    print('PASS audio reference preparation: original effect contracts and recorded statuses; private snapshots retained')

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('destination',type=Path);a=p.parse_args()
    try:prepare(a.destination)
    except (ValueError,OSError) as e:p.exit(1,f'FAIL audio references: {e}\n')
