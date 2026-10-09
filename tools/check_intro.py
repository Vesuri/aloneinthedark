#!/usr/bin/env python3
"""Require uninterrupted intro completion and every-frame native C2P checks."""
import argparse
from pathlib import Path
from compare_frames import capture

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('log', type=Path)
    parser.add_argument('--status', type=int, required=True)
    args = parser.parse_args()
    try:
        log = args.log.read_text()
        capture(log, args.status, 'native')
        if log.count('PASS inherited MACPLAY palette slots 1/15/191 at book title') != 1:
            raise ValueError('Missing inherited splash-palette check')
    except (OSError, ValueError) as error:
        raise SystemExit('FAIL intro regression: '+str(error))
    print('PASS intro regression: four original states, all 840 book batches, zero full-frame C2P mismatches including partial updates')
    print('Run compare_frames.py separately for paired Macintosh pixel/palette acceptance.')
