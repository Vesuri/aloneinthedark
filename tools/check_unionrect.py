#!/usr/bin/env python3
"""Check original UnionRect bytes, 20 calls and isolated Mac edge cases."""
import argparse
import hashlib
from pathlib import Path
import re
import struct
from resource_fork import read_resource_fork

ROOT = Path(__file__).resolve().parents[1]
DIGEST = '6830d1818ab1ca6c4ac1c282e846b0edb808292d4d20c07f630430fa1a67618b'

def fields(line):
    return dict(re.findall(r'(\w+)=([0-9A-Fa-f]+)(?: |$)', line))

def pairs(text, fixtures=11):
    rows = [line for line in text.splitlines() if line.startswith(('UR_ENTER ', 'UR_RETURN '))]
    if len(rows) != 2*(20+fixtures):
        raise ValueError('expected 20 original pairs and 11 fixture pairs')
    for i in range(20+fixtures):
        if not rows[i*2].startswith('UR_ENTER ') or not rows[i*2+1].startswith('UR_RETURN '):
            raise ValueError('entry/return order')
        yield fields(rows[i*2]), fields(rows[i*2+1])

def check(text, status):
    if status != 0 or any(word in text for word in ('FAIL', 'LUA ERROR', 'Error in breakpoint', 'Unknown command', 'timeout')):
        raise ValueError('failed or incomplete reference run')
    if text.count('PASS original UnionRect calls=20 fixtures=11') != 1 or text.count('Exited via the debugger') != 1:
        raise ValueError('missing/duplicate completion')
    code = next(r.body for r in read_resource_fork(ROOT/'tmp/runtime-data/Alone In The Dark') if r.kind == b'CODE' and r.rid == 13)[0x1bc:0x1e0]
    live = re.findall(r'^UR_BYTES data=([0-9A-F]+)$', text, re.M)
    if hashlib.sha256(code).hexdigest() != DIGEST or live != [code.hex().upper()]:
        raise ValueError('original/live Dan2 bytes')
    for i, (before, after) in enumerate(pairs(text)):
        fixture = max(0, i-19)
        if int(before['n']) != min(i+1, 20) or int(before['fixture']) != fixture or any(after[k] != before[k] for k in ('n', 'fixture', 'sp', 'dst', 'r1', 'r2')):
            raise ValueError('call attribution/order')
        a, b = [struct.unpack('>4h', bytes.fromhex(before[k])) for k in ('data1', 'data2')]
        expected = struct.pack('>4h', min(a[0], b[0]), min(a[1], b[1]), max(a[2], b[2]), max(a[3], b[3])).hex().upper()
        if after['dest'] != expected:
            raise ValueError('signed rectangle bounds')
        for data, pointer in (('data1', 'r1'), ('data2', 'r2')):
            if after[data] != (expected if before[pointer] == before['dst'] else before[data]):
                raise ValueError('source mutation/aliasing')
        if int(after['returnsp'], 16) != int(before['sp'], 16)+12:
            raise ValueError('stack cleanup')
        if after['d0'] != expected[:8] or after['d1'] != expected[8:] or int(after['a1'], 16) != int(before['r2'], 16)+8:
            raise ValueError('result registers')
        for reg in [f'd{n}' for n in range(2, 8)]+[f'a{n}' for n in range(2, 7)]:
            if after[reg] != before[reg]:
                raise ValueError('preserved register '+reg)
    return 'PASS UnionRect reference: original bytes, 20 calls, 11 empty/inverted/extreme/alias fixtures, bounds and ABI'

def check_native(reference, native, status):
    from check_native_driver import check as driver_check
    driver_check(native, status)
    if native.count('PASS native UnionRect calls=20') != 1:
        raise ValueError('native loop completion')
    if re.findall(r'^UR_BYTES data=([0-9A-F]+)$', native, re.M) != re.findall(r'^UR_BYTES data=([0-9A-F]+)$', reference, re.M):
        raise ValueError('native original instruction bytes')
    original=list(pairs(reference))[:20]
    for i, ((before, after), (ref_before, ref_after)) in enumerate(zip(pairs(native, 0), original)):
        if int(before['n']) != i+1 or before['fixture'] != '0' or any(after[k] != before[k] for k in ('n','fixture','sp','dst','r1','r2')):
            raise ValueError('native call attribution/order')
        for key in ('data1','data2','dest'):
            if before[key] != ref_before[key] or after[key] != ref_after[key]:
                raise ValueError('native/reference rectangle '+key)
        if int(after['returnsp'],16) != int(before['sp'],16)+12:
            raise ValueError('native stack cleanup')
        if after['d0'] != ref_after['d0'] or after['d1'] != ref_after['d1'] or int(after['a1'],16) != int(before['r2'],16)+8:
            raise ValueError('native result registers')
        for reg in [f'd{n}' for n in range(2,8)]+[f'a{n}' for n in range(2,7)]:
            if after[reg] != before[reg]:
                raise ValueError('native preserved register '+reg)
    return 'PASS paired UnionRect: all 20 original rectangles and call results; native driver/MDRV/next-stop checks pass'

if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('reference', type=Path)
    p.add_argument('--status', type=int, required=True)
    p.add_argument('--native', type=Path)
    p.add_argument('--native-status', type=int)
    args = p.parse_args()
    try:
        print(check(args.reference.read_text(), args.status))
        if args.native:
            print(check_native(args.reference.read_text(),args.native.read_text(),args.native_status))
    except (ValueError, OSError, KeyError) as error:
        raise SystemExit('FAIL UnionRect: '+str(error))
