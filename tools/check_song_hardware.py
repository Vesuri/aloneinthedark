#!/usr/bin/env python3
"""Validate a complete DMA-enable capture and report spacing, not audible quality."""
import argparse
from collections import defaultdict
from pathlib import Path
import re
import statistics
import struct


def require(condition, message):
    if not condition:
        raise SystemExit('FAIL '+message)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('log', type=Path)
    parser.add_argument('capture', type=Path)
    parser.add_argument('--status', type=int, required=True)
    parser.add_argument('--field-lines', type=int, required=True,
                        help='PAL lines per field verified from the emulator core log')
    args = parser.parse_args()
    log = args.log.read_text()
    require(args.status == 0 and not re.search(r'FAIL|[Tt]imeout|Error in', log), 'runner completion')
    require(log.count('PASS uninterrupted intro hardware note capture') == 1
            and '[Inferior 1 (Remote target) detached]' in log, 'natural completion')
    match = re.search(r'SONG_HARDWARE clock=field-raster events=(\d+) starts=(\d+) captured=(\d+) overflow=(\d+) maxLate=(\d+) busyFields=(\d+) tick=(\d+) pal=(\d+) paula=(\d+)', log)
    require(match is not None, 'capture metadata')
    events, starts, count, overflow, late, busy, tick, pal, clock = map(int, match.groups())
    require(events == 3736 and starts == count and count > 100 and not overflow,
            'complete music starts')
    require(pal == 1 and 3500000 < clock < 3600000, 'PAL horizontal clock')
    raw = args.capture.read_bytes()
    require(len(raw) == count*32, 'exact capture length')
    rows = list(struct.iter_unpack('>8I', raw))
    require(args.field_lines in (312, 313), 'fixed PAL field length')
    def distance(a, b):
        return (((b >> 9)-(a >> 9)) & 65535)*args.field_lines+(b & 511)-(a & 511)
    first = rows[0][2]
    groups = defaultdict(list)
    brackets = []
    previous_time = -1
    previous_due = -1
    for due, delivered, before, after, channel, period, instrument, note in rows:
        require(before < (1 << 25) and after < (1 << 25)
                and (before & 511) < args.field_lines and (after & 511) < args.field_lines and channel < 4
                and 0 < period <= 65535 and instrument < 128 and note < 128,
                'hardware row ranges')
        span = distance(before, after)
        time = distance(first, before)+span/2
        require(0 <= span <= 8 and time >= previous_time and due >= previous_due,
                'bounded timestamp brackets and monotonic starts')
        require(0 <= delivered-due <= 1, 'logical delivery lateness')
        brackets.append(span)
        groups[due].append(time)
        previous_time, previous_due = time, due
    # PAL HSYNC is one line per 227 Paula colour clocks. Fit the average tick
    # rate separately so slow clock drift is not conflated with short jitter.
    line_ms = 227000/clock
    points = [(due, min(times)) for due, times in sorted(groups.items())]
    mean_x = statistics.mean(x for x, y in points)
    mean_y = statistics.mean(y for x, y in points)
    slope = sum((x-mean_x)*(y-mean_y) for x, y in points)/sum((x-mean_x)**2 for x, y in points)
    residual = [y-mean_y-slope*(x-mean_x) for x, y in points]
    spread = [(max(times)-min(times))*line_ms for times in groups.values()]
    intervals = defaultdict(list)
    for (x0, y0), (x1, y1) in zip(points, points[1:]):
        intervals[x1-x0].append((y1-y0)*line_ms)
    print(f'PASS complete capture: {count} DMA starts, {len(points)} intended onset ticks; '
          f'max timestamp bracket {max(brackets)*line_ms:.3f} ms')
    print(f'Measured mean tick {slope*line_ms:.4f} ms; onset phase range after mean-rate fit '
          f'{(max(residual)-min(residual))*line_ms:.3f} ms; '
          f'max spread within one intended tick {max(spread):.3f} ms; busy fields {busy}')
    for delta, values in sorted(intervals.items()):
        if len(values) >= 5:
            print(f'Intended gap {delta} ticks ({delta*slope*line_ms:.3f} ms): '
                  f'n={len(values)} observed min/median/max '
                  f'{min(values):.3f}/{statistics.median(values):.3f}/{max(values):.3f} ms')
    print('DMA-enable brackets only; excludes first-sample latency and host audio output.')


if __name__ == '__main__':
    main()
