#!/usr/bin/env python3
"""Pair native living room-four recovery captures with the original route."""
import argparse
from pathlib import Path
import re
import struct
from check_menu_keyboard import require
from check_room4_recovery import check as check_original


def records(log, name):
    return [{k: int(v) for k, v in re.findall(r'(\w+)=(-?\d+)', line)}
            for line in log.splitlines() if line.startswith(name + ' ')]


def snapshot(folder, prefix):
    data = (folder / (prefix + '-a5.bin')).read_bytes()
    raw = (folder / (prefix + '-vars.bin')).read_bytes()
    require(len(data) == 75616 and len(raw) == 400, 'complete native world/variables ' + prefix)
    return lambda offset: struct.unpack_from('>h', data, 75616 + offset)[0], struct.unpack('>200h', raw)


def identity(word, values, room):
    hero = -0xb292 + 160
    require(tuple(word(hero + o) for o in (0, 2, 0x2e, 0x30)) == (1, 12, 1, room), 'actual native hero identity')
    require(values[21] > 0 and tuple(word(o) for o in (-0xd8a6, -0xd8a4, -0xd8a2, -0xd8a8)) ==
            (2, 2, 13, 2), 'living hero and retained inventory')


def check(original, original_folder, original_status, native, folder, native_status, require_walk, require_knockback=False):
    check_original(original, original_folder, original_status)
    require(native_status == 0 and native.count('PASS ROOM4 recovery living room4 fight and room5 Search') == 1,
            'normal complete native recovery')
    require(not re.search(r'FAIL|TIMEOUT|Error in|Program received signal', native), 'no native recovery failure')
    rows = records(native, 'ROOM4_RECOVERY')
    phases = {r['stage']: r for r in rows}
    require(rows and rows[-1]['stage'] == 30 and 11 in phases and 12 in phases, 'real room4 transition and completed recovery gates')
    require(all(r['hp'] > 0 and r['body'] == 12 and r['floor'] == 1 and r['drops'] == 0 for r in rows),
            'living identity and no dropped input throughout recovery')
    require(all(a['tick'] <= b['tick'] for a, b in zip(rows, rows[1:])), 'ordered recovery clock')
    for stage in (11, 12, 30):
        row = phases[stage]
        word, values = snapshot(folder, 'recovery-' + str(stage))
        room = 5 if stage == 30 else 4
        identity(word, values, room)
        require(values[21] == row['hp'] and values[57] == row['enemyHp'] and values[90] == row['action'], 'reported captured health/action agree')
        hero = -0xb292 + 160
        require((word(hero + 0x1c), word(hero + 0x20), word(hero + 0x2a)) ==
                (row['x'], row['z'], row['beta']), 'reported captured pose agrees')
        if stage in (11, 12):
            require(values[57] > 0 and 0 <= word(-0x115f2 + 62 * 52) < 50, 'target alive at actual room4 transition')
        if stage in (12, 30):
            require((word(hero + 0x3e), word(hero + 0x52)) == (4, 1), 'actual restored manual control')
        if stage == 12:
            require(values[90] == 16, 'actual room4 Fight')
        if stage == 30:
            require(values[90] == 64 and values[57] <= 0 and
                    tuple(word(-0x115f2 + 62 * 52 + o) for o in (0, 28, 30)) == (-1, -1, -1),
                    'actual room5 Search and completed target removal')
    transition, _ = snapshot(folder, 'recovery-11')
    knockback = transition(-0xb292 + 160 + 0x3e) == 237
    require(knockback or not require_knockback, 'actual hit-animation room4 transition exercised')
    # A return after combat already moved to room5 does not exercise the room4 exit controller.
    require(all(s in phases for s in range(20, 26)), 'ordinary post-combat room4 doorway exit exercised')
    for stage in range(20, 26):
        word, values = snapshot(folder, 'recovery-' + str(stage))
        identity(word, values, phases[stage]['room'])
        require(values[57] <= 0 and word(-0x115f2 + 62 * 52) == -1, 'target remains removed through doorway exit')
    aligned, _ = snapshot(folder, 'recovery-22')
    # Original entry at z=1189 and native hit entry at z=1069 establish this corridor.
    # Actual living room5 below is still mandatory; a coordinate alone cannot pass.
    require(650 <= aligned(-0xb292 + 160 + 0x20) <= 1200, 'released doorway alignment')
    aims = records(native, 'ROOM4_AIM')
    walking = False
    for a, b in zip(aims, aims[1:]):
        if a['room'] != 4 or b['room'] != 4:
            continue
        wa, va = snapshot(folder, 'aim-' + str(a['index']))
        wb, vb = snapshot(folder, 'aim-' + str(b['index']))
        hero = -0xb292 + 160
        def gap(w):
            slot = w(-0x115f2 + 62 * 52)
            require(0 <= slot < 50, 'active target during walking')
            npc = -0xb292 + slot * 160
            nr = w(npc + 0x30)
            require(nr in (4, 5), 'measured target room during walking')
            return max(abs(w(npc + 0x1c) + (4500 if nr == 5 else 0) - w(hero + 0x1c)),
                       abs(w(npc + 0x20) + (100 if nr == 5 else 0) - w(hero + 0x20)))
        if gap(wa) > 800 and gap(wb) <= 800 and wb(hero + 0x3e) == 254:
            identity(wa, va, 4); identity(wb, vb, 4)
            require((wa(hero + 0x1c), wa(hero + 0x20)) != (wb(hero + 0x1c), wb(hero + 0x20)), 'positive ordinary walking displacement')
            walking = True
    require(walking or not require_walk, 'out-of-range ordinary walking recovery exercised')
    require(len((folder / 'final-screen.bin').read_bytes()) == 307200 and
            len(set((folder / 'final-screen.bin').read_bytes())) > 32 and
            len((folder / 'final-clut.bin').read_bytes()) == 2056, 'populated final logical scene and palette')
    print('PASS paired native room4 recovery: actual living room4 transition, Fight, target death/removal, doorway alignment, ordinary exit and room5 Search; out-of-range walking=' + str(walking) + '; hit-animation transition=' + str(knockback))


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('original', type=Path); p.add_argument('native', type=Path)
    p.add_argument('--original-folder', type=Path, required=True); p.add_argument('--folder', type=Path, required=True)
    p.add_argument('--original-status', type=int, required=True); p.add_argument('--native-status', type=int, required=True)
    p.add_argument('--require-walk', action='store_true')
    p.add_argument('--require-knockback', action='store_true')
    a = p.parse_args()
    try:
        check(a.original.read_text(), a.original_folder, a.original_status, a.native.read_text(), a.folder, a.native_status, a.require_walk, a.require_knockback)
    except (ValueError, OSError, KeyError) as error:
        raise SystemExit('FAIL native room4 recovery: ' + str(error))
