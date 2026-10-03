#!/usr/bin/env python3
"""Check paired original/native first-room controls, not equal-time pixels."""
import argparse
import re
import struct
from pathlib import Path


def require(condition, message):
    if not condition:
        raise ValueError(message)


def check(reference, native, folder, reference_status, native_status):
    for label, text, status, marker in (
        ('Mac', reference, reference_status, 'PASS original gameplay controls'),
        ('Amiga', native, native_status, 'PASS GAMEPLAY input sequence completed'),
    ):
        require(status == 0 and text.count(marker) == 1, label+' completion')
        require(not re.search(r'FAIL|TIMEOUT|LUA ERROR|Error in|Program received signal', text), label+' diagnostic failure')
    require('[Inferior 1 (Remote target) detached]' in native, 'native detach')
    require(re.findall(r'^INPUT_STAGE stage=(\d+)', native, re.M) == list(map(str, range(1, 10))), 'native phase order')
    rows = re.findall(r'^CONTROL stage=(\d+) tick=(\d+) actor=(-?\d+) body=(-?\d+) x=(-?\d+) z=(-?\d+) anim=(-?\d+) frame=(-?\d+) key=(-?\d+) direction=(-?\d+) action=(-?\d+)$', reference, re.M)
    require([r[0] for r in rows] == list(map(str, range(1, 10))), 'original phase order')
    require(tuple(map(int, rows[-1][-3:])) == (0, 0, 0), 'original released input')
    for label in ('Mac', 'Amiga'):
        states = {}
        for n in range(1, 10):
            name = f'mac-input-{n}-actor.bin' if label == 'Mac' else f'input-{n}-actors.bin'
            raw = (folder/name).read_bytes()
            require(len(raw) == (160 if label == 'Mac' else 16000), label+' actor extent')
            actor = raw if label == 'Mac' else raw[160:320]
            word = lambda offset: struct.unpack_from('>h', actor, offset)[0]
            require((word(0), word(2), word(0x30)) == (1, 12, 0), label+' Carnby/attic identity')
            states[n] = (word(0x1c), word(0x20), word(0x3e))
            if label == 'Mac':
                require(states[n] == tuple(map(int, rows[n-1][4:7])), 'original log/capture identity')
            else:
                pixels = (folder/f'input-{n}-screen.bin').read_bytes()
                # Phase 1 can precede the first room publication; all later
                # phases must contain the rendered game, including the action.
                require(len(pixels) == 307200 and (n == 1 or len(set(pixels)) > 32), 'native rendered scene')
                require(len((folder/f'input-{n}-clut.bin').read_bytes()) == 2056, 'native palette extent')
        require([states[n][2] for n in (2, 4, 8, 9)] == [254, 255, 262, 4], label+' walk/run/kick/idle animations')
        walk = abs(states[3][1]-states[1][1])
        run = abs(states[5][1]-states[3][1])
        require(run > walk > 0, label+' walk/run displacement')
        require(states[5][:2] == states[9][:2], label+' stationary fight/release')
        print(f'PASS {label} controls: walk={walk}, run={run}, kick=262, released idle=4')
    native_counts = re.search(r'INPUT_TRAPS wait=(\d+) next=(\d+) keys=(\d+) button=(\d+) still=(\d+) flush=(\d+) systemclick=(\d+) obscure=(\d+) windows=(\d+)', native)
    original_counts = re.search(r'CONTROL_TRAPS ([\d,]+)', reference)
    require(native_counts and original_counts, 'service inventory presence')
    a = tuple(map(int, native_counts.groups()))
    b = tuple(map(int, original_counts[1].split(',')))
    require(len(b) == 8 and all(a[i] > 0 and b[i] > 0 for i in (0, 2, 3)), 'service inventory positive controls')
    require(a[4:7] == b[4:7] == (0, 0, 0), 'unreached first-room services')
    require(a[8] > 0, 'disk-window path exercised')
    print('PASS paired first-room gameplay and reached-service inventory')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('reference', type=Path)
    parser.add_argument('native', type=Path)
    parser.add_argument('--folder', type=Path, default=Path('tmp/m3-input'))
    parser.add_argument('--reference-status', type=int, required=True)
    parser.add_argument('--native-status', type=int, required=True)
    args = parser.parse_args()
    try:
        check(args.reference.read_text(), args.native.read_text(), args.folder,
              args.reference_status, args.native_status)
    except (ValueError, OSError) as error:
        raise SystemExit('FAIL gameplay: '+str(error))
