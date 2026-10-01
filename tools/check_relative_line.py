#!/usr/bin/env python3
"""Accept the reached relative Line only with paired original/native evidence."""
import argparse
import re
import struct
from pathlib import Path
from check_driver22 import fields, one
ROOT = Path(__file__).resolve().parents[1]


def run(reference, status, native=None, native_status=None, paired_reference=None, paired_status=None):
    def complete(text, rc, marker, end):
        if rc != 0 or text.count(marker) != 1 or text.count(end) != 1 or re.search(
                r'FAIL|LUA ERROR|Error in|TIMEOUT|Timed out|Program received signal', text):
            raise ValueError('completion')
    def read(side, phase, name):
        return (ROOT / f'tmp/relative-line-{side}-{phase}-{name}.bin').read_bytes()
    text = reference.read_text()
    complete(text, status, 'PASS original relative Line', 'Exited via the debugger')
    raw = (ROOT / 'tmp/segments/CODE_6_Dark3').read_bytes()[0x3542:0x354c]
    if raw.hex() != 'a8932f3c00010001a892' or one(text, r'^LINE_BYTES (\w+)$') != raw.hex().upper():
        raise ValueError('original caller bytes')
    a, b = [fields(one(text, rf'^LINE_{phase} fixture=0 (.*)$')) for phase in ('ENTER', 'RETURN')]
    if a['target'] != 0x10001 or b['sp'] != a['sp'] + 4 or b['d0']:
        raise ValueError('original stack/result')
    for reg in [f'd{i}' for i in range(1, 8)] + [f'a{i}' for i in range(1, 7)]:
        if a[reg] != b[reg]:
            raise ValueError('original preserved ' + reg)
    if native:
        if not paired_reference:
            raise ValueError('native requires matched-input Mac fixture')
        paired = paired_reference.read_text()
        complete(paired, paired_status, 'PASS original relative Line', 'Exited via the debugger')
        pen = read('native', 'enter', 'port')[48:52]
        if one(paired, r'^LINE_NATIVE_INPUT pen=(\w+)$') != pen.hex().upper():
            raise ValueError('paired fixture input identity')
        e, r = [fields(one(paired, rf'^LINE_{phase} fixture=0 (.*)$')) for phase in ('ENTER', 'RETURN')]
        if e['target'] != 0x10001 or r['sp'] != e['sp'] + 4 or r['d0']:
            raise ValueError('matched-input original ABI')
        for reg in [f'd{i}' for i in range(1, 8)] + [f'a{i}' for i in range(1, 7)]:
            if e[reg] != r[reg]:
                raise ValueError('matched-input original preserved ' + reg)
    for side in (['reference', 'paired-reference', 'native'] if native else ['reference']):
        port = read(side, 'enter', 'port')
        result = read(side, 'return', 'port')
        if side == 'reference' and port[48:58].hex() != 'd67ffb82000100010008':
            raise ValueError(side + ' paired initial pen')
        expected = bytearray(port)
        y, x = struct.unpack_from('>HH', port, 48)
        expected[48:52] = struct.pack('>HH', (y+1)&65535, (x+1)&65535)
        if result != expected:
            raise ValueError(side + ' relative pen/preserved port')
        for name in ('pm', 'vis', 'clip', 'clut', 'pixels'):
            if read(side, 'enter', name) != read(side, 'return', name):
                raise ValueError(side + ' clipped draw changed ' + name)
        if len(read(side, 'enter', 'pixels')) != 652 * 401:
            raise ValueError(side + ' full buffer extent')
        # Both endpoints lie above the map. The unchanged full buffer is an
        # independent clipping oracle, not a claim of visible line coverage.
        pm = read(side, 'enter', 'pm')
        top = struct.unpack_from('>h', pm, 6)[0]
        y0 = struct.unpack_from('>h', port, 48)[0]
        y1 = struct.unpack_from('>h', result, 48)[0]
        if max(y0, y1) >= top:
            raise ValueError('clipping oracle bounds')
    if native:
        text = native.read_text()
        complete(text, native_status, 'PASS native relative Line continuation book=0',
                 '[Inferior 1 (Remote target) detached]')
        if text.count('PASS native original relative Line caller stack registers and pen position') != 1:
            raise ValueError('native ABI guard')
        if read('native', 'enter', 'port')[48:58] != read('paired-reference', 'enter', 'port')[48:58]:
            raise ValueError('paired pen state')
        if read('native', 'return', 'clut')[4:] != read('paired-reference', 'return', 'clut')[4:]:
            raise ValueError('paired colours')
        for name in ('vis', 'clip'):
            if read('native', 'enter', name) != read('paired-reference', 'enter', name):
                raise ValueError('paired ' + name)
        for name, start, end in (('pm', 4, 14), ('pm', 32, 40),
                                 ('port', 16, 24), ('port', 80, 88)):
            if read('native', 'enter', name)[start:end] != read('paired-reference', 'enter', name)[start:end]:
                raise ValueError('paired drawing metadata ' + name)
        for phase in ('enter', 'return'):
            a, b = [read(side, phase, 'pixels') for side in ('paired-reference', 'native')]
            if any(a[y*652:y*652+648] != b[y*652:y*652+648] for y in range(401)):
                raise ValueError('paired defined pixels ' + phase)
    print('PASS relative Line: original bytes/ABI, relative pen and complete clipped-buffer preservation' +
          ('; paired native pixels/colours, registers and original continuation' if native else ''))


if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('--reference', type=Path, required=True)
    p.add_argument('--status', type=int, required=True)
    p.add_argument('--native', type=Path)
    p.add_argument('--native-status', type=int)
    p.add_argument('--paired-reference', type=Path)
    p.add_argument('--paired-status', type=int)
    a = p.parse_args()
    if a.native and a.native_status is None:
        p.error('--native requires --native-status')
    run(a.reference, a.status, a.native, a.native_status, a.paired_reference, a.paired_status)
