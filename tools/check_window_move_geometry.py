#!/usr/bin/env python3
"""Compare the original hidden game-window move with the native service."""
import argparse
import hashlib
from pathlib import Path
import struct
from check_choice_services import one
from check_getgworld import fields
from resource_fork import read_resource_fork


def require(ok, message):
    if not ok:
        raise ValueError(message)


def check(reference, native, reference_status, native_status, folder, resource):
    code = next(r.body for r in read_resource_fork(resource) if r.kind == b'CODE' and r.rid == 7)
    original = code[0x4890:0x48a4]
    require(hashlib.sha256(original).hexdigest() == '91e8cde0ff70b45c93ea24bf275399b06ea38786a44b03df25fcf63cfd5f90a0', 'original Engine move bytes')
    snapshots = {}
    for side, text, status, marker, ending in (
        ('reference', reference, reference_status, 'PASS original colour-window move geometry', 'Exited via the debugger'),
        ('native', native, native_status, 'PASS native window move geometry', '[Inferior 1 (Remote target) detached]')):
        require(status == 0 and all(s not in text for s in ('FAIL', 'Error in', 'LUA ERROR', 'TIMEOUT', 'Program received signal')), side+' run')
        require(text.count(marker) == text.count(ending) == 1, side+' normal completion')
        require(bytes.fromhex(one(text, r'WP_BYTES label=move data=([0-9A-F]+)')) == original, side+' live bytes')
        entered = fields(one(text, r'WP_ENTER label=move (.*)'))
        returned = fields(one(text, r'WP_RETURN label=move (.*)'))
        require(returned['sp'] == entered['sp']+10, side+' argument cleanup')
        args = bytes.fromhex(one(text, r'WP_ENTER label=move .*args=([0-9A-F]+) .*'))
        require(args[0] == 0 and args[2:6] == bytes.fromhex('009600a0'), side+' measured positioning arguments')
        for phase, pm_bounds in (('before', (-168,-82,312,558)), ('after', (-150,-160,330,480))):
            prefix = folder/f'windowmove-{side}-move-{phase}'
            window = Path(str(prefix)+'-window.bin').read_bytes()
            pm = Path(str(prefix)+'-windowpm.bin').read_bytes()
            require(len(window) == 156 and len(pm) == 50, side+' record sizes')
            require(struct.unpack_from('>4h', window, 16) == (0,0,200,320) and window[110] == 0, side+' unchanged hidden local port')
            require(struct.unpack_from('>4h', pm, 6) == pm_bounds, side+' translated pixel coordinates')
            snapshots[side,phase] = (window,pm)
            for name in ('visibility','clip','structure','content','update'):
                region = Path(str(prefix)+'-'+name+'.bin').read_bytes()
                expected = '000a800180017fff7fff' if name == 'clip' else (
                    '000affee004effee004e' if phase == 'after' and name in ('structure','content','update') else '000a0000000000000000')
                require(region == bytes.fromhex(expected), side+'/'+phase+'/'+name+' complete region')
        before, after = snapshots[side,'before'], snapshots[side,'after']
        require(before[0] == after[0] and before[1][:6]+before[1][14:] == after[1][:6]+after[1][14:], side+' only PixMap origin changed')
    print('PASS paired hidden colour-window move: live original bytes, arguments, coordinates and all ten complete region snapshots')


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
