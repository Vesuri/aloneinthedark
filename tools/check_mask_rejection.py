#!/usr/bin/env python3
"""Require a completed native malformed-mask rejection with no destination writes."""
import argparse
from pathlib import Path
import re


def check(log, directory, status):
    text = log.read_text()
    if (status or text.count('PASS malformed mask named rejection') != 1
            or text.count('[Inferior 1 (Remote target) detached]') != 1
            or re.search(r'FAIL|TIMEOUT|Error in|Program received signal', text)):
        raise ValueError('native rejection did not complete')
    matches = re.findall(r'^MASK_REJECTED trap=A8EC segment=4 offset=346C bytes=(\d+)$', text, re.M)
    if len(matches) != 1:
        raise ValueError('expected named CopyBits rejection')
    before = (directory / 'mask-rejection-before.bin').read_bytes()
    after = (directory / 'mask-rejection-after.bin').read_bytes()
    if not before or len(before) != int(matches[0]) or before != after:
        raise ValueError('destination changed before rejection')
    print(f'PASS native malformed mask: named rejection, all {len(before)} destination bytes unchanged')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('log', type=Path)
    parser.add_argument('directory', type=Path)
    parser.add_argument('--status', type=int, required=True)
    args = parser.parse_args()
    check(args.log, args.directory, args.status)
