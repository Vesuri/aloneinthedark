#!/usr/bin/env python3
"""Check the reached idle window fill against a matching Mac service fixture."""
import argparse
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def check(log, status):
    text = log.read_text()
    if status != 0 or any(x in text for x in ('FAIL', 'Error in', 'TIMEOUT', 'Program received signal')):
        raise ValueError('native completion')
    if text.count('PASS native idle PaintRect original call and return') != 1:
        raise ValueError('missing/duplicate native return')
    if text.count('[Inferior 1 (Remote target) detached]') != 1:
        raise ValueError('native detach')

    def native(phase, kind):
        return (ROOT / 'tmp' / f'idle-paint-native-{phase}-{kind}.bin').read_bytes()

    def reference(phase, kind):
        return (ROOT / 'tmp' / f'window-mode0-reference-fixture2-{phase}-{kind}.bin').read_bytes()

    for kind in ('port', 'pm', 'clut', 'vis', 'clip', 'rect'):
        if native('entry', kind) != native('return', kind):
            raise ValueError('native changed ' + kind)
    port, pm = native('entry', 'port'), native('entry', 'pm')
    if len(port) != 108 or len(pm) != 50 or pm[32:34] != b'\0\x08':
        raise ValueError('native port layout')
    if struct.unpack_from('>H', port, 56)[0] != 0 or struct.unpack_from('>I', port, 80)[0] != 255:
        raise ValueError('native mode/foreground')
    if native('entry', 'rect') != struct.pack('>4h', -1000, -1000, 1000, 1000):
        raise ValueError('reached rectangle')
    refport, refpm = reference('enter', 'port'), reference('enter', 'pm')
    if pm[4:14] != refpm[4:14] or port[16:24] != refport[16:24]:
        raise ValueError('paired map/port geometry')
    for kind in ('vis', 'clip'):
        if native('entry', kind) != reference('enter', kind):
            raise ValueError('paired ' + kind)
    if native('entry', 'rect') != reference('enter', 'rect')[4:12]:
        raise ValueError('paired rectangle')
    if port[56:58] != refport[56:58] or port[80:84] != refport[80:84]:
        raise ValueError('paired mode/foreground')

    stride = struct.unpack_from('>H', pm, 4)[0] & 0x3fff
    mt, ml, mb, mr = struct.unpack_from('>4h', pm, 6)
    if (stride, mt, ml, mb, mr) != (640, -150, -160, 330, 480):
        raise ValueError('reached screen geometry')
    before, after = native('entry', 'screen'), native('return', 'screen')
    if len(before) != 307200 or len(after) != 307200:
        raise ValueError('complete native screen capture')
    expected = bytearray(before)
    boxes = [struct.unpack('>4h', b) for b in
             (pm[6:14], port[16:24], native('entry', 'vis')[2:],
              native('entry', 'clip')[2:], native('entry', 'rect'))]
    top, left = max(r[0] for r in boxes), max(r[1] for r in boxes)
    bottom, right = min(r[2] for r in boxes), min(r[3] for r in boxes)
    if (top, left, bottom, right) != (0, 0, 200, 320):
        raise ValueError('reached fill coverage')
    refafter = reference('return', 'pixels')
    if len(refafter) != len(after):
        raise ValueError('complete reference screen capture')
    for y in range(top, bottom):
        a, b = (y-mt)*stride+left-ml, (y-mt)*stride+right-ml
        expected[a:b] = bytes([255]) * (right-left)
        if after[a:b] != refafter[a:b]:
            raise ValueError('paired client pixels')
    if after != expected:
        raise ValueError('native fill/surrounding storage')
    # The scene palettes differ; only index 255 is displayed after this fill.
    # Compare that index's actual RGB, not unused palette entries.
    def colour(table, index):
        flags, last = struct.unpack_from('>HH', table, 4)
        for i in range(last+1):
            value, r, g, b = struct.unpack_from('>4H', table, 8+8*i)
            if (i if flags & 0x8000 else value) == index:
                return r, g, b
        raise ValueError('missing palette index')
    if colour(native('return', 'clut'), 255) != (0, 0, 0) or colour(reference('return', 'clut'), 255) != (0, 0, 0):
        raise ValueError('paired displayed black')
    print('PASS idle PaintRect: original return, 64000 paired black pixels, full-buffer preservation')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('native', type=Path)
    parser.add_argument('--status', type=int, required=True)
    parser.add_argument('--reference', type=Path, required=True)
    parser.add_argument('--reference-status', type=int, required=True)
    args = parser.parse_args()
    try:
        from check_fillrect8 import run
        run(args.reference, args.reference_status, mode=0)
        check(args.native, args.status)
    except (ValueError, OSError, struct.error) as error:
        raise SystemExit('FAIL idle PaintRect: ' + str(error))
