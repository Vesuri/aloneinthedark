#!/usr/bin/env python3
"""Check the original startup's unchanged SizeWindow/MoveWindow requests."""
import argparse
import hashlib
import struct
from pathlib import Path
from check_choice_services import one, PRESERVED
from check_getgworld import fields
from resource_fork import read_resource_fork

CASES = (
    ('size', 9, 0xf78, 0xf8e, '764769fd145c2b1be228275e6c3c34b4a8bf5f494db9e18848a692dd0f8ec59e', (200, 320)),
    ('move', 7, 0x4890, 0x48a4, '91e8cde0ff70b45c93ea24bf275399b06ea38786a44b03df25fcf63cfd5f90a0', (150, 160)),
)
NAMES = ('window', 'windowpm', 'palette', 'private', 'gd', 'pm', 'clut',
         'physical', 'gray', 'front', 'visibility', 'clip', 'structure', 'content', 'update')


def require(ok, message):
    if not ok:
        raise ValueError(message)


def check(reference, native, reference_status, native_status, resource, folder):
    resources = read_resource_fork(resource)
    for side, text, status in [('reference', reference, reference_status), ('native', native, native_status)]:
        require(status == 0 and not any(x in text for x in ('FAIL', 'Error in', 'LUA ERROR', 'TIMEOUT', 'Program received signal')), side+' completion')
        marker = 'PASS original window transitions calls=2' if side == 'reference' else 'PASS native window reassert next-stop original-MDRV=absent'
        ending = 'Exited via the debugger' if side == 'reference' else '[Inferior 1 (Remote target) detached]'
        require(text.count(marker) == text.count(ending) == 1, side+' positive normal exit')
    for label, seg, start, end, digest, dimensions in CASES:
        code = next(r.body for r in resources if r.kind == b'CODE' and r.rid == seg)[start:end]
        require(hashlib.sha256(code).hexdigest() == digest, label+' original instructions')
        captures = {}
        for side, text in [('reference', reference), ('native', native)]:
            e = fields(one(text, rf'RESIZE_ENTER label={label} (.*)'))
            r = fields(one(text, rf'RESIZE_RETURN label={label} (.*)'))
            require(r['sp'] == e['sp']+10 and all(e[k] == r[k] for k in PRESERVED), side+'/'+label+' stack and preserved registers')
            args = bytes.fromhex(one(text, rf'RESIZE_ENTER label={label} .*args=([0-9A-F]+) .*'))
            require(args[0] == 0 and struct.unpack_from('>hh', args, 2) == dimensions and int.from_bytes(args[6:10], 'big'), side+'/'+label+' arguments')
            live = bytes.fromhex(one(text, rf'RESIZE_BYTES label={label} data=([0-9A-F]+)'))
            require(live == code, side+'/'+label+' live instructions')
            captures[side] = {}
            for name in NAMES + (('hardware',) if side == 'reference' else ('copper', 'pending')):
                a = (folder/f'resize-{side}-{label}-before-{name}.bin').read_bytes()
                b = (folder/f'resize-{side}-{label}-after-{name}.bin').read_bytes()
                require(a == b, side+'/'+label+' unchanged '+name)
                captures[side][name] = a
            window = captures[side]['window']
            require(len(window) == 156 and window[110] == 1 and struct.unpack_from('>4h', window, 16) == (0, 0, 200, 320), side+' visible client')
            pm = captures[side]['windowpm']
            require(struct.unpack_from('>4h', pm, 6) == (-150, -160, 330, 480), side+' live screen origin')
            require(len(captures[side]['physical']) == 307200, side+' full screen extent')
        for name in ('gray', 'visibility', 'clip', 'structure', 'content', 'update'):
            require(captures['reference'][name] == captures['native'][name], label+' paired '+name)
        require(captures['reference']['clut'][4:] == captures['native']['clut'][4:], label+' complete logical colours')
        # The native pointer is intentionally hidden; reference cursor pixels are
        # checked against the existing measured cursor image by the AGA checker.
        for y in range(150, 350):
            require(captures['native']['physical'][y*640+160:y*640+480] == bytes([255])*320, label+' unchanged black native client')
    print('PASS paired window reassert: original/live bytes, arguments, ABI, complete regions/pixels/palette preserved; '+one(native, r'RESIZE_NEXT (state=3 trap=AA14 selector=FFFFFFFF segment=12 offset=624A manager=COLOR QUICKDRAW routine=RGBFORECOLOR windows=(?:115|141) services=(?:433/433|441/441))'))


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('reference', type=Path); p.add_argument('native', type=Path)
    p.add_argument('--reference-status', type=int, required=True); p.add_argument('--native-status', type=int, required=True)
    p.add_argument('--resource', type=Path, default=Path('tmp/runtime-data/Alone In The Dark'))
    p.add_argument('--folder', type=Path, default=Path('tmp'))
    a = p.parse_args()
    check(a.reference.read_text(), a.native.read_text(), a.reference_status, a.native_status, a.resource, a.folder)
