#!/usr/bin/env python3
"""List live Page-0 operands, excluding CREL and PEA address constants.

Uses the same original-resource and live-root walk as trap_census.py. Offsets
include the CODE header. No original bytes are changed.
"""
import argparse
from collections import Counter
from capstone.m68k import (M68K_AM_ABSOLUTE_DATA_LONG,
                           M68K_AM_ABSOLUTE_DATA_SHORT, M68K_OP_MEM)
import trap_census as census


def references(insn, relocations):
    """Yield absolute memory operands, excluding relocated address fields.

    Absolute extensions are at the end of the instruction, except a MOVE
    source when a destination extension follows it. In that case the source
    extension immediately follows the opcode. This also handles two absolute
    operands without dropping a real destination alongside a relocated source.
    """
    if insn.mnemonic.split('.')[0] == 'pea':
        return
    operands = census.ops(insn)
    for index, operand in enumerate(operands):
        if operand.type != M68K_OP_MEM or operand.address_mode not in (
                M68K_AM_ABSOLUTE_DATA_LONG, M68K_AM_ABSOLUTE_DATA_SHORT):
            continue
        width = 4 if operand.address_mode == M68K_AM_ABSOLUTE_DATA_LONG else 2
        offset = insn.address + insn.size - width
        if insn.mnemonic.startswith('move') and index == 0:
            offset = insn.address + 2
        if width == 4 and offset in relocations:
            continue
        address = operand.imm & 0xffffffff
        if address < 0x0c00:
            yield address


def selftest():
    # Positive references, an A5-relocated JSR, PEA constant, and mixed MOVE.
    code = bytes.fromhex('20380156 207809de 20390000016a '
                         '4eb900000022 48780004 21f900000022016c 4e75')
    instructions = list(census.md.disasm(code, 0))
    got = [(i.address, a) for i in instructions for a in references(i, {16, 26})]
    expected = [(0, 0x156), (4, 0x9de), (8, 0x16a), (24, 0x16c)]
    assert got == expected, (got, expected)
    print('PASS lowmem-selftest true_refs=4 crel_excluded=2 pea_excluded=1')


def scan(resource):
    census.load(resource)
    walker = census.run_live()
    found = []
    for segment in sorted(census.CODE):
        for pc, insn in sorted(walker.insn_at[segment].items()):
            for address in references(insn, census.RELOC[segment]):
                found.append((segment, pc, address, bytes(insn.bytes).hex(),
                              insn.mnemonic, insn.op_str))
    counts = Counter(row[2] for row in found)
    print(f'{len(found)} live Page-0 operands; {len(counts)} distinct addresses')
    print(', '.join(f'${a:04X} x{n}' for a, n in sorted(counts.items())))
    for seg, pc, address, encoding, mnemonic, operands in found:
        print(f'  ({census.seg_label(seg)}, ${pc:04X}) -> ${address:04X} '
              f'{encoding:<20} {mnemonic} {operands}')
    print(f'PASS lowmem-scan references={len(found)} addresses={len(counts)} '
          f'unresolved={len(walker.blind)}')
    return found


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('resource', nargs='?', default='tmp/runtime-data/Alone In The Dark')
    parser.add_argument('--selftest', action='store_true')
    args = parser.parse_args()
    selftest()
    if not args.selftest:
        scan(args.resource)
