#!/usr/bin/env python3
"""Decode native pointer DMA and all playfield colours; not rendered acceptance."""
import argparse
import hashlib
from pathlib import Path
import re
import struct
from check_aga_capture import check_frame, read, require


def check(log, status, folder, video, require_inversion=False, visual=False):
    require(status == 0 and not re.search(r'FAIL|Error in|TIMEOUT|Program received signal', log), 'normal completion')
    require(log.count('PASS native cursor fixture frames=5 restored=1') == 1
            and log.count('[Inferior 1 (Remote target) detached]') == 1, 'positive completion and detach')
    inverse_fixture = 'CURSOR_INVERSION fixture=1' in log
    require(not require_inversion or inverse_fixture, 'required cursor inversion fixture')
    if inverse_fixture:
        coverage=re.findall(r'^CURSOR_C2P verified=5 failures=0 endLine=(\d+)$',log,re.M)
        require(len(coverage)==1 and int(coverage[0])<(72 if video=='PAL' else 44), 'clean queued frames and cursor blanking deadline')
    transfer = read(folder, 'video-transfer-lut16.bin', 65536)
    require(hashlib.sha256(transfer).hexdigest() == 'bf0a6433c155a61989e5dc0571bae1357066ab476a24d0afaf2e2aa7094fe2aa', 'reference video transfer')
    states = re.findall(r'^CURSOR_FIX stage=(\d+) front=([0-9A-F]+) copper=([0-9A-F]+) sprite=([0-9A-F]+) empty=([0-9A-F]+) crop=(\d+)/(\d+) allowed=(\d+) visible=(\d+) x=(-?\d+) y=(-?\d+) hot=(-?\d+)/(-?\d+) pal=(\d+) control=([0-9A-F]+)$', log, re.M)
    require(len(states) == 5, 'five pointer publications')
    source = bytearray((x*37+y*71+(x^y)) & 255 for y in range(480) for x in range(640))
    if visual:
        ramp = bytes(x*256//320 for x in range(320))
        for y in range(150,230):
            source[y*640+160:y*640+480] = ramp
    clut = bytearray(struct.pack('>IHH', 0, 0x8000, 255))
    for i in range(256):
        clut.extend(struct.pack('>4H', 0x800, i*257, (255-i)*257, ((i*71)&255)*257))
    clut[10:16] = b'\xff'*6
    clut[2050:2056] = bytes(6)
    previous = None
    for stage, state in enumerate(states, 1):
        n, front, copper, sprite, empty, left, top, allowed, visible, x, y, hx, hy, pal, control = state
        front, copper, sprite, empty, control = (int(v, 16) for v in (front, copper, sprite, empty, control))
        n, left, top, allowed, visible, x, y, hx, hy, pal = (int(v) for v in (n, left, top, allowed, visible, x, y, hx, hy, pal))
        require(n == stage and (left, top) == ((161, 151) if stage == 5 else (160, 150)), 'frame and viewport')
        require((x, y) == [(180,180), (160,150), (460,349), (220,220), (221,221)][stage-1]
                and (hx,hy) == (3,2) and pal == (video == 'PAL'), 'pointer fixture identity')
        require(allowed == (stage != 5) and visible == (stage != 4)
                and control == (0x010f if allowed else 0x0011), 'published visibility and palette mode')
        require(0 < sprite < 0x200000-144 and 0 < empty < 0x200000-8, 'sprite chip allocations')
        if stage in (2,3):
            t,l,b,r,color = (153,195,155,229,0x69) if stage == 2 else (180,400,183,404,0xc3)
            for row in range(t,b):
                source[row*640+l:row*640+r] = bytes([color])*(r-l)
        if stage == 4:
            clut[10+42*8:12+42*8] = bytes([17,17])
        prefix = f'cursor-fixture-{stage}'
        require(read(folder,prefix+'-source.bin',307200) == source, 'complete fixture pixels')
        require(read(folder,prefix+'-clut.bin',2056) == clut, 'complete fixture colours')
        inversion = (x-hx-left,y-hy-top,[(0xa55a^(row*0x1111))&~(0xffff>>(row%5))&65535 for row in range(16)]) if inverse_fixture and allowed and visible else None
        planes = check_frame(folder,prefix,source,clut,left,top,front,transfer,control >> 8,inversion)
        previous = planes
        moves = list(struct.iter_unpack('>HH', read(folder,prefix+'-copper.bin',2248)))
        for channel in range(8):
            hi,lo = moves[16+channel*2:18+channel*2]
            require((hi[0],lo[0]) == (0x120+channel*4,0x122+channel*4), 'sprite pointer registers')
            require((hi[1]<<16|lo[1]) == (sprite if channel == 0 else sprite+72 if channel == 7 else empty), 'sprite pointer ownership')
        require(read(folder,prefix+'-empty.bin',8) == bytes(8), 'unused sprites terminated')
        dma = read(folder,prefix+'-sprites.bin',144)
        sx,sy = x-hx-left,y-hy-top
        first = max(0,-sy)
        rows = min(16-first,200-sy-first)
        hs,vs = 129+max(0,sx),(72 if pal else 44)+sy+first
        end = vs+rows
        header = bytes([vs&255,hs>>1,end&255,((vs>>8)&1)<<2|((end>>8)&1)<<1|(hs&1)]) if allowed and visible else bytes(4)
        for channel,base in ((0,0),(7,72)):
            require(dma[base:base+4] == header, 'sprite position/visibility controls')
            for row in range(rows):
                original_row = row+first
                mask = 0xffff >> (original_row%5)
                image = (0xa55a^(original_row*0x1111)) & 65535
                if not inverse_fixture:image &= mask
                mask,image = (v<<max(0,-sx)&65535 for v in (mask,image))
                a,b = struct.unpack_from('>HH',dma,base+4+row*4)
                expected = ((~image&mask,0) if channel == 0 else (0,image&mask))
                require((a,b) == expected, f'sprite {channel} row {row} black/white mask')
            require(dma[base+4+rows*4:base+8+rows*4] == bytes(4), 'sprite DMA terminator')
        if allowed:
            require(((control>>4)&15)*16+1 == 1 and (control&15)*16+12+2 == 254, 'independent sprite colour banks')
    require(states[0][1:3] == states[2][1:3] == states[4][1:3]
            and states[1][1:3] == states[3][1:3] and states[0][1] != states[1][1], 'double-buffer publication')
    inversion_text=', exact inversion' if inverse_fixture else ''
    print(f'PASS native {video} cursor: five frames, all pixels/256 colours, two DMA sprites{inversion_text}, clipping, hiding, disabling and cleanup')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('log',type=Path)
    parser.add_argument('--status',type=int,required=True)
    parser.add_argument('--video',choices=['PAL','NTSC'],required=True)
    parser.add_argument('--folder',type=Path,default=Path('tmp'))
    parser.add_argument('--inversion',action='store_true',help='require the measured XOR fixture and clean C2P verification')
    parser.add_argument('--visual',action='store_true',help='verify the AGAVISUAL colour-ramp fixture')
    args = parser.parse_args()
    try:
        check(args.log.read_text(),args.status,args.folder,args.video,args.inversion,args.visual)
    except (ValueError,OSError) as error:
        raise SystemExit('FAIL native cursor: '+str(error))
