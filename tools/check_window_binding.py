#!/usr/bin/env python3
"""Pair the original window SetPalette call with its native implementation."""
import argparse
import hashlib
from pathlib import Path
import re
from check_choice_services import one
from check_ctable import preserved
from check_getgworld import fields
from resource_fork import read_resource_fork


def require(ok, message):
    if not ok:
        raise ValueError(message)


def check(reference, native, reference_status, native_status, folder, resource):
    code = next(r.body for r in read_resource_fork(resource) if r.kind == b'CODE' and r.rid == 9)[0x10e8:0x10fc]
    require(hashlib.sha256(code).hexdigest() == '41c4b669d4c6ce8e4889fb470c9a76c753d11fe61bd4e1285be68a20b6db8a23', 'original instruction identity')
    captures = {}
    for side, text, status in [('reference', reference, reference_status), ('native', native, native_status)]:
        require(status == 0 and not re.search(r'FAIL|Error in|LUA ERROR|timeout|Protocol error', text, re.I), side+' run')
        marker = 'PASS original window SetPalette capture' if side == 'reference' else 'PASS native window SetPalette capture'
        require(text.count(marker) == 1 and ('Exited via the debugger' if side == 'reference' else '[Inferior 1 (Remote target) detached]') in text, side+' completion')
        entered = fields(one(text, r'WSET_ENTER (.*)'))
        returned = fields(one(text, r'WSET_RETURN (.*)'))
        preserved(entered, returned, 10)
        live = bytes.fromhex(one(text, r'WSET_BYTES data=([0-9A-F]+)'))
        require(len(live) == 20 and live[:6]+live[10:] == code[:6]+code[10:]
                and int.from_bytes(live[6:10], 'big') == (entered['a5']+int.from_bytes(code[6:10], 'big')) & 0xffffffff, side+' live original instructions/relocation')
        args = bytes.fromhex(one(text, r'WSET_ENTER .*args=([0-9A-F/]+) .*').replace('/', ''))
        require(len(args) == 10 and args[0] == 1, side+' update Boolean')
        palette, window = int.from_bytes(args[2:6], 'big'), int.from_bytes(args[6:10], 'big')
        require(palette != 0 and window not in (0,0xffffffff), side+' palette/window identity')
        tag = 'WSET_STATE' if side == 'reference' else 'WSET_NATIVE_STATE'
        before, after = [fields(one(text, tag+r' phase='+phase+r' (.*)')) for phase in ('before','after')]
        require(before['palette'] == palette, side+' argument palette')
        if side == 'reference':
            require(before == after, 'reference state identities')
            query = fields(one(text,r'WSET_QUERY (.*)'))
            binding = fields(one(text,r'WSET_BINDING (.*)'))
            require(query['argument'] == window and query['result'] == 0 and query['opcode'] == 0xaa96, 'GetPalette query input')
            require(binding == dict(palette=palette,result=palette,sp=query['sp']+4,expected=query['sp']+4,opcode=0xaa96), 'GetPalette actual result')
            require(fields(one(text,r'WSET_PRIVATE_SIZE (.*)')) == dict(size=4,mem=0), 'reference private allocation')
        else:
            require(before['binding'] == before['updates'] == 0 and after == dict(before,binding=palette,updates=1), 'native binding only')
            require(before['active'] == before['default'] == palette and before['queued'] == 1
                    and before['dirty'] == before['count'] == 0, 'already-realized and queued state')
        sizes = [('palette',4112),('private',4),('window',156),('gd',62),('pm',50),('clut',2056),('physical',307200)]
        sizes += [('hardware',1024)] if side == 'reference' else [('copper',4496),('pending',1024)]
        for kind, size in sizes:
            a,b = [(folder/f'windowpalette-{side}-{phase}-{kind}.bin').read_bytes() for phase in ('before','after')]
            require(len(a) == size and a == b, side+' preserved '+kind)
            captures[side,kind] = a
        p = captures[side,'palette']
        require(p[:12] == bytes.fromhex('010000000000c00200000001') and int.from_bytes(p[12:16],'big') == before['private'], side+' realized palette')
        require(captures[side,'private'] == captures[side,'clut'][:4], side+' realization seed')
        require(captures[side,'window'][110] == 1, side+' visible window')
    r,n = captures['reference','palette'],captures['native','palette']
    require(r[:12]+r[16:] == n[:12]+n[16:], 'paired complete palette excluding private pointer')
    require(captures['reference','clut'][4:] == captures['native','clut'][4:], 'paired complete logical CLUT excluding allocated seed')
    require(native.count('PASS native window binding next-stop original-MDRV=absent') == 1, 'next-stop and driver guard')
    one(native, r'WSET_NEXT state=3 trap=AA14 segment=13 offset=2BE manager=COLOR QUICKDRAW routine=RGBFORECOLOR windows=(?:101|127) services=(?:163/163|171/171)')
    print('PASS paired window SetPalette: original instructions, stack/registers, binding, full palette/CLUT and unchanged display state')


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('reference',type=Path)
    p.add_argument('native',type=Path)
    p.add_argument('--reference-status',type=int,required=True)
    p.add_argument('--native-status',type=int,required=True)
    p.add_argument('--folder',type=Path,default=Path('tmp'))
    p.add_argument('--resource',type=Path,default=Path('tmp/runtime-data/Alone In The Dark'))
    a = p.parse_args()
    check(a.reference.read_text(),a.native.read_text(),a.reference_status,a.native_status,a.folder,a.resource)
