#!/usr/bin/env python3
"""Verify integer display transfer against exhaustive original Mac captures."""
import argparse
import hashlib
import os
from pathlib import Path
import re
import struct
import subprocess
import local_temp as tempfile
from check_choice_services import one
from check_getgworld import fields
from resource_fork import read_resource_fork
ROOT = Path(__file__).resolve().parents[1]
DIGEST = 'bf0a6433c155a61989e5dc0571bae1357066ab476a24d0afaf2e2aa7094fe2aa'


def require(ok, message):
    if not ok:
        raise ValueError(message)


def native():
    with tempfile.TemporaryDirectory(prefix='aitd-video-color-') as folder:
        exe = Path(folder)/'test'
        subprocess.run([os.environ.get('HOST_CXX', 'c++'), '-std=c++17', '-Wall',
                        '-Wextra', '-Werror', '-fsanitize=address,undefined',
                        str(ROOT/'tools/test_video_color.cpp'), '-o', str(exe)], check=True)
        result = subprocess.run([str(exe)], check=True, timeout=30, stdout=subprocess.PIPE).stdout
        require(len(result) == 65536 and hashlib.sha256(result).hexdigest() == DIGEST,
                'native complete transfer differs from measured reference')
        print('PASS integer video transfer: all 65536 RGB16 channel inputs match the reference digest')
        return result


def reference(log, status, folder, resource, transfer):
    require(status == 0 and not any(s in log for s in ('FAIL', '[LUA ERROR]', 'timeout', 'Error in')), 'reference run')
    for marker in ('PASS reference video transfer values=65536 mixed=256 CPU-SetEntries=257 stack=8',
                   'Exited via the debugger', 'VIDEO_PROGRAM bytes=AA3F4E71'):
        require(log.count(marker) == 1, 'reference completion / scratch instructions')
    code = next(r.body for r in read_resource_fork(resource) if r.kind == b'CODE' and r.rid == 9)
    for label, start, end, digest in (
        ('move', 0xf94, 0xfb4, 'ac7b10b44ab334076f90cb605411a22f4d82b7cb09e3e91470942a38dea74d5a'),
        ('show', 0x10e2, 0x10e8, 'fbb2f10eed30f3a3ccbb42f116e135a329de15963a39307a540398422a54a59c')):
        live = bytes.fromhex(one(log, r'WP_BYTES label='+label+r' data=([0-9A-F]+)'))
        require(live == code[start:end] and hashlib.sha256(live).hexdigest() == digest, 'original startup bytes')
    setup = fields(one(log, r'VIDEO_RAMP (.*)'))
    entered = [fields(s) for s in re.findall(r'^VIDEO_ENTER (.*)$', log, re.M)]
    returned = [fields(s) for s in re.findall(r'^VIDEO_BATCH (.*)$', log, re.M)]
    require(len(entered) == len(returned) == 257, 'CPU call coverage')
    require(setup['code']+2 == setup['return'] and setup['input'] == setup['sp']+8+0x1000, 'scratch layout')
    source = (folder/'video-transfer-all-input.bin').read_bytes()
    output = (folder/'video-transfer-all-output.bin').read_bytes()
    require(len(source) == 257*2048 and len(output) == 257*1024, 'capture extents')
    for batch, (e, r) in enumerate(zip(entered, returned)):
        require(e == dict(batch=batch, sp=setup['sp'], table=setup['input'], count=255, start=0)
                and r == dict(batch=batch, sp=setup['sp']+8), 'call arguments / stack cleanup')
        for i in range(256):
            k = batch*256+i
            requested = (i*256+batch,)*3 if batch < 256 else (i*257, (255-i)*257, ((i*71)%256)*257)
            require(struct.unpack_from('>4H', source, k*8) == (i, *requested), 'actual CPU input array')
            actual = struct.unpack_from('>I', output, k*4)[0] & 0xffffff
            expected = transfer[requested[0]]<<16 | transfer[requested[1]]<<8 | transfer[requested[2]]
            require(actual == expected, 'reference/native output channel mismatch')
    for phase in ('before', 'after'):
        clut = (folder/f'video-transfer-startup-show-{phase}-clut.bin').read_bytes()
        colors = (folder/f'video-transfer-startup-show-{phase}-hardware.bin').read_bytes()
        require(len(clut) == 2056 and len(colors) == 1024, 'startup palette extents')
        for i in range(256):
            rgb = struct.unpack_from('>3H', clut, 10+i*8)
            expected = transfer[rgb[0]]<<16 | transfer[rgb[1]]<<8 | transfer[rgb[2]]
            require(struct.unpack_from('>I', colors, i*4)[0] & 0xffffff == expected, 'startup palette transfer')
    print('PASS reference video transfer: 257 CPU calls, exhaustive channel inputs, mixed colours and 512 startup colours')


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--reference', type=Path)
    p.add_argument('--status', type=int)
    p.add_argument('--folder', type=Path, default=Path('tmp'))
    p.add_argument('--resource', type=Path, default=Path('tmp/runtime-data/Alone In The Dark'))
    a = p.parse_args()
    result = native()
    if a.reference:
        reference(a.reference.read_text(), a.status, a.folder, a.resource, result)
