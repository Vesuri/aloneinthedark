#!/usr/bin/env python3
"""Render a packed 4-bit or indexed 8-bit Mac framebuffer using its live CLUT.

A reference mismatch exits nonzero. Original clut 128 verification is optional
and reads only the supplied local resource fork, never committed game data.
"""
import argparse
import struct
from pathlib import Path
from PIL import Image, ImageChops


def read_palette(text):
    entries = [tuple(map(int, line.split())) for line in text.splitlines() if line.strip()]
    if any(len(e) != 5 or e[0] != i for i, e in enumerate(entries)):
        raise ValueError('FRAMEBUFFER / NONCONTIGUOUS CLUT')
    if any(not 0 <= v <= 65535 for e in entries for v in e[1:]):
        raise ValueError('FRAMEBUFFER / INVALID CLUT VALUE')
    return entries


def render(data, entries, width, height, rowbytes, bpp):
    if bpp not in (4, 8):
        raise ValueError('FRAMEBUFFER / UNSUPPORTED DEPTH')
    if width <= 0 or height <= 0 or rowbytes < (width*bpp+7)//8:
        raise ValueError('FRAMEBUFFER / INVALID GEOMETRY')
    if len(data) != rowbytes*height or len(entries) != 1 << bpp:
        raise ValueError('FRAMEBUFFER / DATA OR PALETTE SIZE')
    palette = [tuple(v >> 8 for v in e[2:]) for e in entries]
    pixels = []
    for y in range(height):
        for x in range(width):
            byte = data[y*rowbytes + (x if bpp == 8 else x//2)]
            index = byte if bpp == 8 else (byte >> 4 if x % 2 == 0 else byte & 15)
            pixels.append(palette[index])
    image = Image.new('RGB', (width, height))
    image.putdata(pixels)
    return image


def selftest():
    p = [(i, 32768, i*257, i*257, i*257) for i in range(256)]
    assert render(bytes([0, 128, 255, 99, 2, 3, 4, 99]), p, 3, 2, 4, 8).tobytes() == bytes(v for c in (0,128,255,2,3,4) for v in (c,c,c))
    assert render(bytes([0x1f, 0x20, 99]), p[:16], 3, 1, 3, 4).tobytes() == bytes(v for c in (1,15,2) for v in (c,c,c))
    for data, width, rowbytes, depth in [(b'',1,1,8),(b'\0',2,1,8),(b'\0',1,1,1)]:
        try:
            render(data,p,width,1,rowbytes,depth)
        except ValueError:
            continue
        raise AssertionError('bad geometry/depth accepted')
    assert read_palette('0 32768 65535 0 257\n') == [(0,32768,65535,0,257)]
    print('PASS framebuffer-selftest indexed8=1 packed4=1 padding=1 invalid=3 clut=1')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('args', nargs='*', help='raw clut width height rowbytes out.png [reference.png]')
    parser.add_argument('--bpp', type=int, choices=(4,8), default=4)
    parser.add_argument('--resource', help='verify clut 128, reporting its three duplicate black/white slots')
    parser.add_argument('--hardware-clut', help='use the measured video-device palette for rendered RGB')
    parser.add_argument('--selftest', action='store_true')
    a = parser.parse_args()
    if a.selftest:
        selftest()
        return
    if len(a.args) not in (6,7):
        parser.error('expected raw clut width height rowbytes out.png [reference.png]')
    raw, clut, width, height, rowbytes, out = a.args[:6]
    entries = read_palette(Path(clut).read_text())
    display_entries = read_palette(Path(a.hardware_clut).read_text()) if a.hardware_clut else entries
    image = render(Path(raw).read_bytes(), display_entries, int(width), int(height), int(rowbytes), a.bpp)
    image.save(out)
    if a.resource:
        from resource_fork import parse_resource_fork
        resource = next(r for r in parse_resource_fork(Path(a.resource).read_bytes()) if r.kind==b'clut' and r.rid==128)
        expected = [struct.unpack_from('>4H', resource.body, 8+i*8)[1:] for i in range(256)]
        different = [i for i, (e, got) in enumerate(zip(expected, entries)) if e != got[2:]]
        # In the measured Mac palette, three duplicate endpoint colours keep
        # prior logo colours. Do not silently rewrite those slots to the resource.
        duplicate = {1:(0,0,0),15:(65535,65535,65535),191:(0,0,0)}
        if any(expected[i]!=rgb for i,rgb in duplicate.items()):
            raise SystemExit('FRAMEBUFFER / ORIGINAL DUPLICATE COLOURS CHANGED')
        unexpected = sorted(set(different)-duplicate.keys())
        if len(entries)!=256 or unexpected:
            raise SystemExit(f'FRAMEBUFFER / ORIGINAL CLUT MISMATCH indices={unexpected}')
        print(f'PASS original-clut-128 fixed_indices=253 exact_rgb16={256-len(different)}/256; duplicate slots differing={different}')
    if len(a.args) == 7:
        reference = Image.open(a.args[6]).convert('RGB')
        if reference.size != image.size:
            raise SystemExit('FRAMEBUFFER / REFERENCE SIZE MISMATCH')
        diff = ImageChops.difference(reference, image)
        rgb = diff.tobytes()
        bad = sum(any(rgb[i:i+3]) for i in range(0,len(rgb),3))
        print(f'differing pixels: {bad}/{image.width*image.height}; bbox={diff.getbbox()}')
        if bad:
            raise SystemExit('FRAMEBUFFER / PIXEL MISMATCH')
        print('PASS framebuffer pixel-exact match')
    print(f'wrote {out}: {image.width}x{image.height}, {a.bpp} bpp, {len(entries)} colours')


if __name__ == '__main__':
    main()
