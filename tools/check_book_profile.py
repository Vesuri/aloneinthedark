#!/usr/bin/env python3
"""Verify state-paired book batching and independently decode its AGA publication."""
import argparse
import hashlib
from pathlib import Path
import re
from check_aga_capture import check_frame, read, require
from resource_fork import read_resource_fork


def record(log, name):
    matches = re.findall(r'^' + name + r' (.*)$', log, re.M)
    require(len(matches) == 1, name + ' unique record')
    return dict(re.findall(r'(\w+)=([^ ]+)', matches[0]))


def completed(path, status):
    text = path.read_text()
    require(status == 0 and not re.search(r'FAIL|[Tt]imeout|[Tt]imed out|Error in|Protocol error', text), 'normal completion')
    require(text.count('PASS original book-fold interval column=160..150 complete') == 1
            and '[Inferior 1 (Remote target) detached]' in text, 'positive book boundary')
    begin, end = record(text, 'BOOK_BEGIN'), record(text, 'BOOK_END')
    require(begin['column'] == '160' and end['column'] == '150', 'same original loop positions')
    require(end['paints'] == '6' and end['copies'] == '1' and end['seedChanges'] == '0', 'complete drawing step')
    require(int(end['epoch']) > 0, 'running profile timer')
    return text, end


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('baseline', type=Path)
    p.add_argument('native', type=Path)
    p.add_argument('--reference', type=Path, required=True)
    p.add_argument('--reference-status', type=int, required=True)
    p.add_argument('--baseline-status', type=int, required=True)
    p.add_argument('--status', type=int, required=True)
    p.add_argument('--folder', type=Path, default=Path('tmp'))
    p.add_argument('--original', type=Path, default=Path('tmp/runtime-data/Alone In The Dark'))
    a = p.parse_args()
    codes = {r.rid: r.body for r in read_resource_fork(a.original) if r.kind == b'CODE'}
    for segment, offset, expected in [
        (12, 0x3fb4, '4eb90000046a'), (12, 0x3fd4, '4eb90000044a'),
        (12, 0x402c, '4eb9000005ba'), (12, 0x405a, '4eb9000005ba'),
        (12, 0x410a, '4eb9000005ba'), (12, 0x4162, '4eb90000046a'),
        (12, 0x4182, '4eb90000044a'), (13, 0xb42, '486effeaaa14'),
        (13, 0xc8a, '4eba000e'), (13, 0xd4e, '486efff0a8a2'),
        (4, 0x1db8, '426742a7a8ec')]:
        require(codes[segment][offset:offset+len(expected)//2].hex() == expected,
                f'original CODE {segment}+{offset:X}')
    _, before = completed(a.baseline, a.baseline_status)
    log, after = completed(a.native, a.status)
    batch = record(log, 'BOOK_BATCH')
    require(batch['active'] == '0' and batch['begun'] == batch['completed'] == '1'
            and int(batch['suppressed']) > 0, 'one complete batch')
    require(after['frames'] == '1', 'one publication')
    phases = re.findall(r'^BOOK_PHASE id=(\d+) ticks=(\d+) calls=(\d+)$', log, re.M)
    require([int(x[0]) for x in phases] == list(range(15)), 'all profile categories')
    require(phases[9][2] == '1', 'one C2P call')
    for suffix, size in [('begin-screen',307200), ('end-screen',307200),
                         ('begin-clut',2056), ('end-clut',2056),
                         ('source-clut',2056), ('destination-clut',2056)]:
        require(read(a.folder, 'book-baseline-'+suffix+'.bin', size)
                == read(a.folder, 'book-profile-'+suffix+'.bin', size), suffix+' exact before/after equality')
    source = read(a.folder, 'book-profile-source-clut.bin', 2056)
    dest = read(a.folder, 'book-profile-destination-clut.bin', 2056)
    differences = [i for i in range(256) if source[10+8*i:16+8*i] != dest[10+8*i:16+8*i]]
    require(differences == [1,15,191], 'measured palette differences')
    active = record(log, 'BOOK_ACTIVE')
    require(active['crop'] == '160/150' and active['queued'] == active['presented']
            and active['pending'] == active['late'] == '0' and int(active['line']) < 72, 'VBI publication')
    transfer = read(a.folder, 'video-transfer-lut16.bin', 65536)
    require(hashlib.sha256(transfer).hexdigest() == 'bf0a6433c155a61989e5dc0571bae1357066ab476a24d0afaf2e2aa7094fe2aa', 'reference video transfer')
    check_frame(a.folder, 'book-profile-active', read(a.folder, 'book-profile-end-screen.bin',307200),
                read(a.folder, 'book-profile-end-clut.bin',2056),160,150,int(active['front'],16),transfer)
    reference_log = a.reference.read_text()
    require(a.reference_status == 0 and 'FAIL' not in reference_log
            and reference_log.count('PASS original book frame positions=160/150') == 1
            and reference_log.count('Exited via the debugger') == 1, 'Mac reference completion')
    require(re.findall(r'BOOK_REFERENCE column=(\d+) row=640', reference_log) == ['160','150'], 'paired Mac positions')
    original_title = read(a.folder, 'copylate-reference-enter-src-pixels.bin', 652*401)
    native_title = read(a.folder, 'copylate-native-enter-src-pixels.bin', 652*401)
    for phase in ('begin','end'):
        native_pixels = read(a.folder, 'book-profile-'+phase+'-screen.bin',307200)
        reference_pixels = read(a.folder, 'book-reference-'+phase+'-screen.bin',307200)
        native_clut = read(a.folder, 'book-profile-'+phase+'-clut.bin',2056)
        reference_clut = read(a.folder, 'book-reference-'+phase+'-clut.bin',2056)
        require(native_clut[4:] == reference_clut[4:], 'Mac logical palette except process-local seed')
        differences = 0
        for y in range(200):
            for x in range(320):
                at = (y+150)*640+x+160
                if native_pixels[at] != reference_pixels[at]:
                    require(37 <= x < 285 and 184 <= y < 200
                            and original_title[y*652+x] != native_title[y*652+x],
                            'unexplained Mac book pixel difference')
                    differences += 1
        print(f'Mac {phase}: {differences} differing D6 copyright pixels; all other client pixels exact')
    improvement = 100*(1-int(after['epoch'])/int(before['epoch']))
    print(f'PASS book batching: exact logical output/palettes, 64000 AGA pixels, 256 colours; presentations {before["frames"]}->1; emulated interval {improvement:.1f}% shorter')
    print('Profile categories are nested: do not sum inclusive drawing/presentation costs.')


if __name__ == '__main__':
    main()
