#!/usr/bin/env python3
"""Generate local-only metadata for the MAME trap logger from original bytes."""
import argparse
import struct
from capstone.m68k import M68K_OP_MEM, M68K_AM_ABSOLUTE_DATA_LONG
from pathlib import Path
import trap_census as c

def driver_calls(data, instruction_offsets):
    """Only the byte-checked indirect call, with a supported caller cleanup."""
    return [pc+4 for pc in sorted(instruction_offsets)
            if data[pc:pc+6] == bytes.fromhex('206df9544e90')
            and data[pc+6:pc+8] in (bytes.fromhex('508f'),bytes.fromhex('588f'))]


def selftest():
    data=bytes.fromhex('206df9544e90508f 206df9544e90588f 206df9544e904e75')
    assert driver_calls(data,{0,8,16}) == [4,12]
    assert driver_calls(data,{8}) == [12]  # data lookalikes are not instructions
    assert driver_calls(bytes.fromhex('206df9504e90508f'),{0}) == []
    print('PASS mac-trap-map-selftest cleanup=2 noninstruction=1 wrong_pointer=1')


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('resource', nargs='?', default='tmp/runtime-data/Alone In The Dark')
    p.add_argument('--output', default='tmp/mac-trap-map.lua')
    p.add_argument('--selftest', action='store_true')
    a = p.parse_args()
    if a.selftest:
        selftest()
        return
    c.load(a.resource)
    w = c.run()
    live = c.run_live()
    trap_sites = sorted({(seg, pc, word) for seg, pc, word, _ in w.traps + live.traps})
    lines = ['-- Generated from local original resources; do not commit.', 'return {segments={']
    for n, data in sorted(c.CODE.items()):
        traps = ','.join(f'{{{pc},{word}}}' for seg, pc, word in trap_sites if seg == n)
        name = c.SEGNAME[n] or 'CODE1'
        writes=[]
        for pc,insn in sorted(w.insn_at[n].items()):
            operands=c.ops(insn)
            if (insn.mnemonic not in ('move.w','clr.w','or.w') or not operands
                    or operands[-1].type != M68K_OP_MEM
                    or operands[-1].address_mode != M68K_AM_ABSOLUTE_DATA_LONG):
                continue
            off=pc+insn.size-4
            if c.RELOC[n].get(off) != 'A5':
                continue
            address=struct.unpack_from('>I',data,off)[0]
            if address in (0xfffee50c,0xfffee508,0xfffee510):
                opcode=struct.unpack_from('>H',data,pc)[0]
                writes.append(f'{{{pc},{pc+insn.size},{opcode},{(1<<32)-address}}}')
        input_writes=','.join(writes)
        # Exact original driver-indirect call sequence, including stack cleanup.
        calls=','.join(map(str,driver_calls(data,w.insn_at[n])))
        lines.append(f'[{n}]={{name="{name}",size={len(data)},traps={{{traps}}},input_writes={{{input_writes}}},driver_calls={{{calls}}}}},')
    lines += ['},jt={']
    for n, off in c.JT:
        opcode = int.from_bytes(c.CODE[n][off:off+2], 'big')
        lines.append(f'{{{n},{off},{opcode}}},')
    lines += ['}}', '']
    Path(a.output).write_text('\n'.join(lines))
    print(f'PASS mac-trap-map segments={len(c.CODE)} entries={len(c.JT)}')


if __name__ == '__main__':
    main()
