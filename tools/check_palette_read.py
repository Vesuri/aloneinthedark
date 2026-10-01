#!/usr/bin/env python3
"""Check native AGA colour-RAM readback; this is not host-video acceptance."""
import argparse
import hashlib
from pathlib import Path
import re
import struct

from check_aga_capture import check_frame, read, require


def check(log, status, folder):
    require(status == 0 and not re.search(r'FAIL|[Tt]imeout|[Tt]imed out|Error', log),
            'normal diagnostic completion')
    require(log.count('PASS native hardware palette capture and menu continuation') == 1,
            'positive readback and continuation control')
    require('[Inferior 1 (Remote target) detached]' in log, 'observer detached')
    row = re.search(r'PALETTE_READ done=1 banks=8 frame=13 queued=13 presented=13 pending=0 '
                    r'beam=(\d+) dmaBefore=([0-9A-F]+) dmaAfter=([0-9A-F]+) '
                    r'ticks=(\d+) start=(\d+) book=0', log)
    require(row is not None, 'stable menu frame identity')
    require(int(row[1]) < 72 and 0 <= int(row[4])-int(row[5]) < 900,
            'read before visible scanlines and menu expiry')
    before, after = int(row[2], 16), int(row[3], 16)
    require(before & 0x3ff == after & 0x3ff and before & 0x380 == 0x380,
            'copper/bitplane/master DMA enabled and preserved')
    position = re.search(r'PALETTE_STORAGE front=([0-9A-F]+) left=160 top=150', log)
    require(position is not None, 'menu viewport')
    high = struct.unpack('>256H', read(folder, 'palette-read-high.bin', 512))
    low = struct.unpack('>256H', read(folder, 'palette-read-low.bin', 512))
    require(all(v < 4096 for v in high+low), 'valid RGB12 reads, no genlock flags')
    moves = list(struct.iter_unpack('>HH', read(folder, 'palette-read-copper.bin', 2248)))
    for bank in range(8):
        at = 32+bank*66
        require(moves[at] == (0x106, 0xc60 | bank << 13), 'high bank select')
        require(moves[at+33] == (0x106, 0xe60 | bank << 13), 'low bank select')
        for pen in range(32):
            require(moves[at+1+pen] == (0x180+pen*2, high[bank*32+pen]),
                    f'hardware high nibble bank={bank} pen={pen}')
            require(moves[at+34+pen] == (0x180+pen*2, low[bank*32+pen]),
                    f'hardware low nibble bank={bank} pen={pen}')
    require(len(set(zip(high, low))) > 16 and high != low,
            'nonuniform colours and distinct high/low readback')
    transfer = read(folder, 'video-transfer-lut16.bin', 65536)
    require(hashlib.sha256(transfer).hexdigest() ==
            'bf0a6433c155a61989e5dc0571bae1357066ab476a24d0afaf2e2aa7094fe2aa',
            'reference colour-transfer identity')
    check_frame(folder, 'palette-read', read(folder, 'palette-read-screen.bin', 307200),
                read(folder, 'palette-read-clut.bin', 2056), 160, 150,
                int(position[1], 16), transfer)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('log', type=Path)
    parser.add_argument('--status', type=int, required=True)
    parser.add_argument('--folder', type=Path, default=Path('tmp'))
    args = parser.parse_args()
    check(args.log.read_text(), args.status, args.folder)
    print('PASS AGA hardware readback: 256 RGB24 colours match copper and logical CLUT; '
          'exact menu pixels and original continuation; host video unverified')


if __name__ == '__main__':
    main()
