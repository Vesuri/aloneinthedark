#!/usr/bin/env python3
"""Compare isolated short waits and the first two unskipped book holds."""
import argparse
import re
from pathlib import Path
from resource_fork import read_resource_fork


def require(condition, message):
    if not condition:
        raise ValueError(message)


def rows(text, kind, count, marker):
    require('FAIL' not in text and text.count(marker) == 1, marker)
    result = [dict((k, int(v)) for k, v in re.findall(r'(\w+)=(\d+)', line))
              for line in text.splitlines() if line.startswith(kind + ' ')]
    require(len(result) == count and [r['n'] for r in result] == list(range(count)), kind + ' completeness')
    return result


def check(original, pal, ntsc, original_route, native_route, resource):
    code = {r.rid: r.body for r in read_resource_fork(resource) if r.kind == b'CODE'}
    require(code[13][0x3364:0x336c].hex() == '42a7a975ba9f62f8', 'original short-loop bytes')
    require(code[12][0x496e:0x497e].hex() == '42a7a975201f90aefe4a0c800000012c', 'original book deadline bytes')
    for name, text in [('Mac', original), ('PAL', pal), ('NTSC', ntsc)]:
        marker = 'PASS original tick waits' if name == 'Mac' else 'PASS tick waits'
        data = rows(text, 'TICK_WAIT', 42, marker)
        if name != 'Mac':
            require('TICK_CONTROLS bits=7' in text, name + ' pending VBI / rollover controls')
        for n, row in enumerate(data):
            delay = 5 if n < 20 else 7 if n < 40 else 300
            elapsed = row['end'] - row['start']
            require(row['delay'] == delay, name + ' paired requested deadline')
            require(delay <= elapsed <= delay + (name == 'PAL'), name + ' elapsed ticks')
            if n:
                require(row['start'] >= data[n-1]['end'], name + ' monotonic clock')
            if name == 'PAL' and 2 <= n < 20:
                require(elapsed == 6, 'PAL five-tick phase lock')
            if name != 'Mac':
                fields = (row['last_field'] - row['first_field']) & 65535
                expected = fields * 6 // 5 if name == 'PAL' else fields
                require(abs(expected - elapsed) <= (name == 'PAL'), name + ' field cadence')
        for delay in [5, 7, 300]:
            times = [r['end']-r['start'] for r in data if r['delay'] == delay]
            print(f'{name} requested={delay}: count={len(times)} ticks={min(times)}..{max(times)} mean={sum(times)/len(times):.3f}')
    mac = rows(original_route, 'TICK_ROUTE', 2, 'PASS original tick route')
    native = rows(native_route, 'TICK_ROUTE', 2, 'PASS native tick route')
    for m, a in zip(mac, native):
        require(m['delay'] == a['delay'] == 300 and m['d7'] == a['d7'], 'paired book hold state')
        require(m['end']-m['start'] == 300 and 300 <= a['end']-a['start'] <= 301, 'book deadlines')
    print('PASS paired tick waits: original bytes, deadlines, monotonicity, field cadence, pending VBI and rollover')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ['original', 'pal', 'ntsc', 'original_route', 'native_route']:
        parser.add_argument(name, type=Path)
    parser.add_argument('--resource', type=Path, default=Path('tmp/runtime-data/Alone In The Dark'))
    parser.add_argument('--statuses', type=int, nargs=5, required=True, help='actual process exit statuses in capture order')
    args = parser.parse_args()
    require(args.statuses == [0]*5, 'all observers completed normally')
    check(*(getattr(args, name).read_text() for name in ['original', 'pal', 'ntsc', 'original_route', 'native_route']), args.resource)
