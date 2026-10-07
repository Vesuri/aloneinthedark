#!/usr/bin/env python3
"""Inventory direct original calls through the A5-$6AC sound-driver pointer.

Static caller evidence only: this does not prove a branch is reached in gameplay.
"""
import argparse
from collections import defaultdict
from pathlib import Path
from resource_fork import read_resource_fork

ROOT=Path(__file__).resolve().parents[1]
SUPPORTED={0,4,5,6,7,8,13,15,17,18,19,20,21,22,24}


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--resource',type=Path,default=ROOT/'tmp/runtime-data/Alone In The Dark')
    a=p.parse_args();calls=defaultdict(list)
    for r in read_resource_fork(a.resource):
        if r.kind!=b'CODE':continue
        code=r.body
        for at in range(4,len(code)-5,2):
            if code[at:at+6]!=bytes.fromhex('206df9544e90'):continue
            if code[at-2:at]==bytes.fromhex('42a7'):selector=0
            elif code[at-4:at-2]==bytes.fromhex('4878'):selector=int.from_bytes(code[at-2:at],'big')
            else:raise ValueError(f'unknown selector push CODE {r.rid}+${at:X}')
            calls[selector].append(f'{r.rid}+${at+4:04X}')
    if sum(map(len,calls.values()))!=45 or set(calls)!=set(range(26))-{3}:
        raise ValueError('different original wrapper inventory; remeasure before updating expectations')
    print('| Selector | Direct CODE calls (JSR offsets) | Native contract |')
    print('| ---: | --- | --- |')
    for selector,sites in sorted(calls.items()):
        print(f'| {selector} | {", ".join(sites)} | {"Measured subset implemented" if selector in SUPPORTED else "Unmeasured; loud stop"} |')
    print('45 direct wrappers, 25 selector values; static presence is not gameplay reachability.')


if __name__=='__main__':
    try:main()
    except (ValueError,OSError) as error:raise SystemExit('FAIL driver inventory: '+str(error))
