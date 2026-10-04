#!/usr/bin/env python3
"""Verify the reached game interfaces and the absence of Mac dialog presentation.

Resource existence is not a runtime contract. Error/monitor/About paths outside
this route remain unsupported until reached and measured.
"""
import argparse
from collections import Counter
from pathlib import Path
import re
from check_menu_keyboard import require, rgb, display_transfer


def check(reference, native, folder, menu_folder, reference_status, native_status):
    for text, status, marker in (
        (reference, reference_status, 'PASS original dialog route newgame save cancel overwrite load quit'),
        (native, native_status, 'PASS native dialog route hidden-size=1 newgame=1 save=1 load=1 Mac-presentation=0'),
    ):
        require(status == 0 and text.count(marker) == 1, 'normal route completion')
        require(not re.search(r'^FAIL|TIMEOUT|LUA ERROR|Error in|Program received signal', text, re.M),
                'route failure')
    require(reference.count('DIALOG_ROUTE_ARM bytes=2f0a2f02246f000a') == 1,
            'byte-verified reference observer')
    calls = re.findall(r'^DIALOG_ROUTE trap=(\w+) pc=(\w+) p0=(\w+) p1=(\w+) p2=(\w+)$', reference, re.M)
    # Earlier captures include A992 (DetachResource) from the interleaved range.
    # It does not provide dialog presentation or choices.
    direct = [tuple(int(value, 16) for value in row) for row in calls
              if int(row[0], 16) != 0xa992 and 0x100000 < (int(row[1], 16) & 0xffffff) < 0x800000]
    require(Counter(row[0] for row in direct) ==
            Counter({0xa97b: 1, 0xa97c: 1, 0xa991: 2, 0xa98d: 2, 0xa983: 1}),
            'only measured startup Dialog Manager calls; no alerts or StandardFile')
    constructor = next(row for row in direct if row[0] == 0xa97c)
    require(constructor[2:] == (0xffffffff, 0, 1000 << 16), 'hidden-size constructor arguments')
    require(int(next(row[1] for row in calls if row[0] == 'A97D'), 16) > 0x800000,
            'System internal constructor is separate from original game callers')
    states = re.findall(r'^DIALOG_STATE ([\w-]+) ticks=\d+$', reference, re.M)
    require(states == ['main-menu', 'new-game', 'character-story', 'attic', 'save-cancel',
                       'save-cancelled', 'save-name', 'saved', 'overwrite', 'overwritten',
                       'load-cancel', 'load-cancelled', 'load', 'loaded'], 'original route states')
    require(re.findall(r'^DIALOG_BOOT stage=(\d+)', native, re.M) == list('012345'),
            'native normal boot, character choice and story route')
    require(native.count('DIALOG_NATIVE hidden-size=1') == 1 and
            native.count('PASS MENUS keyboard quit and restoration') == 1 and
            native.count('[Inferior 1 (Remote target) detached]') == 1,
            'native hidden-size positive control and full shutdown')
    transfer = display_transfer()[::256]
    outside = [i for i in range(307200) if not (150 <= i//640 < 350 and 160 <= i % 640 < 480)]
    baseline = (menu_folder/'native-1-screen.bin').read_bytes()
    require(len(baseline) == 307200, 'baseline extent')
    for name in ('new-game', 'character-story'):
        raw = (folder/f'mac-{name}-rgb.bin').read_bytes()
        require(len(raw) == 640*480*4, 'original screen extent')
        mac = b''.join(raw[i:i+3][::-1] for i in range(0, len(raw), 4))
        pixels = (folder/f'native-{name}-screen.bin').read_bytes()
        amiga = rgb(pixels, (folder/f'native-{name}-clut.bin').read_bytes(), transfer)
        require(all(mac[(y*640+160)*3:(y*640+480)*3] ==
                    amiga[(y*640+160)*3:(y*640+480)*3] for y in range(150, 350)),
                'exact original engine artwork and text: '+name)
        require(all(pixels[i] == baseline[i] for i in outside), 'no pixels outside viewport: '+name)
    # Names and slot thumbnails legitimately differ after independent saves.
    # These measured sample points identify the engine's save/load artwork.
    for original_name, stage in (('save-name', 6), ('load-cancel', 8)):
        mac = (folder/f'mac-{original_name}-rgb.bin').read_bytes()
        pixels = (menu_folder/f'native-{stage}-screen.bin').read_bytes()
        amiga = rgb(pixels, (menu_folder/f'native-{stage}-clut.bin').read_bytes(), transfer)
        for x, y, color in ((190, 180, 0x84653b), (400, 210, 0x81a1a1), (200, 345, 0)):
            at = y*640+x
            require(int.from_bytes(mac[at*4:at*4+3], 'little') == color and
                    int.from_bytes(amiga[at*3:at*3+3], 'big') == color, 'engine save/load artwork')
        require(all(pixels[i] == baseline[i] for i in outside), 'save/load viewport bounds')
    print('PASS dialog route: exact new-game/story frames, engine save/load, cancellation, original overwrite/load, hidden size only; no Mac dialog presentation')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('reference', type=Path)
    parser.add_argument('native', type=Path)
    parser.add_argument('--reference-status', type=int, required=True)
    parser.add_argument('--native-status', type=int, required=True)
    parser.add_argument('--folder', type=Path, default=Path('tmp/m3-dialog'))
    parser.add_argument('--menu-folder', type=Path, default=Path('tmp/m3-menu'))
    args = parser.parse_args()
    try:
        check(args.reference.read_text(), args.native.read_text(), args.folder,
              args.menu_folder, args.reference_status, args.native_status)
    except (ValueError, OSError, StopIteration) as error:
        raise SystemExit('FAIL dialog route: '+str(error))
