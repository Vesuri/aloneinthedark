#!/usr/bin/env python3
"""Validate the original default-palette binding and unchanged device state."""
import argparse
import hashlib
from pathlib import Path
import re
import unittest
from resource_fork import read_resource_fork
from check_getgworld import fields
from check_choice_services import one
from check_ctable import preserved


def original(path):
    code = next(r.body for r in read_resource_fork(path)
                if r.kind == b'CODE' and r.rid == 7)[0x1166:0x1174]
    if hashlib.sha256(code).hexdigest() != 'a37e6695ed61b794457a22240ae74b278380251f2205ec46b1001a7afa0c7a82':
        raise ValueError('original SetPalette bytes')
    return code


def check(text, status, folder, code):
    if status != 0 or any(x in text for x in ('FAIL', 'Error in', '[LUA ERROR]', 'timeout', 'unknown command')):
        raise ValueError('failed observer')
    for marker in ('ARM setpalette dispatcher bytes=2f0a2f02246f000a',
                   'PASS original SetPalette binding capture', 'Exited via the debugger'):
        if text.count(marker) != 1:
            raise ValueError('completion')
    if bytes.fromhex(one(text, r'SET_BYTES data=([0-9A-F]+)')) != code:
        raise ValueError('live original bytes')
    enter = fields(one(text, r'SET_ENTER (.*)'))
    returned = fields(one(text, r'SET_RETURN (.*)'))
    preserved(enter, returned, 10)
    before = fields(one(text, r'SET_STATE phase=before (.*)'))
    after = fields(one(text, r'SET_STATE phase=after (.*)'))
    if before != after or not all(before.values()):
        raise ValueError('state identities')
    args = bytes.fromhex(one(text, r'SET_ENTER .*args=([0-9A-F/]+) .*').replace('/', ''))
    # Boolean occupies the high byte; the low byte is undefined stack padding.
    if len(args) != 10 or args[0] != 1 or int.from_bytes(args[2:6], 'big') != before['palette'] or args[6:] != b'\xff'*4:
        raise ValueError('original arguments')
    def load(phase, kind):
        return (folder / ('setpalette-reference-' + phase + '-' + kind + '.bin')).read_bytes()
    palette = load('before', 'palette')
    if len(palette) != 4112 or palette[:12] != bytes.fromhex('010000000000000200000000') or int.from_bytes(palette[12:16], 'big') != before['private']:
        raise ValueError('palette header/extent')
    changed = bytearray(palette)
    changed[6] = 0xe0
    if load('after', 'palette') != changed:
        raise ValueError('palette binding mutation')
    for kind, size in (('private', 4), ('gd', 62), ('pm', 50), ('clut', 2056), ('physical', 307200), ('hardware', 1024)):
        a, b = load('before', kind), load('after', kind)
        if len(a) != size or a != b:
            raise ValueError('changed device/private state: ' + kind)
    if load('before', 'private') != bytes(4) or (folder/'setpalette-reference-private.bin').read_bytes() != bytes(4):
        raise ValueError('private contents')
    if fields(one(text, r'SET_PRIVATE_SIZE (.*)')) != {'size': 4, 'mem': 0}:
        raise ValueError('private extent')
    for phase, default in (('before', 0), ('after', before['palette'])):
        a = fields(one(text, r'SET_ADDRESS phase=' + phase + r' (.*)'))
        if a != dict(base=0xf9000a00, logical=default, physical=0, low=default, default=default):
            raise ValueError('default binding/address translation')
        p = one(text, r'SET_PHYSICAL phase=' + phase + r' pc=([0-9A-F]+) base=F9000A00 bytes=307200 hardware=256')
        if phase == 'before' and int(p, 16) != 0xdd60:
            raise ValueError('physical capture checkpoint')
    q = fields(one(text, r'SET_QUERY (.*)'))
    b = fields(one(text, r'SET_BINDING (.*)'))
    if q['argument'] != 0xffffffff or q['result'] != 0 or q['opcode'] != 0xaa96:
        raise ValueError('GetPalette input')
    if b != dict(palette=before['palette'], result=before['palette'], sp=q['sp']+4, expected=q['sp']+4, opcode=0xaa96):
        raise ValueError('GetPalette binding')


def check_native(text, status, folder, code):
    if status != 0 or any(x in text for x in ('FAIL', 'Error in', 'timeout')):
        raise ValueError('failed native observer')
    for marker in ('ARM native SetPalette original bytes', 'PASS native SetPalette capture',
                   'PASS native SetPalette original-MDRV=absent'):
        if text.count(marker) != 1:
            raise ValueError('native completion')
    if bytes.fromhex(one(text, r'SET_BYTES data=([0-9A-F]+)')) != code:
        raise ValueError('native live original bytes')
    enter = fields(one(text, r'SET_ENTER (.*)'))
    returned = fields(one(text, r'SET_RETURN (.*)'))
    preserved(enter, returned, 10)
    before = fields(one(text, r'SET_NATIVE_STATE phase=before (.*)'))
    after = fields(one(text, r'SET_NATIVE_STATE phase=after (.*)'))
    if before['binding'] != 0 or after != dict(before, binding=before['palette']):
        raise ValueError('native binding/identity')
    args = bytes.fromhex(one(text, r'SET_ENTER .*args=([0-9A-F/]+) .*').replace('/', ''))
    if len(args) != 10 or args[0] != 1 or int.from_bytes(args[2:6], 'big') != before['palette'] or args[6:] != b'\xff'*4:
        raise ValueError('native request')
    def load(phase, kind):
        return (folder / ('setpalette-native-' + phase + '-' + kind + '.bin')).read_bytes()
    palette = load('before', 'palette')
    if len(palette) != 4112 or palette[:12] != bytes.fromhex('010000000000000200000000') or int.from_bytes(palette[12:16], 'big') != before['private']:
        raise ValueError('native palette extent/header')
    changed = bytearray(palette)
    changed[6] = 0xe0
    if load('after', 'palette') != changed:
        raise ValueError('native palette mutation')
    for kind, size in (('private', 4), ('gd', 62), ('pm', 50), ('clut', 2056), ('physical', 307200), ('pending', 1024), ('copper', 2248)):
        a, b = load('before', kind), load('after', kind)
        if len(a) != size or a != b:
            raise ValueError('native changed device/private state: ' + kind)
    if load('before', 'private') != bytes(4):
        raise ValueError('native private block')
    if fields(one(text, r'SET_NATIVE_SIZE (.*)')) != dict(palette=4112, private=4):
        raise ValueError('native allocation sizes')
    one(text, r'SET_NEXT state=3 trap=A8F6 selector=FFFFFFFF segment=13 offset=382 manager=QUICKDRAW routine=DRAWPICTURE windows=(?:101|127) services=(?:164/164|172/172)')
    for phase in ('before', 'after'):
        reference = (folder/('setpalette-reference-'+phase+'-palette.bin')).read_bytes()
        native = load(phase, 'palette')
        if len(reference) != 4112 or reference[:12]+reference[16:] != native[:12]+native[16:]:
            raise ValueError('paired palette bytes')


class Checks(unittest.TestCase):
    def test_reject_incomplete(self):
        for status in (None, 124, 0):
            with self.assertRaises(ValueError):
                check('PASS original SetPalette binding capture', status, Path('tmp'), b'')


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('log', type=Path, nargs='?')
    p.add_argument('--status', type=int)
    p.add_argument('--folder', type=Path, default=Path('tmp'))
    p.add_argument('--selftest', action='store_true')
    p.add_argument('--native', action='store_true')
    a = p.parse_args()
    if a.selftest:
        raise SystemExit(not unittest.TextTestRunner().run(unittest.defaultTestLoader.loadTestsFromTestCase(Checks)).wasSuccessful())
    try:
        code = original(Path('tmp/runtime-data/Alone In The Dark'))
        text = a.log.read_text()
        verify = check_native if a.native else check
        verify(text, a.status, a.folder, code)
        for bad, status in ((text, 124), (text, None), (text+text, 0),
                            (text.replace('data=4878FFFF', 'data=48780000'), 0),
                            (text.replace('SET_NATIVE_SIZE palette=1010', 'SET_NATIVE_SIZE palette=1000') if a.native else text.replace('opcode=AA96', 'opcode=AA90'), 0),
                            (text.replace('args=01', 'args=00'), 0),
                            (text.replace('SET_NATIVE_STATE phase=after', 'SET_NATIVE_STATE phase=wrong') if a.native else text.replace('bytes=307200', 'bytes=307199'), 0)):
            try:
                verify(bad, status, a.folder, code)
            except ValueError:
                continue
            raise ValueError('invalid capture accepted')
        print('PASS SetPalette: original bytes, request, stack/registers, default binding, private state and unchanged '+('native logical buffers/copper colours' if a.native else 'physical reference display'))
    except (OSError, ValueError, KeyError, AttributeError) as e:
        raise SystemExit('FAIL SetPalette: ' + str(e))
