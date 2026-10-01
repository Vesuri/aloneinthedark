#!/usr/bin/env python3
"""Paired pond DisposeRgn ABI, ownership and drawing-isolation acceptance."""
import argparse
import re
import struct
from pathlib import Path
from check_driver22 import fields, one
ROOT = Path(__file__).resolve().parents[1]


def run(reference, status, native=None, native_status=None):
    def complete(text, rc, marker, end):
        if rc != 0 or text.count(marker) != 1 or text.count(end) != 1 or re.search(
                r'FAIL|LUA ERROR|Error in|TIMEOUT|Timed out|Program received signal', text):
            raise ValueError('completion')

    def blob(side, phase, name):
        return (ROOT / f'tmp/disposergn-{side}-{phase}-{name}.bin').read_bytes()

    def isolation(side):
        for name in ('port', 'pm', 'pixels', 'clut', 'vis', 'clip'):
            if blob(side, 'ENTER', name) != blob(side, 'RETURN', name):
                raise ValueError(side + ' changed ' + name)

    preserved = [f'd{i}' for i in range(1, 8)] + [f'a{i}' for i in range(2, 7)]
    def registers(a, b, handle):
        if b['sp'] != a['sp'] + 4 or b['d0'] or b['a0'] != a[handle] or b['memerr']:
            raise ValueError('disposal ABI')
        for reg in preserved:
            if a[reg] != b[reg]:
                raise ValueError('preserved ' + reg)

    text = reference.read_text()
    complete(text, status, 'COMPLETE original pond region disposal', 'Exited via the debugger')
    raw = (ROOT / 'tmp/segments/CODE_4_Dark').read_bytes()[0x3056:0x3062]
    if raw.hex() != '2f14a8d9429470ff29400004' or one(text, r'^DRGN_BYTES data=(\w+)$') != raw.hex().upper():
        raise ValueError('original caller bytes')
    a, b = [fields(one(text, rf'^DRGN_{phase} (.*)$')) for phase in ('ENTER', 'RETURN')]
    registers(a, b, 'region')
    z0, z1 = [blob('reference', phase, 'zone') for phase in ('ENTER', 'RETURN')]
    if a['size'] != 128 or a['master'] != a['body'] or a['zone'] != b['zone'] or b['free'] != a['free'] + 136 or b['master'] != struct.unpack_from('>I', z0, 8)[0]:
        raise ValueError('original heap disposal')
    expected = bytearray(z0)
    struct.pack_into('>II', expected, 8, a['region'], b['free'])
    if expected != z1:
        raise ValueError('original zone transition')
    isolation('reference')
    if native:
        text = native.read_text()
        complete(text, native_status, 'PASS native DisposeRgn and continuation', '[Inferior 1 (Remote target) detached]')
        a, b = [fields(one(text, rf'^DRGN_NATIVE_{phase} (.*)$')) for phase in ('ENTER', 'RETURN')]
        registers(a, b, 'poly')
        if a['size'] != 128 or a['span'] < 152 or b['master'] != a['successor'] or b['flags'] or b['free'] != a['free'] + a['span']:
            raise ValueError('native heap disposal')
        if blob('native', 'ENTER', 'region') != blob('reference', 'ENTER', 'region'):
            raise ValueError('region input')
        allocation = {}
        for phase in ('ENTER', 'RETURN'):
            rows = [fields(row) for row in re.findall(rf'^DRGN_ALLOC_{phase} (.*)$', text, re.M)]
            if not rows or len({row['block'] for row in rows}) != len(rows):
                raise ValueError('allocation records missing or duplicated')
            allocation[phase] = {row['block']: row for row in rows}
        disposed = [key for key in allocation['ENTER'] if key not in allocation['RETURN']]
        if len(disposed) != 1:
            raise ValueError('disposed allocation count')
        removed = allocation['ENTER'].pop(disposed[0])
        if removed['kind'] != 2 or removed['logical'] != a['size'] or removed['span'] != a['span']:
            raise ValueError('disposed allocation identity')
        if allocation['ENTER'] != allocation['RETURN']:
            raise ValueError('unrelated allocation changed')
        isolation('native')
        if not re.search(r'^DRGN_NATIVE_ISOLATION frames=\d+ book=0$', text, re.M):
            raise ValueError('publication or book isolation')
        c = fields(one(text, r'^DRGN_NEXT (.*)$'))
        if c != {'offset': 0x305e, 'cleared': 0}:
            raise ValueError('original cleanup continuation')
    print('PASS DisposeRgn: original bytes/ABI, heap disposal and drawing isolation' +
          ('; paired native region, ownership, registers and original cleanup continuation' if native else ''))


if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('--reference', type=Path, required=True)
    p.add_argument('--status', type=int, required=True)
    p.add_argument('--native', type=Path)
    p.add_argument('--native-status', type=int)
    a = p.parse_args()
    if a.native and a.native_status is None:
        p.error('--native requires --native-status')
    run(a.reference, a.status, a.native, a.native_status)
