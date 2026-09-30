#!/usr/bin/env python3
"""Verify the original already-realized window ActivatePalette contract."""
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
    code = next(r.body for r in read_resource_fork(resource) if r.kind == b'CODE' and r.rid == 9)[0x10fc:0x1102]
    require(hashlib.sha256(code).hexdigest() == '37df3a67690b54fed3ec5919c7018e887f19a8b44f900795abb6d548120a2370', 'original activation instructions')
    captures = {}
    for side, text, status in [('reference',reference,reference_status),('native',native,native_status)]:
        require(status == 0 and not re.search(r'FAIL|Error in|LUA ERROR|timeout|Protocol error',text,re.I),side+' run')
        marker = 'PASS original window activation calls=1' if side == 'reference' else 'PASS native window activation capture'
        require(text.count(marker) == 1 and ('Exited via the debugger' if side == 'reference' else '[Inferior 1 (Remote target) detached]') in text,side+' completion')
        label = 'label=activate ' if side == 'reference' else ''
        entered = fields(one(text,r'ACT_ENTER '+label+r'(.*)'))
        returned = fields(one(text,r'ACT_RETURN '+label+r'(.*)'))
        preserved(entered,returned,4)
        require(bytes.fromhex(one(text,r'ACT_BYTES '+label+r'data=([0-9A-F]+)')) == code,side+' live original bytes')
        args = bytes.fromhex(one(text,r'ACT_ENTER '+label+r'.*args=([0-9A-F]+) .*'))
        window = int.from_bytes(args[:4],'big')
        require(len(args) == (12 if side == 'reference' else 4) and window not in (0,0xffffffff),side+' window argument')
        tag = 'ACT_STATE label=activate' if side == 'reference' else 'ACT_NATIVE_STATE'
        before,after = [fields(one(text,tag+r' phase='+phase+r' (.*)')) for phase in ('before','after')]
        require(before == after,side+' state preservation')
        if side == 'reference':
            require(before['window'] == window,'reference window identity')
            one(text,r'ACT_SITE label=activate offset=1100 opcode=AA94')
            one(text,r'ACT_PHYSICAL label=activate phase=before pc=DD60 base=F9000A00 bytes=307200 hardware=256 mouse=[0-9A-F]+')
        else:
            require(before['binding'] == before['active'] == before['default'] == before['palette']
                    and before['updates'] == before['queued'] == 1 and before['dirty'] == before['count'] == 0,'native realized window state')
        sizes = [('palette',4112),('private',4),('window',156),('gd',62),('pm',50),('clut',2056),('physical',307200)]
        sizes += [('windowpm',50),('hardware',1024)] if side == 'reference' else [('copper',4496),('pending',1024)]
        for kind,size in sizes:
            a,b = [(folder/f'activation-{side}-activate-{phase}-{kind}.bin').read_bytes() for phase in ('before','after')]
            require(len(a) == size and a == b,side+' unchanged '+kind)
            captures[side,kind] = a
        palette = captures[side,'palette']
        require(palette[:12] == bytes.fromhex('010000000000c00200000001') and int.from_bytes(palette[12:16],'big') == before['private'],side+' palette header/owner')
        require(captures[side,'private'] == captures[side,'clut'][:4],side+' private/device seed')
        require(captures[side,'window'][110] == 1,side+' visible window')
    r,n = captures['reference','palette'],captures['native','palette']
    require(r[:12]+r[16:] == n[:12]+n[16:],'paired palette excluding private pointer')
    require(captures['reference','clut'][4:] == captures['native','clut'][4:],'paired device CLUT excluding allocated seed')
    require(native.count('PASS native window activation next-stop original-MDRV=absent') == 1,'next-stop/MDRV guard')
    one(native, r'ACT_NEXT state=3 trap=A8DF segment=4 offset=3D46 manager=UNKNOWN MANAGER routine=UNKNOWN TRAP windows=(?:249|275) services=\d+/\d+')
    print('PASS paired ActivatePalette: original bytes, stack/registers, realized binding, unchanged full palette/device/pixels/copper')


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
