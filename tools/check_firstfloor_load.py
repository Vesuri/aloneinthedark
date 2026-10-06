#!/usr/bin/env python3
"""Verify ordinary first-floor Load against the fresh original game Load."""
import argparse
from pathlib import Path
import re
import struct
from check_menu_keyboard import require


def check(original, original_actor, original_status, native, prefix, native_status):
    require(original_status == 0 and original.count('PASS original durable firstfloor checkpoint fresh Load') == 1,
            'completed fresh original Load')
    require(native_status == 0 and native.count('PASS native ordinary firstfloor checkpoint Load') == 1,
            'completed native Load')
    require(not re.search(r'FAIL|TIMEOUT|Program received signal', original + native), 'no failed observer')
    # The original actor becomes visible before Load's final block read.
    # Count the completed file-I/O trace, including partial EOF bytes, after
    # choosing the slot. The chooser's preview/header reads are excluded.
    trace = original.split('DIALOG_STATE firstfloor-load-choice', 1)[1]
    pending, refs, reference_bytes, reference_closed = None, {}, 0, False
    for line in trace.splitlines():
        if line.startswith('SAVELOAD_IO_ENTER '):
            pending = dict(re.findall(r'(\w+)=([^ ]*)', line))
            pending['name'] = line.split('name=', 1)[1]
        elif line.startswith('SAVELOAD_IO_RETURN ') and pending:
            result = dict(re.findall(r'(\w+)=([^ ]*)', line))
            ref, error = int(result['ref']), int(result['result'])
            if result['trap'] in ('A000', 'A200', 'A060', 'A260') and error == 0:
                refs[ref] = pending['name']
            if result['trap'] == 'A002' and error in (0, -39) and 'SAVE0.ITD' in refs.get(ref, ''):
                reference_bytes += int(result['actual'])
            if result['trap'] == 'A001':
                if error == 0 and 'SAVE0.ITD' in refs.get(ref, '') and reference_bytes > 10000:
                    reference_closed = True
                refs.pop(ref, None)
            pending = None
    phases = [tuple(map(int, row)) for row in re.findall(
        r'^FIRSTFLOOR_LOAD stage=(\d+) tick=(\d+) frames=(\d+) read=(\d+)$', native, re.M)]
    require(reference_closed and reference_bytes > 10000 and [p[0] for p in phases] == [1, 2, 3, 4, 5], 'ordered ordinary input phases')
    require(all(a[1] < b[1] for a, b in zip(phases, phases[1:])), 'increasing input clock')
    require(phases[-1][3] == reference_bytes > 10000 and phases[-1][2] > phases[0][2],
            'exact original save-read extent and fresh loaded scene')
    read = lambda suffix: Path(str(prefix) + '-' + suffix + '.bin').read_bytes()
    before = read('before-actor')
    require(len(before) == 160 and tuple(struct.unpack_from('>h', before, o)[0]
            for o in (0, 2, 0x2e, 0x30)) == (1, 12, 0, 0), 'fresh attic before Load')
    data, variables = read('a5'), read('vars')
    require(len(data) == 75616 and len(variables) == 400 and len(original_actor) == 160, 'complete records')
    word = lambda offset: struct.unpack_from('>h', data, 75616 + offset)[0]
    hero = -0xb292 + 160
    # Compare stable saved fields; pointers and natural animation phases are not portable.
    fields = (0, 2, 0x1c, 0x1e, 0x20, 0x2a, 0x2e, 0x30, 0x3e, 0x52)
    require(all(word(hero + o) == struct.unpack_from('>h', original_actor, o)[0] for o in fields),
            'loaded actor matches the original fresh Load')
    require(tuple(word(hero + o) for o in (0, 2, 0x2e, 0x30, 0x3e, 0x52)) == (1, 12, 1, 3, 4, 1),
            'actual living manual first-floor identity')
    values = struct.unpack('>200h', variables)
    require(values[21] == 18 and values[90] == 64 and values[20] == 0, 'loaded health, action and encounter counter')
    require(tuple(word(o) for o in (-0xd8a6, -0xd8a4, -0xd8a2, -0xd8a8)) == (2, 2, 13, 2),
            'Actions/lamp inventory and equipment')
    require((word(-0x115f2 + 13*52 + 12) & 0xffff) == 0x8609, 'taken lamp flags')
    require(values[57] <= 0 and tuple(word(-0x115f2 + 62*52 + o) for o in (0, 28, 30)) == (-1, -1, -1),
            'room5 enemy remains removed')
    require(values[40] == 10 and word(-0x115f2 + 35*52) == -1, 'untouched bedroom encounter')
    pixels, colors = read('choice-screen'), read('choice-clut')
    require(len(pixels) == 307200 and len(set(pixels)) > 32 and len(colors) == 2056,
            'populated logical chooser and save preview')
    print(f'PASS paired ordinary first-floor Load: read={phases[-1][3]}; original actor, inventory and encounter state restored')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('original', type=Path)
    parser.add_argument('native', type=Path)
    parser.add_argument('--original-actor', type=Path, required=True)
    parser.add_argument('--original-status', type=int, required=True)
    parser.add_argument('--native-status', type=int, required=True)
    parser.add_argument('--prefix', type=Path, default=Path('tmp/firstfloor-load'))
    args = parser.parse_args()
    try:
        check(args.original.read_text(), args.original_actor.read_bytes(), args.original_status,
              args.native.read_text(), args.prefix, args.native_status)
    except (ValueError, OSError, KeyError, IndexError, struct.error) as error:
        raise SystemExit('FAIL first-floor Load: ' + str(error))
