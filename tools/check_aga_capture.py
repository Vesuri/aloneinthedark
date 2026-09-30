#!/usr/bin/env python3
"""Independently decode native AGA buffers; memory evidence, not rendered video."""
import argparse
import hashlib
from pathlib import Path
import re
import struct


def require(ok, message):
    if not ok:
        raise ValueError(message)


def read(folder, name, size):
    data = (folder / name).read_bytes()
    require(len(data) == size, name + ' extent')
    return data


def check_frame(folder, prefix, source, clut, left, top, front, transfer):
    planes = read(folder, prefix + '-planes.bin', 64000)
    for y in range(200):
        for x in range(320):
            pixel = sum(((planes[y*320+p*40+x//8] >> (7-x%8)) & 1) << p for p in range(8))
            require(pixel == source[(y+top)*640+x+left], f'{prefix} pixel {x},{y}')
    copper = read(folder, prefix + '-copper.bin', 2248)
    moves = list(struct.iter_unpack('>HH', copper))
    require(0 < front < 0x200000-64000, 'bitmap must fit chip memory')
    for p in range(8):
        hi, lo = moves[p*2:p*2+2]
        require(hi[0] == 0xe0+p*4 and lo[0] == 0xe2+p*4, 'plane pointer registers')
        require((hi[1] << 16 | lo[1]) == front+p*40, 'plane pointer values')
    rgb = [[0, 0, 0] for _ in range(256)]
    writes = set()
    bank = low = None
    for reg, value in moves[32:-1]:
        if reg == 0x106:
            require(value & 0x1dff == 0xc60, 'BPLCON3 control')
            bank, low = value >> 13, bool(value & 0x200)
        else:
            require(bank is not None and 0x180 <= reg <= 0x1be and not reg%2, 'palette register')
            pen = bank*32+(reg-0x180)//2
            require((pen, low) not in writes and value < 4096, 'duplicate/invalid colour write')
            writes.add((pen, low))
            for channel in range(3):
                nibble = value >> ((2-channel)*4) & 15
                rgb[pen][channel] |= nibble << (0 if low else 4)
    require(len(writes) == 512 and moves[-2] == (0x106, 0xc60)
            and moves[-1] == (0xffff, 0xfffe), 'complete palette and terminator')
    for i in range(256):
        values = struct.unpack_from('>3H', clut, 10+i*8)
        require(rgb[i] == [transfer[v] for v in values], f'{prefix} palette {i}')
    return planes


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=['startup', 'fixture'])
    parser.add_argument('log', type=Path)
    parser.add_argument('--status', type=int, required=True)
    parser.add_argument('--folder', type=Path, default=Path('tmp'))
    args = parser.parse_args()
    log = args.log.read_text()
    require(args.status == 0 and not re.search(r'FAIL|[Tt]imeout|[Tt]imed out|Error|Protocol error', log), 'run completion')
    require('[Inferior 1 (Remote target) detached]' in log, 'observer detach')
    transfer = read(args.folder, 'video-transfer-lut16.bin', 65536)
    require(hashlib.sha256(transfer).hexdigest() == 'bf0a6433c155a61989e5dc0571bae1357066ab476a24d0afaf2e2aa7094fe2aa', 'reference transfer identity')
    if args.mode == 'startup':
        require(log.count('PASS AGA startup queued and VBI-published next=UNIONRECT') == 1, 'startup positive control')
        m = re.search(r'AGA_ACTIVE front=([0-9A-F]+) back=([0-9A-F]+) copper=([0-9A-F]+) crop=160/150 queued=1 presented=1 pending=0 line=(\d+) late=0', log)
        require(m and int(m[4]) < 72, 'startup publication')
        source = read(args.folder, 'aga-startup-logical.bin', 307200)
        clut = read(args.folder, 'aga-startup-clut.bin', 2056)
        expected = bytearray(307200)
        for y in range(150,350):
            expected[y*640+160:y*640+480] = bytes([255])*320
        # ShowHide now clears the measured exposed background after the client
        # frame is queued; it leaves every viewport pixel and palette unchanged.
        from check_showhide import spans
        region = (args.folder/'showhide-reference-showhide-after-update.bin').read_bytes()
        for y,left,right in spans(region):
            expected[y*640+left:y*640+right] = bytes([255])*(right-left)
        require(source == expected, 'exact client/background clears, no other writes')
        reference_clut = read(args.folder, 'windowstate-reference-show-after-clut.bin', 2056)
        require(clut[4:] == reference_clut[4:], 'reference logical palette, excluding process-local seed')
        hardware = read(args.folder, 'windowstate-reference-show-after-hardware.bin', 1024)
        for i in range(256):
            values = struct.unpack_from('>3H', clut, 10+i*8)
            rgb = bytes(transfer[v] for v in values)
            require(hardware[i*4+1:i*4+4] == rgb, 'reference video palette')
        check_frame(args.folder, 'aga-startup-active', source, clut, 160, 150, int(m[1],16), transfer)
        for suffix, size in [('planes',64000),('copper',2248)]:
            require(read(args.folder,'aga-startup-queued-'+suffix+'.bin',size) == read(args.folder,'aga-startup-active-'+suffix+'.bin',size), 'queued/published bytes')
    else:
        require(log.count('PASS AGA fixture frames=5 restored=1') == 1, 'fixture positive control')
        states = re.findall(r'AGA_FIX stage=(\d+) front=([0-9A-F]+) copper=([0-9A-F]+) crop=(\d+)/(\d+) pending=0 line=(\d+) late=0', log)
        require(len(states) == 5, 'five completed publications')
        source = bytearray((x*37+y*71+(x^y)) & 255 for y in range(480) for x in range(640))
        clut = bytearray(struct.pack('>IHH',0,0x8000,255))
        for i in range(256):
            clut.extend(struct.pack('>4H',0x800,i*257,(255-i)*257,((i*71)&255)*257))
        previous = None
        for stage, state in enumerate(states,1):
            n, front, copper, left, top, line = state
            left, top = int(left), int(top)
            require(int(n) == stage and (left,top) == ((161,151) if stage == 5 else (160,150)) and int(line)<72, 'frame identity/timing')
            if stage in (2,3):
                t,l,b,r,color = (153,195,155,229,0x69) if stage == 2 else (180,400,183,404,0xc3)
                for y in range(t,b):
                    source[y*640+l:y*640+r] = bytes([color])*(r-l)
            if stage == 4:
                clut[10+42*8:12+42*8] = bytes([17,17])
            prefix = f'aga-fixture-{stage}'
            require(read(args.folder,prefix+'-source.bin',307200) == source, 'actual fixture source')
            require(read(args.folder,prefix+'-clut.bin',2056) == clut, 'actual fixture CLUT')
            planes = check_frame(args.folder,prefix,source,clut,left,top,int(front,16),transfer)
            if stage == 4:
                require(planes == previous, 'palette-only pixel preservation')
            previous = planes
        require(states[0][1:3] == states[2][1:3] == states[4][1:3]
                and states[1][1:3] == states[3][1:3] and states[0][1] != states[1][1]
                and states[0][2] != states[1][2], 'double buffer alternation')
        require('AGA_RESTORED stage=99 done=1 error=0 front=0 back=0 copper=0' in log, 'released display allocations')
    print('PASS AGA '+args.mode+': exact pixels, eight plane pointers, 256 RGB24 colours and VBI publication')


if __name__ == '__main__':
    main()
