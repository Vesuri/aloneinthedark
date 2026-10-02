#!/usr/bin/env python3
"""Compare four instruction-matched intro states and native AGA publication."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import struct
from check_aga_capture import check_frame, read, require

STATES = [(1, 5, 0x1c94), (2, 5, 0x1f46), (3, 13, 0x2ed4), (4, 4, 0x5220)]
ROOT = Path(__file__).resolve().parents[1]
PLACEHOLDER_RUNS = {3: [('©1992 I•Motion/Infogrames, 1994 Interplay',37,196)],
                    4: [('Music',102,58),('Conversion:',140,58),
                        ('Mathew',108,74),('Berardo',156,74),
                        ('Additional',90,98),('Artwork',151,98),('by:',201,98),
                        ('Keith',110,114),('Robinson',143,114)]}


def placeholder_policy(frame):
    # D6: owned capitals/block artwork, original Times/plain/14 spacing.
    # These are the original copyright and final-credit text runs, not a
    # screen-wide mask. The native ink must match the authored stencil exactly.
    # The original credits issue separate calls per word, each with fraction
    # $8000. Joining the words would silently change their measured spacing.
    runs = PLACEHOLDER_RUNS.get(frame,[])
    shapes=json.loads((ROOT/'resources/placeholder-font.json').read_text())['glyphs']
    metrics=(ROOT/'src/mac/Times14Metrics.h').read_text().split('advances[256]={')[1].split('};')[0]
    units=[int(x) for x in re.findall(r'\d+',metrics)]
    ink=set();areas=[]
    for text,x,baseline in runs:
        position=32768
        for byte in text.encode('mac_roman'):
            end=position+units[byte]*76544;cell=end//65536-position//65536
            shape=shapes[bytes([byte]).decode('mac_roman').upper()]
            columns=[i for i in range(5) if any(row&(16>>i) for row in shape)]
            if columns and cell>1:
                lo,hi=min(columns),max(columns)+1;width=min(hi-lo,cell-1)
                for row in range(10):
                    for col in range(width):
                        if shape[row*7//10]&(16>>(lo+col*(hi-lo)//width)):
                            ink.add((x+position//65536+col,baseline-10+row))
            position=end
        areas.append((x-2,baseline-12,x+position//65536+2,baseline+4))
    return ink,areas


def explained_placeholder(frame,pixels,original,differences):
    ink,areas=placeholder_policy(frame)
    require(areas, 'no placeholder exception for this frame')
    for left,top,right,bottom in areas:
        for y in range(top,bottom):
            for x in range(left,right):
                index=(y+150)*640+x+160
                # The artwork also uses pen 26. Unchanged reference pixels are
                # valid background; every new ink pixel must belong to a glyph,
                # and every authored glyph pixel must actually be present.
                require(pixels[index]==26 if (x,y) in ink else pixels[index]!=26 or original[index]==26, f'frame {frame} owned glyph stencil at {x},{y}')
    for x,y in differences:
        index=(y+150)*640+x+160
        require(26 in (pixels[index],original[index]) and any(l<=x<r and t<=y<b for l,t,r,b in areas), f'frame {frame} non-glyph difference at {x},{y}')


def capture(log, status, side):
    require(status == 0 and not re.search(r'FAIL|LUA ERROR|Error in|TIMEOUT|Timed out|Program received signal', log), side+' clean completion')
    terminal = 'Exited via the debugger' if side == 'reference' else '[Inferior 1 (Remote target) detached]'
    require(log.count(terminal) == 1, side+' terminal record')
    rows = re.findall(r'^INTRO_FRAME n=(\d+) segment=(\d+) offset=([0-9A-F]+) d0=([0-9A-F]+)$', log, re.M)
    records = [tuple(int(v, 16 if i >= 2 else 10) for i, v in enumerate(row)) for row in rows]
    require([r[:3] for r in records] == STATES, side+' original state keys/order')
    require(records[-1][3] == 0, side+' uninterrupted completion')
    if side == 'reference':
        require(log.count('PASS original intro frames=4') == 1, 'original completion')
    else:
        coverage = re.findall(r'^PASS full intro C2P frames=(\d+) partial=(\d+) failures=(\d+) queued=(\d+) presented=(\d+) book=(\d+)/(\d+) ticks=(\d+)$', log, re.M)
        require(len(coverage) == 1, 'full intro C2P completion')
        frames, partial, failures, queued, presented, begun, completed, ticks = map(int, coverage[0])
        require(frames == queued == presented and frames >= 840 and 0 < partial <= frames and failures == 0 and begun == completed == 840 and ticks > 0, 'full intro conversion/publication coverage')


def compare(reference, native, reference_status, native_status, folder, allow_placeholder=False):
    capture(reference, reference_status, 'reference')
    capture(native, native_status, 'native')
    if allow_placeholder:
        text_calls=re.findall(r'^INTRO_TEXT state=(\d+) x=(-?\d+) y=(-?\d+) fraction=([0-9A-F]+) font=(\d+) size=(\d+) face=(\d+) mode=(\d+) extra=([0-9A-F]+) hex=([0-9A-F]*)$',reference,re.M)
        for frame,runs in PLACEHOLDER_RUNS.items():
            rows=[r for r in text_calls if int(r[0])==frame and r[9]][-len(runs):]
            require(len(rows)==len(runs),'original caption text-call coverage')
            for row,(text,x,y) in zip(rows,runs):
                settings=tuple(int(v,16 if i in (2,7) else 10) for i,v in enumerate(row[1:9]))
                require(settings==(x,y,0x8000,20,14,0,1,0) and bytes.fromhex(row[9])==text.encode('mac_roman'),'original caption text/position/style')
    publications = re.findall(r'^INTRO_PUBLICATION n=(\d+) front=([0-9A-F]+) queued=(\d+) presented=(\d+) randomCalls=(\d+)$', native, re.M)
    require(len(publications) == 4, 'four native publications')
    cursors = re.findall(r'^INTRO_CURSOR n=(\d+) enabled=(\d+) control=([0-9A-F]+)$', native, re.M)
    require(not cursors or cursors == [(str(n),'1','010F') for n in range(1,5)], 'four pointer palette publications')
    inversions = re.findall(r'^INTRO_INVERSION n=(\d+) active=([01]) left=(-?\d+) top=(-?\d+)$', native, re.M)
    require(not inversions or [row[0] for row in inversions] == ['1','2','3','4'], 'four cursor inversion records')
    transfer = read(folder, 'video-transfer-lut16.bin', 65536)
    require(hashlib.sha256(transfer).hexdigest() == 'bf0a6433c155a61989e5dc0571bae1357066ab476a24d0afaf2e2aa7094fe2aa', 'reference colour transfer')
    total = 0
    previous = 0
    for state, publication in zip(STATES, publications):
        n, front, queued, presented, random_calls = publication
        require(int(n) == state[0] and int(queued) > previous and queued == presented and int(random_calls) == 0, 'complete pre-random intro state')
        previous = int(queued)
        prefix = 'intro-native-'+n
        pixels = read(folder, prefix+'-screen.bin', 307200)
        clut = read(folder, prefix+'-clut.bin', 2056)
        original = read(folder, 'intro-reference-'+n+'-screen.bin', 307200)
        original_clut = read(folder, 'intro-reference-'+n+'-clut.bin', 2056)
        for pen in range(256):
            require(clut[10+pen*8:16+pen*8] == original_clut[10+pen*8:16+pen*8], f'frame {n} palette {pen}')
        overlay = None
        if inversions:
            _, active, left, top = inversions[int(n)-1]
            masks = struct.unpack('>16H', read(folder, prefix+'-inversion.bin', 32))
            if active == '1':
                overlay = (int(left), int(top), masks)
        check_frame(folder, prefix, pixels, clut, 160, 150, int(front, 16), transfer, 1 if cursors else 0, overlay)
        differences = [(x, y) for y in range(200) for x in range(320)
                       if pixels[(y+150)*640+x+160] != original[(y+150)*640+x+160]]
        if differences and allow_placeholder:
            explained_placeholder(state[0],pixels,original,differences)
        else:
            total += len(differences)
        if differences:
            xs, ys = zip(*differences)
            print(f'FRAME {n}: {len(differences)} '+('verified owned-glyph' if allow_placeholder else 'unexplained')+f' differences; bounds={min(xs)},{min(ys)}..{max(xs)},{max(ys)}; palette/publication exact')
        else:
            print(f'PASS frame {n}: original state CODE {state[1]}+{state[2]:X}, all 64000 pixels, palette and AGA publication')
    require(total == 0, f'{total} frame differences require explanation and a bounded acceptance rule')
    print('PASS paired intro: logo and three states, uninterrupted completion and full-frame C2P coverage')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('reference_log', type=Path)
    parser.add_argument('native_log', type=Path)
    parser.add_argument('--reference-status', type=int, required=True)
    parser.add_argument('--native-status', type=int, required=True)
    parser.add_argument('--folder', type=Path, default=Path('tmp'))
    parser.add_argument('--allow-placeholder-text', action='store_true', help='accept D6 glyph artwork only after verifying the complete owned ink stencil')
    args = parser.parse_args()
    try:
        compare(args.reference_log.read_text(), args.native_log.read_text(), args.reference_status, args.native_status, args.folder, args.allow_placeholder_text)
    except (ValueError, OSError) as error:
        raise SystemExit('FAIL intro comparison: '+str(error))
