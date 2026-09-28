#!/usr/bin/env python3
"""Attribute a local MAME log to original CODE bytes and compare its trap set.

Unknown/system PCs are counted separately, never assigned to the nearest CODE.
This report is evidence, not acceptance of the scripted UI route.
"""
import argparse
import collections
import re
import struct
from pathlib import Path
import trap_census as census


def fields(line):
    return {k: int(v, 16) for k, v in re.findall(r'(\w+)=([0-9A-F]+)(?:\s|$)', line)}


def caller(pc, word, maps, codes):
    pc &= 0xffffff
    matches = []
    for seg, base, size in maps:
        offset = pc - base
        if 4 <= offset <= size - 2 and seg in codes:
            if struct.unpack_from('>H', codes[seg], offset)[0] == word:
                matches.append((seg, offset))
    matches = set(matches)
    return next(iter(matches)) if len(matches) == 1 else None


def selftest():
    codes = {1: bytes.fromhex('00000000 a9a0 4e75')}
    maps = {(1, 0x400000, 8)}
    assert caller(0x80400004, 0xa9a0, maps, codes) == (1, 4)
    assert caller(0x400006, 0xa9a0, maps, codes) is None
    assert caller(0x500004, 0xa9a0, maps, codes) is None
    assert fields('TRAP pc=80400004 trap=0000A9A0') == {'pc': 0x80400004, 'trap': 0xa9a0}
    print('PASS mac-trap-report-selftest tagged_pc=1 byte_mismatch=1 unattributed=1 fields=1')


def report(log, resource, output):
    census.load(resource)
    live = census.run_live()
    allowed = {t[2] for t in live.traps}
    first = {}
    for seg, offset in census.JT:
        first.setdefault(seg, offset)
    calls = collections.Counter()
    selectors = collections.Counter()
    results = collections.Counter()
    driver = collections.Counter()
    texts = collections.Counter()
    unclaimed = collections.Counter()
    checkpoints = []
    states = set()
    phase = "startup"
    samples = set()
    complete = False
    errors = []
    with open(log) as source:
        for line in source:
            if line.startswith('TRAP '):
                f = fields(line)
                current = {(seg, (f['j'+str(seg)] & 0xffffff)-off, len(census.CODE[seg]))
                           for seg, off in first.items() if f.get('j'+str(seg))}
                if 'j1' not in f:
                    raise SystemExit('TRAP REPORT / LIVE JUMP TABLE FIELDS MISSING')
                at = caller(f['pc'], f['trap'], current, census.CODE)
                if at:
                    calls[(*at, f['trap'])] += 1
                    if f['trap'] in census.SELNAME:
                        selectors[(f['trap'], f['d0'])] += 1
                else:
                    unclaimed[f['trap']] += 1
            elif line.startswith('RESULT '):
                f = fields(line)
                results[f['trap']] += 1
            elif line.startswith('MDRV '):
                f = fields(line)
                if f['cleanup'] not in (0x508f,0x588f) or 'seg' not in f:
                    errors.append('MDRV / UNKNOWN CALL SIGNATURE')
                    continue
                driver[(phase, f['selector'], f['arg'] if f['cleanup']==0x508f else -1, f['seg'], f['offset'])] += 1
                if f['selector']==17:
                    raw=b''.join(f[f'sample{i}'].to_bytes(4,'big') for i in range(8))
                    samples.add((f['arg1'],f['arg2'],raw.hex()))
            elif line.startswith('TEXT '):
                f = fields(line)
                raw = b''.join(f[f'text{i}'].to_bytes(4, 'big') for i in range(16))
                text = raw[:min(f['count'], 64)].decode('mac_roman', 'replace')
                if f['count'] > 64:
                    text += ' [truncated]'
                texts[(f.get('font', -1), f.get('size', -1), text)] += 1
            elif line.startswith('CHECKPOINT '):
                checkpoints.append(line.strip())
                phase=line.split()[1]
            elif line.startswith('STATE_VERIFIED '):
                states.add(line.split()[1])
            elif line.startswith('SESSION complete'):
                complete = True
            if 'VP ERROR' in line or 'VP TIMEOUT' in line or line.startswith('FAIL '):
                errors.append(line.strip())
    required={'attic','escape-menu','engine-save','saved-room','file-save','file-open','loaded-room'}
    missing=required-states
    if missing:
        errors.append('STATE PROOFS MISSING: '+', '.join(sorted(missing)))
    words = {word for _, _, word in calls}
    extra = words - allowed
    lines = ['# MAME runtime trap report', '',
             f'Original CODE: {sum(calls.values())} calls, {len(calls)} sites, {len(words)} trap words.',
             f'Pack3 ($A9EA) direct CODE calls: {sum(n for (_,_,w),n in calls.items() if w==0xa9ea)}.',
             f'Census differences: {", ".join(f"${w:04X}" for w in sorted(extra)) or "none"}.',
             f'Result records: {sum(results.values())}. Driver calls: {sum(driver.values())}.',
             f'Unattributed/system/driver trap calls: {sum(unclaimed.values())}; not counted as application CODE.',
             'MDRV is replaced under D8; its internal traps are outside the CODE census.', '',
             '## Direct CODE sites', '', '| Segment | Offset | Trap | Calls |', '| --- | --- | --- | ---: |']
    for (seg, pc, word), count in sorted(calls.items()):
        lines.append(f'| {census.seg_label(seg)} | ${pc:04X} | ${word:04X} | {count} |')
    lines += ['', '## D0 selectors', '']
    lines += [f'- ${w:04X} D0=${sel:08X}: {n}' for (w, sel), n in sorted(selectors.items())]
    lines += ['', '## MDRV calls (raw interface; no guessed selector semantics)', '']
    lines += [f"- after={phase} selector={sel} arg={f'${arg:08X}' if arg >= 0 else 'unused (one-argument call)'} caller=CODE {seg}+${pc:04X}: {n}"
              for (phase, sel, arg, seg, pc), n in sorted(driver.items())]
    lines += ['', '## Effect sample packets (length, rate/flags, first 32 bytes)', '']
    lines += [f'- {length}, ${flags:08X}, `{raw}`' for length,flags,raw in sorted(samples)]
    lines += ['', '## Mac text', '', '| Font ID | Size | Text | Calls |', '| --- | --- | --- | ---: |']
    for (font, size, text), n in sorted(texts.items()):
        safe = text.replace('|', '\\|').replace('\r', ' ').replace('\n', ' ')
        lines.append(f'| {font} | {size} | {safe} | {n} |')
    lines += ['', '## Script checkpoints (captures still require inspection)', '', *checkpoints,
              '', f'Session completed: {complete}', *errors, '']
    Path(output).write_text('\n'.join(lines))
    if missing or not calls or not results or not driver or not texts or extra or errors or not complete:
        raise SystemExit('TRAP REPORT / INCOMPLETE OR MISMATCHED EVIDENCE; inspect ' + str(output))
    print(f'PASS mac-trap-report code_calls={sum(calls.values())} words={len(words)} '
          f'extra={len(extra)} results={sum(results.values())} mdrv={sum(driver.values())} '
          f'text={sum(texts.values())}; UI captures require separate verification')


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('log', nargs='?')
    p.add_argument('--resource', default='tmp/runtime-data/Alone In The Dark')
    p.add_argument('--output', default='tmp/mac-traps.md')
    p.add_argument('--selftest', action='store_true')
    a = p.parse_args()
    if a.selftest:
        selftest()
    elif a.log:
        report(a.log, a.resource, a.output)
    else:
        p.error('provide a log or --selftest')


if __name__ == '__main__':
    main()
