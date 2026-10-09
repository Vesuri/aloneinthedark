#!/usr/bin/env python3
"""Compare four instruction-matched intro states and native AGA publication."""
import argparse
import hashlib
from pathlib import Path
import re
import struct
from check_aga_capture import check_frame, read, require

STATES = [(1, 5, 0x1c94), (2, 5, 0x1f46), (3, 13, 0x2ed4), (4, 4, 0x5220)]
def capture(log, status, side):
    require(status == 0 and not re.search(r'FAIL|LUA ERROR|Error in|TIMEOUT|Timed out|Program received signal', log), side+' clean completion')
    terminal = 'Exited via the debugger' if side == 'reference' else '[Inferior 1 (Remote target) detached]'
    require(log.count(terminal) == 1, side+' terminal record')
    rows = re.findall(r'^INTRO_FRAME n=(\d+) segment=(\d+) offset=([0-9A-F]+) d0=([0-9A-F]+)$', log, re.M)
    records = [tuple(int(v, 16 if i >= 2 else 10) for i, v in enumerate(row)) for row in rows]
    require([r[:3] for r in records] == STATES, side+' original state keys/order')
    require(records[-1][3] == 0, side+' uninterrupted completion')
    if side == 'reference':
        require(log.count('PASS original intro frames=4') == 1, 'original completion')
    else:
        coverage = re.findall(r'^PASS full intro C2P frames=(\d+) partial=(\d+) failures=(\d+) queued=(\d+) presented=(\d+) book=(\d+)/(\d+) ticks=(\d+)$', log, re.M)
        require(len(coverage) == 1, 'full intro C2P completion')
        frames, partial, failures, queued, presented, begun, completed, ticks = map(int, coverage[0])
        require(frames == queued == presented and frames >= 840 and 0 < partial <= frames and failures == 0 and begun == completed == 840 and ticks > 0, 'full intro conversion/publication coverage')


def check_pixels(pixels, original, state):
    differences = [(x, y) for y in range(200) for x in range(320)
                   if pixels[(y+150)*640+x+160] != original[(y+150)*640+x+160]]
    require(not differences, f'frame {state[0]}: {len(differences)} differing viewport pixels')
    print(f'PASS frame {state[0]}: original state CODE {state[1]}+{state[2]:X}, all 64000 pixels, palette and AGA publication')


def compare(reference, native, reference_status, native_status, folder):
    capture(reference, reference_status, 'reference')
    capture(native, native_status, 'native')
    publications = re.findall(r'^INTRO_PUBLICATION n=(\d+) front=([0-9A-F]+) queued=(\d+) presented=(\d+) randomCalls=(\d+)$', native, re.M)
    require(len(publications) == 4, 'four native publications')
    cursors = re.findall(r'^INTRO_CURSOR n=(\d+) enabled=(\d+) control=([0-9A-F]+)$', native, re.M)
    require(not cursors or cursors == [(str(n),'1','010F') for n in range(1,5)], 'four pointer palette publications')
    inversions = re.findall(r'^INTRO_INVERSION n=(\d+) active=([01]) left=(-?\d+) top=(-?\d+)$', native, re.M)
    require(not inversions or [row[0] for row in inversions] == ['1','2','3','4'], 'four cursor inversion records')
    transfer = read(folder, 'video-transfer-lut16.bin', 65536)
    require(hashlib.sha256(transfer).hexdigest() == 'bf0a6433c155a61989e5dc0571bae1357066ab476a24d0afaf2e2aa7094fe2aa', 'reference colour transfer')
    previous = 0
    for state, publication in zip(STATES, publications):
        n, front, queued, presented, random_calls = publication
        require(int(n) == state[0] and int(queued) > previous and queued == presented and int(random_calls) == 0, 'complete pre-random intro state')
        previous = int(queued)
        prefix = 'intro-native-'+n
        pixels = read(folder, prefix+'-screen.bin', 307200)
        clut = read(folder, prefix+'-clut.bin', 2056)
        original = read(folder, 'intro-reference-'+n+'-screen.bin', 307200)
        original_clut = read(folder, 'intro-reference-'+n+'-clut.bin', 2056)
        for pen in range(256):
            require(clut[10+pen*8:16+pen*8] == original_clut[10+pen*8:16+pen*8], f'frame {n} palette {pen}')
        overlay = None
        if inversions:
            _, active, left, top = inversions[int(n)-1]
            masks = struct.unpack('>16H', read(folder, prefix+'-inversion.bin', 32))
            if active == '1':
                overlay = (int(left), int(top), masks)
        check_frame(folder, prefix, pixels, clut, 160, 150, int(front, 16), transfer, 1 if cursors else 0, overlay)
        check_pixels(pixels, original, state)
    print('PASS paired intro: logo and three states, uninterrupted completion and full-frame C2P coverage')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('reference_log', type=Path)
    parser.add_argument('native_log', type=Path)
    parser.add_argument('--reference-status', type=int, required=True)
    parser.add_argument('--native-status', type=int, required=True)
    parser.add_argument('--folder', type=Path, default=Path('tmp'))
    args = parser.parse_args()
    try:
        compare(args.reference_log.read_text(), args.native_log.read_text(), args.reference_status, args.native_status, args.folder)
    except (ValueError, OSError) as error:
        raise SystemExit('FAIL intro comparison: '+str(error))
