#!/usr/bin/env python3
"""Check the original hidden SetWTitle call and CPU-executed font measurements."""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import unittest
from check_choice_services import one
from check_getgworld import fields
from check_ctable import preserved
from resource_fork import read_resource_fork


def original(path):
    rows = read_resource_fork(path)
    code = next(r.body for r in rows if r.kind == b'CODE' and r.rid == 9)[0x128c:0x1298]
    if hashlib.sha256(code).hexdigest() != 'e2db8225b409eb6628d60db59a5148cd1b2229bd52caa216af43e59e794479b0':
        raise ValueError('original title instructions')
    wind = next(r.body for r in rows if r.kind == b'WIND' and r.rid == 131)
    if wind != bytes.fromhex('e0c0e0c01f401f40000200000000000000000a4e65772057696e646f77'):
        raise ValueError('original background window')
    return code, wind[18:]


def check(text, status, folder, code, initial_title):
    if status != 0 or any(x in text for x in ('FAIL', 'Error in', '[LUA ERROR]', 'timeout', 'unknown command')):
        raise ValueError('failed title observer')
    for marker in ('ARM title dispatcher bytes=2f0a2f02246f000a',
                   'PASS original SetWTitle capture', 'PASS title system-font widths',
                   'Exited via the debugger'):
        if text.count(marker) != 1:
            raise ValueError('title completion')
    enter = fields(one(text, r'TITLE_ENTER (.*)'))
    returned = fields(one(text, r'TITLE_RETURN (.*)'))
    preserved(enter, returned, 8)
    live = bytes.fromhex(one(text, r'TITLE_BYTES data=([0-9A-F]+)'))
    if len(live) != len(code) or live[:6]+live[10:] != code[:6]+code[10:] or int.from_bytes(live[6:10], 'big') != enter['string']:
        raise ValueError('live instructions / relocated string')
    def load(name):
        return (folder/('title-reference-'+name+'.bin')).read_bytes()
    requested = load('input')
    if requested != b'\x05Hider' or requested != load('input-after'):
        raise ValueError('original title request / input preservation')
    before = fields(one(text, r'TITLE_STATE phase=before (.*)'))
    after = fields(one(text, r'TITLE_STATE phase=after (.*)'))
    if before['window'] != enter['window'] or not all(before[k] for k in ('window', 'titleHandle', 'titleBody')) or before['visible'] != 0 or before['length'] != 10 or before['width'] != 85:
        raise ValueError('initial title state')
    if after != dict(before, length=5, width=34):
        raise ValueError('title state mutation')
    window = load('before-window')
    if len(window) != 156 or int.from_bytes(window[134:138], 'big') & 0xffffff != before['titleHandle'] or window[138:140] != b'\x00\x55' or window[110] != 0:
        raise ValueError('window record extent / fields')
    changed = bytearray(window)
    changed[138:140] = b'\x00\x22'
    if load('after-window') != changed or load('before-title') != initial_title or load('after-title') != requested:
        raise ValueError('title record effects')
    for kind, size in (('wmgr', 108), ('vis', 10), ('clip', 10), ('structure', 10), ('content', 10), ('update', 10)):
        a, b = load('before-'+kind), load('after-'+kind)
        if len(a) != size or a != b:
            raise ValueError('changed state: '+kind)
    ports = fields(one(text, r'TITLE_PORT phase=before (.*)'))
    if not ports['current'] or ports['current'] != ports['wmgr'] or fields(one(text, r'TITLE_PORT phase=after (.*)')) != ports:
        raise ValueError('port preservation')
    if fields(one(text, r'TITLE_WIDTH_CALL (.*)')) != dict(trap=0xa88c, font=0, face=0, size=0, string=enter['string']):
        raise ValueError('title font selection')
    if fields(one(text, r'TITLE_SIZE (.*)')) != dict(size=6, mem=0):
        raise ValueError('title allocation extent')
    expected_program = b''.join(struct.pack('>5H', 0x558f, 0x3f3c, c, 0xa88d, 0x36df) for c in range(32, 127))
    if load('width-program') != expected_program:
        raise ValueError('CPU fixture inputs / instructions')
    inp = fields(one(text, r'TITLE_WIDTH_INPUT (.*)'))
    end = fields(one(text, r'TITLE_WIDTH_DONE (.*)'))
    if (inp['font'], inp['face'], inp['size']) != (0, 0, 0) or end != dict(sp=inp['sp'], output=inp['output']+190):
        raise ValueError('CPU fixture completion / font')
    raw = load('ascii-widths')
    if len(raw) != 190:
        raise ValueError('font advances extent')
    widths = struct.unpack('>95H', raw)
    if not all(0 < w <= 14 for w in widths) or widths[0] != 4 or widths[16] != 8:
        raise ValueError('font advances / prior metrics contract')
    installed=json.loads((Path(__file__).resolve().parents[1]/'resources/startup-fonts.json').read_text())['faces'][0]
    if (installed['family'],installed['size'],installed['style']) != (0,12,0) or installed['printableWidths'] != list(widths):
        raise ValueError('installed advances differ from reference')
    for title, expected in ((initial_title, 85), (requested, 34)):
        if sum(widths[c-32] for c in title[1:]) != expected:
            raise ValueError('measured string advance')
    return widths


def check_native(text, status, folder, code, initial_title):
    if status != 0 or any(x in text for x in ('FAIL', 'Error in', 'timeout')):
        raise ValueError('failed native title observer')
    for marker in ('ARM native title original bytes', 'PASS native title capture',
                   'PASS native title next=NEWPALETTE original-MDRV=absent'):
        if text.count(marker) != 1:
            raise ValueError('native title completion')
    enter = fields(one(text, r'TITLE_ENTER (.*)'))
    returned = fields(one(text, r'TITLE_RETURN (.*)'))
    preserved(enter, returned, 8)
    live = bytes.fromhex(one(text, r'TITLE_BYTES data=([0-9A-F]+)'))
    if len(live) != len(code) or live[:6]+live[10:] != code[:6]+code[10:] or int.from_bytes(live[6:10], 'big') != enter['string']:
        raise ValueError('native live title instructions')
    def load(phase, kind):
        return (folder/('title-native-'+phase+'-'+kind+'.bin')).read_bytes()
    before = fields(one(text, r'TITLE_STATE phase=before (.*)'))
    after = fields(one(text, r'TITLE_STATE phase=after (.*)'))
    if before['window'] != enter['window'] or not all(before[k] for k in ('window', 'titleHandle', 'titleBody')) or before['visible'] != 0 or before['length'] != 10 or before['width'] != 85:
        raise ValueError('native initial title')
    if after != dict(before, length=5, width=34):
        raise ValueError('native title mutation')
    a = load('before', 'window')
    if len(a) != 156 or int.from_bytes(a[134:138], 'big') != before['titleHandle'] or a[138:140] != b'\x00\x55' or a[110] != 0:
        raise ValueError('native title record')
    changed = bytearray(a); changed[138:140] = b'\x00\x22'
    if load('after', 'window') != changed:
        raise ValueError('native title record effects')
    for phase, title in (('before', initial_title), ('after', b'\x05Hider')):
        if load(phase, 'title') != title or load(phase, 'title') != (folder/('title-reference-'+phase+'-title.bin')).read_bytes():
            raise ValueError('paired title contents')
        if fields(one(text, r'TITLE_NATIVE_SIZE phase='+phase+r' (.*)')) != dict(size=len(title)):
            raise ValueError('native owned title extent')
    for name in ('input', 'input-after'):
        if (folder/('title-native-'+name+'.bin')).read_bytes() != b'\x05Hider':
            raise ValueError('native title input preservation')
    for kind, size in (('wmgr',108), ('screen',307200), ('vis',10), ('clip',10), ('structure',10), ('content',10), ('update',10)):
        a,b = load('before',kind),load('after',kind)
        if len(a) != size or a != b:
            raise ValueError('native changed state: '+kind)
    ports = fields(one(text, r'TITLE_PORT phase=before (.*)'))
    if not ports['current'] or ports['current'] != ports['wmgr'] or fields(one(text, r'TITLE_PORT phase=after (.*)')) != ports:
        raise ValueError('native title port preservation')
    one(text, r'TITLE_NEXT state=3 trap=AA91 selector=FFFFFFFF segment=5 offset=201C manager=PALETTE MANAGER routine=NEWPALETTE windows=\d+ services=(\d+/\d+)')


class Checks(unittest.TestCase):
    def test_reject_incomplete(self):
        for status in (None, 124, 0):
            with self.assertRaises(ValueError):
                check('PASS original SetWTitle capture', status, Path('tmp'), b'', b'')


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('log', type=Path, nargs='?')
    p.add_argument('--status', type=int)
    p.add_argument('--folder', type=Path, default=Path('tmp'))
    p.add_argument('--resource', type=Path, default=Path('tmp/runtime-data/Alone In The Dark'))
    p.add_argument('--selftest', action='store_true')
    p.add_argument('--native', action='store_true')
    a = p.parse_args()
    if a.selftest:
        unittest.main(argv=['check_window_title'], exit=True)
    code, title = original(a.resource)
    (check_native if a.native else check)(a.log.read_text(), a.status, a.folder, code, title)
    print('PASS '+('paired native hidden title contract' if a.native else 'original hidden title contract and 95 printable system-font advances'))
