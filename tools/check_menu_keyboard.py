#!/usr/bin/env python3
"""Verify M3.2 keyboard commands, shutdown, published feedback and viewport bounds."""
import argparse
import json
from pathlib import Path
import re
import struct
from check_driver22 import fields, one
from resource_fork import read_resource_fork
from check_video_transfer import native as display_transfer

ROOT = Path(__file__).resolve().parents[1]


def require(value, message):
    if not value:
        raise ValueError(message)


def rgb(pixels, table, transfer):
    require(len(pixels) == 307200 and len(table) == 2056, 'native frame extent')
    colors = [bytes(table[10+i*8+j] for j in (0, 2, 4)) for i in range(256)]
    return b''.join(colors[index] for index in pixels).translate(transfer)


def glyph_mask(message):
    glyphs = json.loads((ROOT/'resources/times14-bitmap.json').read_text())['glyphs']
    header = (ROOT/'src/mac/Times14Metrics.h').read_text().split('advances[256]={')[1].split('};')[0]
    units = list(map(int, re.findall(r'\d+', header)))
    position, points = 32768, set()
    for character in message:
        left, top, width, rows = glyphs[character-32]
        for y, bits in enumerate(rows):
            for x in range(width):
                if bits & (1 << (width-1-x)):
                    points.add((position//65536+left+x, top+y))
        position += units[character]*76544
    left, top = min(x for x, y in points), min(y for x, y in points)
    return frozenset((x-left, y-top) for x, y in points)


def feedback_bands(pixels, foreground):
    # The unchanged game stacks messages in slots above its copyright line.
    # Captures can contain different older queued messages. Pair the requested
    # message wherever the game placed it; retain exact horizontal position.
    points = {(x, y) for y in range(290, 330) for x in range(230, 420)
              if pixels[(y*640+x)*3:(y*640+x)*3+3] == foreground}
    bands = []
    for y in sorted({y for x, y in points}):
        if not bands or y > bands[-1][-1]+1:
            bands.append([y])
        else:
            bands[-1].append(y)
    result = []
    for rows in bands:
        ink = {(x, y) for x, y in points if y in rows}
        left, top = min(x for x, y in ink), min(rows)
        result.append((frozenset((x-left, y-top) for x, y in ink), left))
    return result


def check(reference, native, folder, reference_status, native_status):
    for label, text, status, marker in (
        ('Mac', reference, reference_status, 'PASS original keyboard menus commands=3'),
        ('Amiga', native, native_status, 'PASS MENUS keyboard quit and restoration'),
    ):
        require(status == 0 and text.count(marker) == 1, label+' completion')
        require(not re.search(r'FAIL|TIMEOUT|LUA ERROR|Error in|Program received signal', text), label+' failure')
    require(native.count('[Inferior 1 (Remote target) detached]') == 1, 'native detach')
    expected = [('73', '810002'), ('6F', '810001'), ('71', '810004')]
    original = re.findall(r'^MENUKEY_RETURN key=(\w+) result=(\w+) delta=10$', reference, re.M)
    mapped = [(key, result) for key, result in re.findall(
        r'^MENUKEY_NATIVE key=(\w+) result=(\w+)$', native, re.M) if int(result, 16)]
    require(original == mapped == expected, 'Save/Load/Quit menu mapping')
    stages = re.findall(r'^MENU_STAGE stage=(\d+) tick=(\d+) song=(\d+) playing=(\d+)', native, re.M)
    require([int(row[0]) for row in stages] == list(range(1, 11)), 'native stage order')
    require([(int(stages[n-1][2]), int(stages[n-1][3])) for n in (1, 4, 5)]
            == [(137, 1), (137, 0), (137, 1)], 'music stop/resume')
    require('PASS driver8 native ABI preserved=13 ccr=4 DMA=0' in native, 'native shutdown ABI/DMA')
    require('MENU_EXIT ok=1 linea=0 view=1' in native, 'OS/file closure')
    before = (folder/'driver8-native-enter-config.bin').read_bytes()
    require(before and before == (folder/'driver8-native-return-config.bin').read_bytes(),
            'shutdown configuration preservation')

    code = next(r.body for r in read_resource_fork(ROOT/'tmp/runtime-data/Alone In The Dark')
                if r.kind == b'CODE' and r.rid == 3)
    require(code[0x1dc4:0x1dd0].hex() == '48780008206df9544e90588f'
            and one(reference, r'^DRIVER8_BYTES (\w+)$') == code[0x1dc4:0x1dd0].hex().upper(),
            'original shutdown caller bytes')
    entry, returned = [fields(one(reference, '^DRIVER8_'+phase+' (.*)$')) for phase in ('ENTER', 'RETURN')]
    require(entry['selector'] == 8 and returned['sp'] == entry['sp']
            and returned['d0'] == 0 and returned['d1'] == 1 and returned['sr'] & 31 == 4,
            'original shutdown return ABI')
    for register in [f'd{i}' for i in range(2, 8)]+[f'a{i}' for i in range(7)]:
        require(entry[register] == returned[register], 'original preserved '+register)
    driver = (folder/'driver8-driver.bin').read_bytes()
    for offset, encoded in ((0, '202f0004222f000848e73ffe'), (0x54, '6000032a'),
                            (0x380, '61003c086000fd24'), (0x3f8a, '6100c468426c182a6184')):
        require(driver[offset:offset+len(encoded)//2].hex() == encoded, 'original shutdown instructions')
    old = (folder/'driver8-enter-state.bin').read_bytes()
    new = (folder/'driver8-return-state.bin').read_bytes()
    require(len(old) == len(new) == 0x3048, 'original complete driver capture')
    word = lambda data, offset: struct.unpack_from('>I', data, offset)[0]
    require(word(old, 0x58) and word(old, 0x226c), 'original allocated hardware/storage positive controls')
    for offset in (0x58, 0x226c, 0x187a, 0x32, 0x2c):
        require(word(new, offset) == 0, 'original disposed pointer '+hex(offset))
    offset = 0x2ef0
    while word(old, offset):
        require(word(new, offset) == 0 and offset < 0x3040, 'original effect sample ownership')
        offset += 4
    require(offset > 0x2ef0 and old[0x11c0:0x11c6] == new[0x11c0:0x11c6],
            'original effect/configuration positive controls')

    baseline = (folder/'native-1-screen.bin').read_bytes()
    # The first checkpoint and menu-dismissal checkpoints can precede room
    # publication. Require rendered content in the control and menu states.
    require(len(baseline) == 307200, 'native initial frame extent')
    outside = [i for i in range(307200) if not (150 <= i//640 < 350 and 160 <= i % 640 < 480)]
    for number in range(2, 10):
        pixels = (folder/f'native-{number}-screen.bin').read_bytes()
        if number in (2, 3, 4, 5, 6, 8):
            require(len(set(pixels)) > 32, f'rendered native viewport at stage {number}')
        require(len(pixels) == len(baseline) and all(pixels[i] == baseline[i] for i in outside),
                f'unchanged pixels outside viewport at stage {number}')
    messages = {b'Sound effects OFF': 'sound-off', b'Sound effects ON': 'sound-on',
                b'Music OFF': 'music-off', b'Music ON': 'music-on'}
    require(set(map(int, re.findall(r'^MENU_FEEDBACK stage=(\d+)', native, re.M))) == {1, 2, 3, 4},
            'four current-run published feedback captures')
    seen = set()
    transfer = display_transfer()[::256]
    for number in (6, 8):
        menu = rgb((folder/f'native-{number}-screen.bin').read_bytes(),
                   (folder/f'native-{number}-clut.bin').read_bytes(), transfer)
        for x, y, color in ((190, 180, 0x84653b), (400, 210, 0x81a1a1), (200, 345, 0)):
            at = (y*640+x)*3
            require(int.from_bytes(menu[at:at+3], 'big') == color, 'published Save/Load menu state')
    raw = (folder/'mac-sound-off-rgb.bin').read_bytes()
    original_off = b''.join(raw[i:i+3][::-1] for i in range(0, len(raw), 4))
    foreground = max((original_off[(y*640+x)*3:(y*640+x)*3+3]
                      for y in range(310, 328) for x in range(230, 420)), key=sum)
    for number in range(1, 5):
        message = (folder/f'feedback-{number}-text.bin').read_bytes()
        require(message in messages and message not in seen, 'sound/music feedback message')
        seen.add(message)
        pixels = (folder/f'feedback-{number}-screen.bin').read_bytes()
        require(all(pixels[i] == baseline[i] for i in outside), 'feedback confined to viewport')
        colors = (folder/f'feedback-{number}-clut.bin').read_bytes()
        raw = (folder/f'mac-{messages[message]}-rgb.bin').read_bytes()
        require(len(raw) == 640*480*4, 'original feedback extent')
        original_rgb = b''.join(raw[i:i+3][::-1] for i in range(0, len(raw), 4))
        expected_ink = glyph_mask(message)
        reference_bands = [band for band in feedback_bands(original_rgb, foreground)
                           if band[0] == expected_ink]
        require(len(reference_bands) == 1, 'original exact message glyphs: '+message.decode())
        require(reference_bands[0] in feedback_bands(rgb(pixels, colors, transfer), foreground),
                'published original/native glyphs, colour and centring: '+message.decode())
    require(seen == set(messages), 'all sound/music choices')
    print('PASS M3.2: original menu results, four exact published feedback glyphs/colours/centring, viewport bounds and full Quit restoration')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('reference', type=Path)
    parser.add_argument('native', type=Path)
    parser.add_argument('--folder', type=Path, default=ROOT/'tmp/m3-menu')
    parser.add_argument('--reference-status', type=int, required=True)
    parser.add_argument('--native-status', type=int, required=True)
    args = parser.parse_args()
    try:
        check(args.reference.read_text(), args.native.read_text(), args.folder,
              args.reference_status, args.native_status)
    except (ValueError, OSError, KeyError) as error:
        raise SystemExit('FAIL menu keyboard: '+str(error))
