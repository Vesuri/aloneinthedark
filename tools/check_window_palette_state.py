#!/usr/bin/env python3
"""Pair original MoveWindow/ShowWindow state with the native logical display."""
import argparse
import hashlib
from pathlib import Path
import struct
from check_choice_services import one
from check_getgworld import fields
from check_ctable import preserved
from check_palette8 import SYSTEM_CLUT_SHA
from resource_fork import read_resource_fork

CASES = (('move', 0xfac, 0xa91b, 10, 0xf94, 0xfb4,
          'ac7b10b44ab334076f90cb605411a22f4d82b7cb09e3e91470942a38dea74d5a'),
         ('show', 0x10e6, 0xa915, 4, 0x10e2, 0x10e8,
          'fbb2f10eed30f3a3ccbb42f116e135a329de15963a39307a540398422a54a59c'))
SIZES = dict(palette=4112, private=4, window=156, gd=62, pm=50, clut=2056)


def require(ok, message):
    if not ok:
        raise ValueError(message)


def u32(data, offset=0):
    return int.from_bytes(data[offset:offset+4], 'big')


def check(reference, native, reference_status, native_status, folder, resource):
    rows = read_resource_fork(resource)
    code = next(r.body for r in rows if r.kind == b'CODE' and r.rid == 9)
    captured = {}
    for kind, text, status in (('reference', reference, reference_status),
                                ('native', native, native_status)):
        require(status == 0 and not any(s in text for s in
                ('FAIL', 'Error in', '[LUA ERROR]', 'timeout', 'Program received signal')),
                kind+' observer failed')
        markers = ('PASS original window palette state calls=2',
                   'ARM window palette state dispatcher bytes=2f0a2f02246f000a',
                   'Exited via the debugger') if kind == 'reference' else (
                   'PASS native window palette state calls=2',
                   'PASS native window colours=2 original-MDRV=absent',
                   '[Inferior 1 (Remote target) detached]')
        require(all(text.count(s) == 1 for s in markers), kind+' completion')
        for label, offset, opcode, pop, start, end, digest in CASES:
            original = code[start:end]
            require(hashlib.sha256(original).hexdigest() == digest, 'original '+label+' instructions')
            require(bytes.fromhex(one(text, r'WP_BYTES label='+label+r' data=([0-9A-F]+)')) == original,
                    'live '+label+' instructions')
            require(fields(one(text, r'WP_SITE label='+label+r' (.*)')) ==
                    dict(offset=offset, opcode=opcode), 'call site')
            enter = fields(one(text, r'WP_ENTER label='+label+r' (.*)'))
            returned = fields(one(text, r'WP_RETURN label='+label+r' (.*)'))
            preserved(enter, returned, pop)
            args = bytes.fromhex(one(text, r'WP_ENTER label='+label+r' .*args=([0-9A-F]+) .*'))
            before = fields(one(text, r'WP_STATE label='+label+r' phase=before (.*)'))
            after = fields(one(text, r'WP_STATE label='+label+r' phase=after (.*)'))
            require(before == after and all(before.values()), 'stable record identities')
            require((u32(args, 6) if label == 'move' else u32(args)) == before['window'], 'window argument')
            if label == 'move':
                require(args[0] == 0 and args[2:6] == bytes.fromhex('e0c0e0c0'), 'move arguments')
            for phase in ('before', 'after'):
                records = {}
                for name, size in SIZES.items():
                    data = (folder/f'windowstate-{kind}-{label}-{phase}-{name}.bin').read_bytes()
                    require(len(data) == size, name+' extent')
                    records[name] = data
                require(u32(records['palette'], 12) & (0xffffff if kind == 'reference' else 0xffffffff)
                        == before['private'], 'private handle identity')
                captured[kind, label, phase] = records
            a, b = (captured[kind, label, phase] for phase in ('before', 'after'))
            for name in ('gd', 'pm'):
                require(a[name] == b[name], 'device record mutation')
            palette = bytearray(a['palette'])
            window = bytearray(a['window'])
            if label == 'move':
                require(palette[4:12] == bytes.fromhex('0000e00200000000'), 'initial palette header')
                palette[6] = 0xc0
                palette[8:12] = bytes.fromhex('00000001')
                require(a['private'] == b['private'] == bytes(4) and a['clut'] == b['clut'], 'move colours')
            else:
                require(palette[4:12] == bytes.fromhex('0000c00200000001'), 'prepared palette header')
                require(hashlib.sha256(a['clut'][4:]).hexdigest() == SYSTEM_CLUT_SHA, 'initial complete system CLUT')
                table = bytearray(a['clut'])
                table[:4] = b['clut'][:4]
                require(a['private'] == bytes(4) and b['private'] == table[:4]
                        and u32(table) != u32(a['clut']), 'private/CLUT fresh seed')
                retained = []
                for i in range(256):
                    entry = 16+i*16
                    rgb = palette[entry:entry+6]
                    require(palette[entry+6:entry+16] == bytes.fromhex('000a0000000000000000'), 'initial entry')
                    if rgb in (bytes(6), bytes([255])*6):
                        retained.append(i)
                    else:
                        table[8+i*8:16+i*8] = b'\x20\x00'+rgb
                    palette[entry+10:entry+12] = b'\x80\x0a'
                require(retained == [0, 1, 15, 191, 255], 'endpoint identity')
                require(table == b['clut'], 'full realized device CLUT')
                require(window[110] == 0 and window[42:48] == bytes(6), 'invisible black-background window')
                window[110:112] = b'\x01\xff'
            require(palette == b['palette'] and window == b['window'], label+' complete record effects')
        a, b = (captured[kind, label, phase] for label, phase in (('move', 'after'), ('show', 'before')))
        require(all(a[name] == b[name] for name in ('palette', 'private', 'clut', 'gd', 'pm')), 'state between calls')
    for label, *_ in CASES:
        for phase in ('before', 'after'):
            a, b = (captured[kind, label, phase] for kind in ('reference', 'native'))
            require(a['palette'][:12]+a['palette'][16:] == b['palette'][:12]+b['palette'][16:], 'paired complete palette')
            require(a['clut'][4:] == b['clut'][4:], 'paired complete CLUT')
    # Per-window coordinates and complete regions, independently captured on both sides.
    for label in ('move', 'show'):
        for phase in ('before', 'after'):
            records = []
            for kind in ('reference', 'native'):
                prefix = folder/f'windowstate-{kind}-{label}-{phase}'
                pm = Path(str(prefix)+'-windowpm.bin').read_bytes()
                port = captured[kind, label, phase]['window']
                require(len(pm) == 50, kind+' window PixMap extent')
                expected_port = (0, 0, 16000, 16000) if label == 'move' else (0, 0, 200, 320)
                expected_pm = (8000, 8000, 8480, 8640) if label == 'move' else (-150, -160, 330, 480)
                require(struct.unpack_from('>4h', port, 16) == expected_port and
                        struct.unpack_from('>4h', pm, 6) == expected_pm, kind+' local/global geometry')
                regions = {}
                handles = []
                for name, offset in (('visibility',24), ('clip',28), ('structure',114), ('content',118), ('update',122)):
                    handles.append(u32(port, offset))
                    region = Path(str(prefix)+'-'+name+'.bin').read_bytes()
                    require(len(region) >= 10 and int.from_bytes(region[:2], 'big') == len(region), kind+' region extent')
                    regions[name] = region
                    if name == 'clip':
                        require(region == bytes.fromhex('000a800180017fff7fff'), kind+' unrestricted clip')
                    elif label == 'move' or phase == 'before':
                        expected = '000affee004effee004e' if label == 'show' and name == 'update' else '000a0000000000000000'
                        require(region == bytes.fromhex(expected), kind+' hidden empty region')
                require(all(handles) and len(set(handles)) == 5, kind+' independent regions')
                records.append(regions)
            require(records[0] == records[1], label+'/'+phase+' paired complete window regions')
    for rid in (128, 131):
        original = next(r.body for r in rows if r.kind == b'wctb' and r.rid == rid)
        require(original == bytes.fromhex('000000000000000400000000000000000001000000000000000200000000000000030000000000000004ffffffffffff'), 'original window colour resource')
        require((folder/f'windowstate-native-wctb{rid}.bin').read_bytes() == original, 'native window colour resource')
    pm = (folder/'windowstate-reference-show-after-windowpm.bin').read_bytes()
    require(len(pm) == 50, 'window PixMap extent')
    top, left, bottom, right = struct.unpack('>4h', pm[6:14])
    port = captured['reference', 'show', 'after']['window']
    pt, pl, pb, pr = struct.unpack('>4h', port[16:24])
    rect = (pl-left, pt-top, pr-left, pb-top)
    require(rect == (160, 150, 480, 350), 'measured client rectangle')
    expected = bytearray(640*480)
    for y in range(rect[1], rect[3]):
        expected[y*640+rect[0]:y*640+rect[2]] = bytes([255])*(rect[2]-rect[0])
    for label, phase in (('move','before'), ('move','after'), ('show','before'), ('show','after')):
        pixels = (folder/f'windowstate-native-{label}-{phase}-logical.bin').read_bytes()
        require(pixels == (expected if (label, phase) == ('show','after') else bytes(640*480)), 'native content clear / no outside writes')
    for name in ('physical', 'hardware'):
        a, b = ((folder/f'windowstate-reference-move-{phase}-{name}.bin').read_bytes() for phase in ('before', 'after'))
        require(len(a) == (307200 if name == 'physical' else 1024) and a == b, 'move physical preservation')
    physical = (folder/'windowstate-reference-show-after-physical.bin').read_bytes()
    require(len(physical) == 307200, 'reference physical extent')
    mouse = fields(one(reference, r'WP_PHYSICAL label=show phase=after (.*)'))['mouse']
    my, mx = mouse >> 16, mouse & 65535
    # This measured software-arrow capture occupies RawMouse minus (1,1).
    # Check its complete 16x16 pattern, not an arbitrary masked rectangle.
    # Native hardware cursor acceptance is separate.
    differences = 0
    for y in range(rect[1], rect[3]):
        for x in range(rect[0], rect[2]):
            pixel = physical[y*640+x]
            if pixel != expected[y*640+x]:
                require(mx-1 <= x < mx+15 and my-1 <= y < my+15 and pixel == 0,
                        'unexplained client pixel mismatch')
                differences += 1
    cursor = bytes(physical[y*640+x] for y in range(my-1, my+15)
                   for x in range(mx-1, mx+15))
    require(differences == 43 and hashlib.sha256(cursor).hexdigest() ==
            'ae24d8f12f95437a2fc9341131eebe30967f0fc5eaa09bdd64104e3c88f16317',
            'measured software arrow pattern')
    active_before = fields(one(native, r'WP_NATIVE label=show phase=before (.*)'))
    active_after = fields(one(native, r'WP_NATIVE label=show phase=after (.*)'))
    state = fields(one(native, r'WP_STATE label=show phase=after (.*)'))
    require(active_before['active'] == 0 and active_after['active'] == state['palette'] and
            active_after['seed'] == active_before['seed']+1 and
            u32(captured['native','show','after']['clut']) == active_before['seed'], 'native active palette / seed allocation')
    one(native, r'WP_NEXT state=3 trap=A908 segment=9 offset=FC6 manager=WINDOW MANAGER routine=SHOWHIDE windows=(?:70|96) services=(?:124/124|132/132)')
    one(native, r'WP_DIRTY (?:pending=1 count=1 queued=0|pending=0 count=0 queued=1) rect=160/150/480/350')
    one(native, r'WP_COUNTS app=34/130788 overlay=31/80650 prep=64/81222 resources=244')
    print(f'PASS paired window palette state: 256 colours, exact client clear, {differences} explained Mac cursor pixels; next=SHOWHIDE')


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('reference', type=Path)
    p.add_argument('native', type=Path)
    p.add_argument('--reference-status', type=int, required=True)
    p.add_argument('--native-status', type=int, required=True)
    p.add_argument('--folder', type=Path, default=Path('tmp'))
    p.add_argument('--resource', type=Path, default=Path('tmp/runtime-data/Alone In The Dark'))
    a = p.parse_args()
    check(a.reference.read_text(), a.native.read_text(), a.reference_status, a.native_status, a.folder, a.resource)
