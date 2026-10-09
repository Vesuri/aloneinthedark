#!/usr/bin/env python3
"""Require ordinary attic descent, published storeroom, and measured guest FPS."""
import argparse
import os
from pathlib import Path
import re
import struct
from check_menu_keyboard import require


def check(text, status, folder):
    rates = [tuple(map(int, row)) for row in re.findall(
        r'^STAIRS_RATE stage=(\d+) tick=(\d+) frames=(\d+) fields=(\d+)$', text, re.M)]
    # Print measured progress even if the original stair track fails.
    if rates:
        start = next((r for r in rates if r[0] == 17), rates[0])
        end = rates[-1]
        if end[1] > start[1]:
            print(f'STAIRS timing: stages {start[0]}→{end[0]}, '
                  f'{end[2]-start[2]} frames / {end[1]-start[1]} guest ticks, '
                  f'{60*(end[2]-start[2])/(end[1]-start[1]):.3f} FPS')
    require(status == 0, f'runner exit {status}')
    require(not re.search(r'FAIL|TIMEOUT|Error in|Program received signal', text), 'observer failure')
    require(text.count('PASS EXPLORE reached published first floor through ordinary keys') == 1
            and text.count('[Inferior 1 (Remote target) detached]') == 1, 'positive completion')
    require([r[0] for r in rates] == list(range(1,20)), 'all nineteen route phases')
    require(all(b[1] > a[1] and b[2] >= a[2] for a,b in zip(rates,rates[1:])), 'advancing guest time and frames')
    choices = re.findall(r"^STAIRS_CHARACTER choice=(\d+)$", text, re.M)
    expected = "1" if os.environ.get("EMILY") == "1" else "0"
    require(choices == [expected]*19, "selected character at every route phase")
    snapshots = []
    for stage in range(1,20):
        data = (folder/f'native-{stage}-actor.bin').read_bytes()
        require(len(data) == 160, f'actor extent at {stage}')
        snapshots.append(tuple(struct.unpack_from('>h', data, i)[0]
                               for i in (0,2,28,32,42,46,48,62,82)))
    require(snapshots[0] == (1,12,3231,-1548,0,0,0,4,1), 'fresh attic start')
    require(snapshots[2][3] >= 1000 and snapshots[6][2] >= 4100
            and snapshots[10][3] >= 3600 and snapshots[14][2] >= 6650,
            'actual approach through stair opening')
    for stage in range(1,18,2):
        require(snapshots[stage-1][5:] == (0,0,4,1), f'released attic waypoint {stage}')
    final = snapshots[-1]
    require(final[:2] == (1,12) and final[5:] == (1,6,4,1), 'living manual storeroom actor')
    require(rates[-1][2] > rates[-2][2], 'new scene after transition')
    pixels = (folder/'stairs-native-screen.bin').read_bytes()
    require(len(pixels) == 307200 and len(set(pixels)) > 32, 'rendered destination')
    require(len((folder/'stairs-native-clut.bin').read_bytes()) == 2056, 'destination palette')
    print('PASS stairs regression: ordinary attic route, floor 0→1, room 6, released manual actor and published destination')


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('log', type=Path)
    p.add_argument('--status', type=int, required=True)
    p.add_argument('--folder', type=Path, default=Path('../tmp/stairs-regression'))
    a = p.parse_args()
    try:
        check(a.log.read_text(), a.status, a.folder)
    except (ValueError, OSError) as error:
        raise SystemExit('FAIL stairs regression: '+str(error))
