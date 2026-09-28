#!/usr/bin/env python3
"""Compile the actual native patcher and check its fixture and original CODE 1."""
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
        subprocess.run(['c++', '-std=c++17', '-Wall', '-Wextra', '-Werror',
                        str(ROOT/'tools/test_startup_lowmem.cpp'), '-o', exe], check=True)
        subprocess.run([exe], check=True)
        if args.resource:
            import trap_census as census
            from m68k_lowmem import references
            from capstone.m68k import M68K_AM_REGI_ADDR_DISP, M68K_REG_A5
            census.load(args.resource)
            walker = census.run_live()
            actual = {pc for pc, insn in walker.insn_at[1].items()
                      if list(references(insn, census.RELOC[1]))}
            rows = [tuple(map(int, line.split())) for line in
                    subprocess.check_output([exe, '--sites'], text=True).splitlines()]
            if {row[0] for row in rows} != actual or len(rows) != 10:
                raise ValueError('CODE 1 patch table and census differ')
            source = census.CODE[1]
            patched = subprocess.check_output([exe, '--patch'], input=source)
            changed = set()
            for offset, size, displacement in rows:
                before = list(census.md.disasm(source[offset:offset+size], offset))
                after = list(census.md.disasm(patched[offset:offset+size], offset))
                if len(before) != 1 or len(after) != 1 or before[0].size != size \
                        or after[0].size != size or before[0].mnemonic != after[0].mnemonic:
                    raise ValueError(f'instruction changed size/operation at {offset:x}')
                memory = [op for op in after[0].operands
                          if op.address_mode == M68K_AM_REGI_ADDR_DISP]
                if len(memory) != 1 or memory[0].mem.base_reg != M68K_REG_A5 \
                        or memory[0].mem.disp != displacement:
                    raise ValueError(f'wrong patched address at {offset:x}')
                changed.update(range(offset, offset+size))
            if any(a != b and i not in changed for i, (a,b) in enumerate(zip(source,patched))):
                raise ValueError('patch changed bytes outside its sites')
            print('PASS startup-lowmem-original: census=10 patches=10 lengths-preserved=10')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
