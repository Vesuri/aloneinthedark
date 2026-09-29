#!/usr/bin/env python3
"""Check pending-map write evidence; failed-read payload/size are not a contract."""
import argparse
from pathlib import Path
import re
from resource_fork import read_resource_fork

LABELS = '''application create map open allocate-a add-a allocate-b add-b
write-with-unwritten-peer attrs-written-a attrs-unwritten-b empty-written-a
reload-written-a empty-unwritten-b attrs-empty-unwritten-b load-unwritten-b
attrs-after-unwritten-load size-unwritten-loaded remove-unwritten-b dispose-unwritten-b
update-first close-first reopen-first lookup-first-a lookup-first-removed-b
allocate-again-b add-again-b update-baseline remove-stored-b change-a
write-with-removed-peer attrs-written-again-a empty-again-a reload-again-a
lookup-removed-b update-second close-second reopen-second lookup-final-a
lookup-final-removed-b close-final dispose-stored-b delete current-final'''.split()


def validate(text, status, resources):
    if (status or any(x in text for x in ('FAIL ', 'LUA ERROR', 'Error in breakpoint'))
            or text.count('PASS resource map-edit capture complete; scratch deleted') != 1
            or text.count('ARM resource-map-edit Engine+$3CDC bytes=a820245f') != 1):
        raise ValueError('runner, original gate or completion')
    rows = [{k: v if k == 'label' else int(v, 16)
             for k, v in re.findall(r'(\w+)=(\S+)', line)}
            for line in text.splitlines() if line.startswith('RMAPEDIT label=')]
    if [r['label'] for r in rows] != LABELS:
        raise ValueError('ordered 44-call sequence')
    by = {r['label']: r for r in rows}
    app = by['application']['result']
    for n, r in enumerate(rows, 1):
        s = r['label']
        current = s in {'application', 'current-final'}
        attrs = s.startswith('attrs-')
        opened = s in {'open', 'reopen-first', 'reopen-second'}
        lookup = s.startswith('lookup-')
        missing = lookup and 'removed' in s
        allocated = s.startswith('allocate-')
        empty = s.startswith('empty-')
        sized = s == 'size-unwritten-loaded'
        os = s in {'create', 'delete'} or allocated or empty or sized or s.startswith('dispose-')
        error = 0x8888 if os or current else 0xffd9 if s == 'load-unwritten-b' else 0
        mem = 0x7777 if current or attrs or missing or s in {'create', 'map', 'delete', 'update-second'} else 0
        d0 = (0x12345678 if current or attrs or opened or s.startswith(('reload-', 'update-', 'load-'))
              else 4 if s == 'map' else r['result'] if sized else 0)
        delta = 4 if lookup else 2 if current or attrs or opened else 0
        if (r['stage'], r['error'], r['mem'], r['d0'], r['sp']) != (n, error, mem, d0, r['base'] - delta):
            raise ValueError(s + ' registers/errors/stack')
        if current:
            if not app or r['result'] != app:
                raise ValueError(s + ' current file')
        elif opened:
            if r['result'] in (0, 0xffff, app) or r['result'] != r['ref']:
                raise ValueError(s + ' resource ref')
        elif allocated or (lookup and not missing):
            if not r['handle'] or r['result'] != r['handle']:
                raise ValueError(s + ' returned handle')
        elif attrs:
            # The System wrapper writes only the low attribute byte.
            expected = 2 if s in {'attrs-unwritten-b', 'attrs-empty-unwritten-b'} else 0
            if r['result'] & 255 != expected:
                raise ValueError(s + ' defined attribute byte')
        elif not sized and r['result']:
            raise ValueError(s + ' scalar result')
        if empty or s == 'attrs-empty-unwritten-b':
            if r['master']:
                raise ValueError(s + ' master not empty')
    bodies = {
        0x41414141: 'allocate-a add-a write-with-unwritten-peer attrs-written-a reload-written-a lookup-first-a lookup-first-removed-b',
        0x42424242: 'allocate-b add-b attrs-unwritten-b allocate-again-b add-again-b update-baseline remove-stored-b',
        0x43434343: 'change-a write-with-removed-peer attrs-written-again-a reload-again-a lookup-removed-b update-second lookup-final-a lookup-final-removed-b',
    }
    for body, names in bodies.items():
        for s in names.split():
            r = by[s]
            flag = 0 if s.startswith('allocate-') or s == 'remove-stored-b' else 0x20
            if r['body'] != body or not r['master'] & 0xffffff or r['master'] >> 24 != flag:
                raise ValueError(s + ' exact live body/flags')
    # EOF did not restore BBBB. Do not assert failed-read bytes or the allocation
    # size: ROM/I/O tracing finds unrelated bytes beyond the saved empty map.
    for s in ('load-unwritten-b', 'attrs-after-unwritten-load', 'size-unwritten-loaded', 'remove-unwritten-b'):
        r = by[s]
        if not r['master'] & 0xffffff or r['master'] >> 24 != (0 if s.startswith('remove-') else 0x20):
            raise ValueError(s + ' observed resident state')
    groups = [
        'allocate-a add-a write-with-unwritten-peer attrs-written-a empty-written-a reload-written-a',
        'allocate-b add-b attrs-unwritten-b empty-unwritten-b attrs-empty-unwritten-b load-unwritten-b attrs-after-unwritten-load size-unwritten-loaded remove-unwritten-b',
        'lookup-first-a change-a write-with-removed-peer attrs-written-again-a empty-again-a reload-again-a',
        'allocate-again-b add-again-b update-baseline remove-stored-b dispose-stored-b',
    ]
    for group in groups:
        if len({by[s]['handle'] for s in group.split()}) != 1:
            raise ValueError('live handle identity')
    if by['allocate-a']['handle'] == by['allocate-b']['handle']:
        raise ValueError('independent resource handles')
    for rid, offset, raw in [(7, 0x3cdc, 'a820245f'), (8, 0x08ac, 'a9ad3f06'),
                             (8, 0x0906, 'a9aa2f0b'), (8, 0x090a, 'a9b0204b')]:
        segment = next(r.body for r in resources if r.kind == b'CODE' and r.rid == rid)
        if segment[offset:offset + 4] != bytes.fromhex(raw):
            raise ValueError('original resource call bytes')
    return ('PASS resource map-edit reference: 44 calls; pending-add/remove writes, selected reloads, '
            'reopen/removal and cleanup; unwritten reload EOF observed, undefined size/body excluded')


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('log', type=Path)
    p.add_argument('--status', type=int, required=True)
    p.add_argument('--original', type=Path, required=True)
    a = p.parse_args()
    try:
        print(validate(a.log.read_text(), a.status, read_resource_fork(a.original)))
    except (ValueError, KeyError, OSError, StopIteration) as e:
        raise SystemExit('FAIL resource map-edit reference: ' + str(e))
