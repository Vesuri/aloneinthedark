#!/usr/bin/env python3
"""Compare InitGraf patterns and reject the observed m68k copy miscompile."""
import argparse
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
EXPECTED = bytes.fromhex('77dd77dd77dd77dd8822882288228822aa55aa55aa55aa55ffffffffffffffff0000000000000000')
BAD_COPY = re.compile(r'\bmove\.[bwl]\s+\((a[0-7])\)\+,\([^)]*\b\1\b')

def check(reference, native, reference_status, native_status, elf):
    for side, text, status, marker in (
        ('reference', reference, reference_status, 'PASS original InitGraf five patterns bytes=40'),
        ('native', native, native_status, 'PASS identity: SysEnvRec=16 Gestalt=8 Engine-flags=11 startup=Core+0460 result=0 alerts=0')):
        if status != 0 or text.count(marker) != 1 or re.search(r'FAIL|Error in|TIMEOUT|Program received signal', text):
            raise ValueError(side+' incomplete capture')
        terminal = 'Exited via the debugger' if side == 'reference' else '[Inferior 1 (Remote target) detached]'
        if text.count(terminal) != 1:
            raise ValueError(side+' missing normal termination')
        if (ROOT/f'tmp/qd-patterns-{side}.bin').read_bytes() != EXPECTED:
            raise ValueError(side+' white/black/gray/light/dark pattern bytes')
    assembly = subprocess.run(['m68k-amiga-elf-objdump', '-d', str(elf)], check=True, capture_output=True, text=True).stdout
    if not assembly.strip():
        raise ValueError('empty linked-program disassembly')
    bad = [line.strip() for line in assembly.splitlines() if BAD_COPY.search(line)]
    if bad:
        raise ValueError('same-register postincrement/indexed copy: '+repr(bad))
    print('PASS InitGraf patterns: five Mac/native patterns, 40 exact bytes, startup success and no same-register postincrement copy in linked program')

if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('reference', type=Path)
    p.add_argument('native', type=Path)
    p.add_argument('--reference-status', type=int, required=True)
    p.add_argument('--native-status', type=int, required=True)
    p.add_argument('--elf', type=Path, default=ROOT/'amiga/out/AloneInTheDark.elf')
    a = p.parse_args()
    try:
        check(a.reference.read_text(), a.native.read_text(), a.reference_status, a.native_status, a.elf)
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        raise SystemExit('FAIL InitGraf patterns: '+str(error))
