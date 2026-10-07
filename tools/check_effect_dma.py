#!/usr/bin/env python3
"""Validate the bounded Paula segment-start interrupt timing probe."""
import argparse
from pathlib import Path
import re

def check(text,status):
    if status or re.search(r'FAIL|TIMEOUT|Error in|Program received signal',text) or text.count('PASS native effect DMA interrupt observation and vector restoration')!=1 or text.count('[Inferior 1 (Remote target) detached]')!=1:
        raise ValueError('normal probe completion and restored vector')
    rows=re.findall(r'^EFFECT_DMA_IRQ n=(\d+) clocks=(\d+) hz=(\d+)$',text,re.M)
    if len(rows)!=4 or [int(r[0]) for r in rows]!=list(range(4)) or {int(r[2]) for r in rows}!={709379}:
        raise ValueError('four PAL interrupt timestamps')
    clocks=[int(r[1]) for r in rows];hz=709379
    if not 0<clocks[0]<hz/1000 or clocks!=sorted(set(clocks)):
        raise ValueError('first interrupt at startup')
    attack=4096*443/3546895
    if abs((clocks[1]-clocks[0])/hz-attack)>.003:
        raise ValueError('next interrupt after the complete attack')
    for before,after in zip(clocks[1:],clocks[2:]):
        if abs((after-before)/hz-2*443/3546895)>.0001:
            raise ValueError('subsequent silent-word reloads')
    if 'PASS native driver17 play-effect ABI and publication' not in text or not re.search(r'^EFFECT_FRACTION period=443 duration=31 elapsed=3[1-6]$',text,re.M):
        raise ValueError('actual effect playback and bounded cleanup')
    print('PASS Paula DMA: startup IRQ, complete 4096-byte attack, two silent-word reloads, native effect cleanup and restored vector/mask')

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('log',type=Path);p.add_argument('--status',type=int,required=True);a=p.parse_args()
    try:check(a.log.read_text(),a.status)
    except (OSError,ValueError) as e:p.exit(1,f'FAIL effect DMA: {e}\n')
