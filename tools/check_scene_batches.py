#!/usr/bin/env python3
"""Check complete intro batches and independently decode every captured back buffer.

Read-only GDB captures at AitdScreen::queueFrame precede pointer publication;
they establish buffer correctness, not host-window or audible acceptance.
"""
import argparse
import hashlib
from pathlib import Path
import re
import struct

from check_aga_capture import read, require


def decode(planes):
    # Expand each plane byte into eight byte-wide lanes, then combine planes.
    # This is independent of the runtime's Kalms conversion and row-sync code.
    expand = [sum(((value >> (7-x)) & 1) << (x*8) for x in range(8))
              for value in range(256)]
    result = bytearray(64000)
    for y in range(200):
        base = y*320
        for byte in range(40):
            pixels = 0
            for plane in range(8):
                pixels |= expand[planes[base+plane*40+byte]] << plane
            result[base+byte*8:base+byte*8+8] = pixels.to_bytes(8, 'little')
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('log', type=Path)
    parser.add_argument('folder', type=Path)
    parser.add_argument('--status', type=int, required=True)
    parser.add_argument('--transfer', type=Path, default=Path('tmp/video-transfer-lut16.bin'))
    args = parser.parse_args()
    log = args.log.read_text()
    require(args.status == 0 and not re.search(r'FAIL|[Tt]imeout|Error in|Protocol error', log),
            'successful runner status')
    require(log.count('PASS original demo timing complete') == 1
            and '[Inferior 1 (Remote target) detached]' in log, 'natural observer completion')
    require(len(re.findall(r'INTRO_TIME stage=transition ', log)) == 9, 'nine major transitions')
    batch = re.findall(r'SCENE_BATCH begun=(\d+) completed=(\d+) active=(\d+)', log)
    require(len(batch) == 1 and int(batch[0][0]) > 0
            and batch[0][0] == batch[0][1] and batch[0][2] == '0', 'balanced scene batches')
    require(re.search(r'FIXED_ROUTE choice=0 randomCalls=[1-9]\d*', log), 'controlled character')
    require(re.search(r'MUSIC_IRQ_ROUTE notes=3736 maxLate=[01] prepared=\d+ latePresents=0 ', log),
            'complete music and timely publication')
    captures = re.findall(r'SCENE_PLANAR n=(\d+) frame=(\d+) left=(\d+) top=(\d+) back=([0-9A-Fa-f]+)', log)
    final = re.findall(r'SCENE_DISPLAY queued=(\d+) presented=(\d+) checks=(\d+)', log)
    require(len(final) == 1 and final[0][0] == final[0][1]
            and int(final[0][2]) == len(captures) and len(captures) > 100,
            'all queued frames published and captured')
    transfer = args.transfer.read_bytes()
    require(hashlib.sha256(transfer).hexdigest() ==
            'bf0a6433c155a61989e5dc0571bae1357066ab476a24d0afaf2e2aa7094fe2aa',
            'independently measured Mac colour transfer')
    first_frame = int(captures[0][1])
    for index, record in enumerate(captures, 1):
        n, frame, left, top = map(int, record[:4])
        require(n == index and frame == first_frame+index-1, 'continuous capture sequence')
        require((left, top) == (160, 150), 'game viewport')
        require(0 < int(record[4], 16) < 0x200000-64000, 'chip-memory back buffer')
        prefix = f'queued-{n:05d}'
        source = read(args.folder, prefix+'-screen.bin', 307200)
        planes = read(args.folder, prefix+'-planes.bin', 64000)
        expected = b''.join(source[y*640+left:y*640+left+320] for y in range(top, top+200))
        require(decode(planes) == expected, f'frame {frame}: all 64000 pixels')
        clut = read(args.folder, prefix+'-clut.bin', 2056)
        palette = struct.unpack('>256I', read(args.folder, prefix+'-palette.bin', 1024))
        for pen, actual in enumerate(palette):
            r, g, b = struct.unpack_from('>3H', clut, 10+pen*8)
            require(actual == (transfer[r] << 16 | transfer[g] << 8 | transfer[b]),
                    f'frame {frame}: colour {pen}')
    require(int(captures[-1][1]) == int(final[0][0]), 'capture reaches final publication')
    print(f'PASS {len(captures)} complete published buffers, all pixels and colours; '
          f'{batch[0][0]} balanced scene batches, full route and music')


if __name__ == '__main__':
    main()
