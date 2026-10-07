#!/usr/bin/env python3
"""Verify one continuous new-game, recovery, return and first-floor circuit session."""
import argparse
from pathlib import Path
import re
from check_menu_keyboard import require
from check_native_room4_recovery import check as check_recovery, snapshot, records
from check_native_firstfloor_circuit import check as check_circuit


def check(original, original_folder, native, folder, original_status, native_status,
          require_walk=False, require_knockback=False):
    require('DIALOG_STATE checkpoint-load-choice' not in original,
            'original continuous session uses new game rather than checkpoint Load')
    check_recovery(original, original_folder, original_status, native, folder / 'recovery',
                   native_status, require_walk, require_knockback)
    check_circuit(original, original_folder, original_status, native, folder / 'circuit', native_status)
    starts = records(native, 'NEWGAME_NATIVE')
    require(len(starts) == 1, 'one positively captured native new-game start')
    word, values = snapshot(folder / 'recovery', 'newgame')
    hero = -0xb292 + 160
    require(tuple(word(hero + o) for o in (0, 2, 0x2e, 0x30)) == (1, 12, 0, 0)
            and values[21] == 20 and word(-0xd8a6) == 1 and word(-0xd8a4) == 2,
            'actual fresh attic hero, health and initial inventory')
    returns = [r for r in records(native, 'ROOM3_NATIVE') if r['stage'] == 66]
    require(len(returns) == 1, 'one connected bathroom return after recovery')
    returned = returns[0]
    word, values = snapshot(folder / 'recovery', 'native-66')
    require(tuple(word(hero + o) for o in (0, 2, 0x2e, 0x30, 0x3e, 0x52)) == (1, 12, 1, 3, 4, 1)
            and values[21] == returned['health'] > 0 and values[90] == 64 and returned['drops'] == 0,
            'actual living manual bathroom with Search after new-game recovery')
    recovery = records(native, 'ROOM4_RECOVERY')[-1]
    circuit = records(native, 'CIRCUIT_NATIVE')[0]
    require(starts[0]['tick'] < recovery['tick'] <= returned['tick'] <= circuit['tick'],
            'continuous ordered new-game/recovery/bathroom/circuit clock')
    require(returned['frames'] <= circuit['frames'], 'continuous completed scene count')
    print('PASS paired continuous new-game first-floor session: fresh attic, room4 fight/return, bathroom and ten-minute circuit')


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('original', type=Path); p.add_argument('native', type=Path)
    p.add_argument('--original-folder', type=Path, required=True); p.add_argument('--folder', type=Path, required=True)
    p.add_argument('--original-status', type=int, required=True); p.add_argument('--native-status', type=int, required=True)
    p.add_argument('--require-walk', action='store_true'); p.add_argument('--require-knockback', action='store_true')
    a = p.parse_args()
    try:
        check(a.original.read_text(), a.original_folder, a.native.read_text(), a.folder,
              a.original_status, a.native_status, a.require_walk, a.require_knockback)
    except (ValueError, OSError, KeyError) as error:
        raise SystemExit('FAIL new-game first-floor session: ' + str(error))
