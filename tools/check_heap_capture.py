#!/usr/bin/env python3
"""Account for M1.5 heaps at the first Core+$3D36 Gestalt('sysv').

Inputs are local-only MAME and original_startup.gdb dumps and the original fork.
No emulator addresses or original payloads are distributed with this checker.
"""
import argparse
from collections import Counter
from pathlib import Path
from resource_fork import read_resource_fork


def blocks(raw, native):
    end = len(raw) - (16 if native else 0)
    pos = 64 if native else 52
    result = []
    while pos < end:
        word = int.from_bytes(raw[pos:pos+4], 'big')
        span = word if native else word & 0xffffff
        kind = int.from_bytes(raw[pos+12:pos+16], 'big') if native else word >> 30
        header = 24 if native else 8
        logical = int.from_bytes(raw[pos+4:pos+8], 'big') if native else span-header-((word >> 24) & 15)
        if span < header or pos+span > end or kind > 3 or logical > span-header:
            raise ValueError(f'invalid block at {pos:#x}')
        result.append((kind, span, raw[pos+header:pos+header+logical]))
        pos += span
    free = sum(span for kind, span, _ in result if kind == 0)
    if pos != end or free != int.from_bytes(raw[12:16], 'big'):
        raise ValueError('block walk does not match zone FreeMem')
    return result, free


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('reference', type=Path)
    parser.add_argument('native', type=Path)
    parser.add_argument('resource', type=Path)
    args = parser.parse_args()
    ref, native = args.reference.read_bytes(), args.native.read_bytes()
    rb, rf = blocks(ref, False)
    nb, nf = blocks(native, True)
    resources = read_resource_fork(args.resource)
    unused = [r for r in resources if r.kind == b'CODE' and r.rid in (4,5,6,8,9,10,11,12,13)]
    unused_span = 0
    for resource in unused:
        matches = [span for kind, span, data in rb if kind == 2 and data == resource.body]
        if len(matches) != 1:
            raise ValueError(f'original CODE {resource.rid} not uniquely present')
        unused_span += matches[0]
    rc = Counter(); nc = Counter()
    for kind, span, _ in rb: rc[kind] += span
    for kind, span, _ in nb: nc[kind] += span
    geometry = len(native)-len(ref)
    remaining = rf + geometry + unused_span
    residual = nf-remaining
    # Captured-state acceptance: differences must remain exactly accounted for;
    # this is an observer baseline, never a Memory Manager return constant.
    if (rf,nf,geometry,unused_span,residual) != (2821316,3096720,120360,149260,5784):
        raise ValueError(f'startup heap baseline changed: {(rf,nf,geometry,unused_span,residual)}')
    print(f'PASS heap-reference: Mac={rf} Amiga={nf} geometry={geometry} unused-CODE={unused_span} other-blocks={residual} unaccounted=0')
    print(f'physical blocks: Mac={dict(rc)} Amiga={dict(nc)}; zone metadata Mac=52 Amiga=80')


if __name__ == '__main__':
    main()
