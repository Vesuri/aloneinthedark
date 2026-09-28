#!/usr/bin/env python3
"""Validate the actual native patcher against the complete original live census."""
import argparse
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--resource', type=Path)
    p.add_argument('--selftest', action='store_true')
    args = p.parse_args()
    with tempfile.TemporaryDirectory(prefix='aitd-lowmem-') as work:
        exe = str(Path(work) / 'check')
        subprocess.run(['c++','-std=c++17','-Wall','-Wextra','-Werror',
                        str(ROOT/'tools/test_lowmem.cpp'),'-o',exe],check=True)
        subprocess.run([exe],check=True)
        if args.resource:
            import trap_census as census
            from m68k_lowmem import references
            from capstone.m68k import M68K_AM_REGI_ADDR_DISP, M68K_REG_A5
            census.load(args.resource)
            walker = census.run_live()
            actual = {(seg,pc) for seg in census.CODE for pc,insn in walker.insn_at[seg].items()
                      if list(references(insn,census.RELOC[seg]))}
            rows = [tuple(map(int,line.split())) for line in
                    subprocess.check_output([exe,'--sites'],text=True).splitlines()]
            if {(row[0],row[1]) for row in rows} != actual or len(rows) != len(actual):
                raise ValueError('patch table and census differ')
            for seg,source in census.CODE.items():
                patched = subprocess.check_output([exe,'--patch',str(seg)],input=source)
                changed=set()
                for segment,offset,size,displacement,destination in rows:
                    if segment != seg:
                        continue
                    before=list(census.md.disasm(source[offset:offset+size],offset))
                    after=list(census.md.disasm(patched[offset:offset+size],offset))
                    if len(before)!=1 or len(after)!=1 or before[0].size!=size \
                            or after[0].size!=size or before[0].mnemonic!=after[0].mnemonic:
                        raise ValueError(f'instruction size/operation changed at {seg}:{offset:x}')
                    old_refs=list(references(before[0],census.RELOC[seg]))
                    if len(old_refs)!=1 or list(references(after[0],census.RELOC[seg])):
                        raise ValueError(f'absolute reference survived at {seg}:{offset:x}')
                    index=len(after[0].operands)-1 if destination else 0
                    # Immediate+memory operations have their EA as operand 1.
                    if before[0].mnemonic.split('.')[0] in ('cmpi','btst'):
                        index=1
                    memory=after[0].operands[index]
                    if memory.address_mode!=M68K_AM_REGI_ADDR_DISP \
                            or memory.mem.base_reg!=M68K_REG_A5 or memory.mem.disp!=displacement:
                        raise ValueError(f'wrong patched address at {seg}:{offset:x}')
                    # All other operands remain byte-equivalent as decoded.
                    before_text=before[0].op_str.split(', ')
                    after_text=after[0].op_str.split(', ')
                    if any(a!=b for n,(a,b) in enumerate(zip(before_text,after_text)) if n!=index):
                        raise ValueError(f'other operand changed at {seg}:{offset:x}')
                    changed.update(range(offset,offset+size))
                if any(a!=b and i not in changed for i,(a,b) in enumerate(zip(source,patched))):
                    raise ValueError('bytes changed outside patch sites')
                for offset in census.RELOC[seg]:
                    if patched[offset:offset+4] != source[offset:offset+4]:
                        raise ValueError('CREL field changed')
                # Whole-CODE validation rejects changes outside the known sites too.
                corrupt=bytearray(source);corrupt[-1]^=1
                if subprocess.run([exe,'--patch',str(seg)],input=corrupt,
                                  stdout=subprocess.DEVNULL).returncode!=1:
                    raise ValueError('changed original fingerprint accepted')
            print(f'PASS lowmem-original: census={len(actual)} patches={len(rows)} '
                  f'Page0-remaining=0 segments={len(census.CODE)} CREL-preserved=1')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
