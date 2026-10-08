#!/usr/bin/env python3
"""Compare a state-paired full-play viewport with original Mac display pixels."""
import argparse
from pathlib import Path
import struct
from check_menu_keyboard import require, rgb
from check_video_transfer import native as display_transfer

FIELDS = {'actor': 0, 'body': 2, 'x': 28, 'y': 30, 'z': 32,
          'alpha': 40, 'beta': 42, 'gamma': 44, 'floor': 46, 'room': 48, 'animation': 62, 'keyframe': 74, 'track': 82}

def actor_state(data):
    require(len(data) == 75616, 'A5 world capture extent')
    base = len(data)-0xb292+160
    state = {name: struct.unpack_from('>h', data, base+offset)[0]
             for name, offset in FIELDS.items()}
    state['camera'] = struct.unpack_from('>h', data, len(data)-0xcd70)[0]
    return state

def viewport(data):
    require(len(data) == 640*480*3, 'RGB capture extent')
    return b''.join(data[(y*640+160)*3:(y*640+480)*3] for y in range(150,350))

def check(args):
    original = actor_state(args.mac_world.read_bytes())
    native = actor_state((args.native/f'world-{args.sequence}.bin').read_bytes())
    require(original == native, f'actor state mismatch: Mac={original}, Amiga={native}')
    for item in args.expect:
        key, value = item.split('=', 1)
        require(key in original and original[key] == int(value), 'expected state '+item)
    mac = args.mac_pixels.read_bytes()
    require(len(mac) == 640*480*4, 'original BGRA screen extent')
    mac_rgb = bytes(channel for i in range(0,len(mac),4)
                    for channel in (mac[i+2],mac[i+1],mac[i]))
    indices = (args.native/f'screen-{args.sequence}.bin').read_bytes()
    table = (args.native/f'clut-{args.sequence}.bin').read_bytes()
    amiga = rgb(indices, table, display_transfer()[::256])
    a, b = viewport(mac_rgb), viewport(amiga)
    require(len(set(a[i:i+3] for i in range(0,len(a),3))) > 32,
            'positive rendered reference coverage')
    different = sum(a[i:i+3] != b[i:i+3] for i in range(0,len(a),3))
    require(different == 0, f'viewport: {different} differing pixels')
    if args.scanout:
        planes = args.scanout.read_bytes()
        require(len(planes) == 64000, '320x200 eight-plane scanout extent')
        physical = bytes(sum(((planes[y*320+p*40+x//8] >> (7-x%8)) & 1) << p
                             for p in range(8)) for y in range(200) for x in range(320))
        logical = b''.join(indices[(y*640+160):(y*640+480)] for y in range(150,350))
        require(physical == logical, 'physical scanout differs from paired logical frame')
    print(f'PASS fullplay frame {args.label}: paired state {original}; 64000 exact display pixels'
          + ('; physical scanout matches' if args.scanout else ''))

if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--label', required=True)
    p.add_argument('--native', type=Path, required=True)
    p.add_argument('--sequence', type=int, required=True)
    p.add_argument('--mac-world', type=Path, required=True)
    p.add_argument('--mac-pixels', type=Path, required=True)
    p.add_argument('--expect', action='append', required=True, metavar='FIELD=VALUE')
    p.add_argument('--scanout', type=Path)
    try:
        check(p.parse_args())
    except (ValueError, OSError) as error:
        raise SystemExit('FAIL fullplay frame: '+str(error))
