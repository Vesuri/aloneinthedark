# Development

## Build dependencies

The production game is the Amiga executable; there is no host game renderer.

- GNU make, a shell and Python 3 (plus `capstone` for the 68k sweeps).
- `m68k-amiga-elf-gcc/g++`, `elf2hunk`, vasm and Amiga NDK headers.
- `unar` and `hfsutils` to extract the original release.

`amiga/env.sh` adds the development toolchain under `~/.local` to PATH.
FS-UAE launchers use `${FSUAE_COMMON:-$HOME/.local/share/amiga/fsuae_common.sh}`
for shared, PID-scoped emulator/debug-port management; it is an external
developer dependency, shared with the other ports on this host. `KICKSTART`
selects your local boot ROM. `tools/ghidra` links to the shared Ghidra install.

```sh
. amiga/env.sh
make -C amiga clean
make -C amiga -j4
```

The output is `amiga/out/Alone.exe`. The build needs no copyrighted input.
`make -C amiga HIRES=1` selects the hires-interlaced default. Always clean when
changing other build flags or shared headers. Every link runs two audits:
`muldiv-audit` (no 32-bit software multiply/divide) and `probe-audit` (every
debugger-read global survives `--gc-sections`).

## Original data

Put your original archive in ignored `tmp/`, then:

```sh
make extract-original-data ARCHIVE=tmp/AloneInTheDark.img_.sit
make segments
```

The first writes `tmp/runtime-data/Alone In The Dark` (the raw resource fork)
and `tmp/runtime-data/Alone Data/`; see [install-original-data.md](install-original-data.md).
The second dumps the CODE resources to `tmp/segments/` for the 68k sweeps and
Ghidra.

## Running

```sh
cd amiga
. ./env.sh
./run.sh
```

`stage_original_data.sh` copies the extracted files next to the executable on
the emulated hard drive; override `AITD_APP_RSRC` and `AITD_DATA_DIR` for other
layouts.

## Debugging

```sh
cd amiga
. ./env.sh
make clean && make -j4 PROBES=1
EXTRA_ARGS="--warp_mode=1" GDBSCRIPT=runtime_status.gdb ./diag_run.sh 60
```

The runner stops early when an event-driven observer finishes; otherwise its
seconds argument is a safety ceiling, not proof of success. It stops only the
emulator it owns and keeps the output in `amiga/.run/gdb-out.log`.
`runtime_status.gdb` reports the stage, tick counters and the loud stop: the
loader's reason and segment, or the trap word, manager, routine and caller
(segment, offset). `wbstartup.gdb` checks the Shell startup branch.
`./debug.sh` gives an interactive source-level session.

The current display owner is `AitdScreen`; the interpreter boundary is
`MacLoader`. Keep changes at the documented interface and verify original
opcodes/operands before changing binary behavior.

## Static analysis

```sh
make host-tests         # host analysis fixtures
make trap-census        # tmp/trap-census.md, live sites and selectors
make m68k-sweep         # 68020-only instructions on reachable paths
make lowmem-scan        # reachable absolute Page-0 references
make entrypoints-check  # ghidra_scripts/entrypoints.csv matches CODE 0
```

The census and low-memory scan read the original resource fork directly, including
CREL, DATA, ZERO and DREL; no scratch scripts or Vette checkout are needed.
The census checks the 1.0 baseline of 1,115 sites / 242 distinct trap words.
Its 114 unresolved static transfers/decode stops remain listed for runtime
verification. D0 selectors are local static evidence, not a data-flow proof.

`lowmem-scan` reports 54 live Page-0 operands at 28 addresses, with original
encodings. CREL address fields and PEA address constants are excluded; genuine
memory operands in the same instruction remain visible. This conservative set
includes fallback paths (such as SysEnvirons glue); M1.4 must reconcile those
with the implemented system services before producing its patch table.

Trap names come from cxmon through `tools/gen_trap_names.py`, reused from Vette.
The generated `tmp/trap_names.lua` remains local-only. The generator accepts a
local cxmon `mon_atraps.h` path for offline use; otherwise it downloads the table.

`ghidra_scripts/` holds the headless Ghidra scripts used by Vette!
(entry marking, names, trap and call-graph dumps, listing export). Their
output belongs under ignored `tmp/` or `disasm/`.
