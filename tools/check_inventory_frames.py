#!/usr/bin/env python3
"""Compare the Book inventory and action views at paired preview phases."""
import argparse
from pathlib import Path
import re
import struct
from check_menu_keyboard import require, rgb
from check_video_transfer import native as display_transfer


def check(reference, folder, mac_log, native_log, mac_status, native_status):
    for label, text, status, marker in (
        ('Mac', mac_log, mac_status,
         'PASS original book forward/backward pages, last-page Return and manual gameplay'),
        ('Amiga', native_log, native_status,
         'PASS BOOK Take, Read and published manual gameplay')):
        require(status == 0 and text.count(marker) == 1, label + ' completed route')
        require(not re.search(r'FAIL|TIMEOUT|LUA ERROR|Error in|Program received signal', text),
                label + ' no diagnostic failure')
    transfer = display_transfer()[::256]
    for stage, label, angle in ((31, 'book-selected', 688), (33, 'book-actions', 672)):
        stem = f'menu-{stage}-{angle}'
        require(re.search(rf'^INVENTORY_PAIR stage={stage} angle={angle} tick=\d+$',
                          native_log, re.M), label + ' observed phase')
        for side, path in (
            ('Mac', reference / f'book-session-{label}-a5.bin'),
            ('Amiga', folder / f'{stem}-a5.bin')):
            data = path.read_bytes()
            require(len(data) == 75616, side + ' world extent')
            def word(offset):
                return struct.unpack_from('>h', data, len(data) + offset)[0]
            require(word(-0xce86) & 1023 == angle, side + ' paired preview angle')
            require(tuple(word(o) for o in (-0xd8a6, -0xd8a4, -0xd8a2, -0xd8a0,
                                           -0xd8a8, -0xd868)) == (3, 2, 12, 13, 2, 0),
                    side + ' inventory, stance and pending action')
            book = -0x115f2 + 12 * 52
            require(tuple(word(book + o) for o in (8, 10, 12, 28, 30)) ==
                    (21, 205, -31228, -1, -1), side + ' taken unread Book')
        raw = (reference / f'book-session-mac-{label}-rgb.bin').read_bytes()
        require(len(raw) == 640 * 480 * 4, 'original frame extent')
        original = b''.join(raw[i:i+3][::-1] for i in range(0, len(raw), 4))
        pixels = (folder / f'{stem}-screen.bin').read_bytes()
        colors = (folder / f'{stem}-clut.bin').read_bytes()
        require(len(pixels) == 307200 and len(colors) == 2056, 'native frame extent')
        actual = rgb(pixels, colors, transfer)
        differences = sum(original[i:i+3] != actual[i:i+3]
                          for y in range(150, 350) for x in range(160, 480)
                          for i in [(y * 640 + x) * 3])
        require(differences == 0, f'{label}: {differences} differing viewport pixels')
        print(f'PASS {label}: paired inventory/rotation and all 64000 viewport pixels')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--reference', type=Path, required=True)
    parser.add_argument('--folder', type=Path, required=True)
    parser.add_argument('--mac-log', type=Path, required=True)
    parser.add_argument('--native-log', type=Path, required=True)
    parser.add_argument('--mac-status', type=int, required=True)
    parser.add_argument('--native-status', type=int, required=True)
    args = parser.parse_args()
    try:
        check(args.reference, args.folder, args.mac_log.read_text(),
              args.native_log.read_text(), args.mac_status, args.native_status)
    except (ValueError, OSError) as error:
        raise SystemExit('FAIL inventory frames: ' + str(error))
