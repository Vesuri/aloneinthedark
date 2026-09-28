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
Always clean when changing build flags or shared headers. Every link runs two audits:
`no-float-audit` (no libgcc floating-point helpers) and `probe-audit` (every
debugger-read global survives `--gc-sections`). C/C++ uses
`-m68020 -mtune=68020 -msoft-float`; GNU as uses `-mcpu=68020 -mno-float`
(it has no `-mtune` option). Integer multiplication/division uses native C/C++;
the 68000 helper header is retired.

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

The default and sole active configuration is `a1200-020`: A1200, 68EC020,
AGA, 2 MB chip / 8 MB fast, no FPU/MMU/JIT. Other CPU configurations fail
with `CONFIG / DEFERRED CPU TARGET`; their support is deferred to M5.0.
All three launchers share these settings and write the emulator core log to
`amiga/.run/logs/fs-uae.log.txt`.

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
The census checks the 1.0 baseline of 1,129 sites / 244 distinct trap words.
Its 115 unresolved static transfers/decode stops remain listed for runtime
verification. D0 selectors are local static evidence, not a data-flow proof.

`lowmem-scan` reports 58 live Page-0 operands at 29 addresses, with original
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

The MAME runtime logger and its bounded session are documented in
[mac-reference-loop.md](mac-reference-loop.md#runtime-trap-evidence).
`make mac-trap-map` generates local original-byte metadata; the report attributes
calls using per-record live jump-table targets and rejects missing state proofs.
M0.2 added the runtime-confirmed CODE 1 cache helper at `$021E`/`$026E` to the
census: `$A0BD` was the new distinct trap; `$A346`/`$A746` were new sites for
already-known words. The original bytes are checked before these extra roots
are walked. The additional low-memory operands both access `CPUFlag` (`$012F`).

M0.3 verification: clean 68020 build linked with `no-float-audit: clean` and
`probe-audit: clean (33 symbols)`. A real soft-float compilation fixture was
rejected for `__addsf3` and `__floatsidf`. A bounded A1200/68020 diagnostic run
reached the unchanged `SEGMENT LOADER / CREL RELOCATION`, CODE 3, state 2,
10 jump entries. This is the expected current stop, not a gameplay/boot pass.

M0.4 verification: clean build and both link audits pass (30 retained probes);
the `PROBES=1 FILLWATCH=1` clean build also passes (78 probes).
The bounded 68020 run still reaches the CODE 3 CREL relocation stop. Captures
made immediately after drawing that same stop compare byte-for-byte equal:
98,304 planar bytes. The launcher now matches its documented A1200, 2 MB chip /
8 MB fast configuration. The eight-plane game display remains M2.4 work.

The Shell message `cannot read Alone In The Dark` / returncode 20 is a startup
failure, not the expected CREL stop. It covers file open, size, allocation and
read failures. Check the staged file and OS-visible memory; the exploratory
68040 configuration produced this failure with its fast RAM unconfigured.

M0.6 verification (68020-only scope per owner): clean build and both audits
pass (30 probes). The bounded default run reports emulator CPU=68020,
FPU/MMU/JIT=0, 24-bit addressing, Exec.AttnFlags=$0003, and 8 MB Z2 fast RAM
at $00200000. It reaches `SEGMENT LOADER / CREL RELOCATION`, CODE 3, state 2,
10 jump entries, before the 45-second ceiling. Shell syntax checks pass;
deferred CPU selections and conflicting CPU overrides are rejected. This is
configuration acceptance only, not the still-unimplemented boot regression.

## Regression

`make regression` (or `amiga/regression.sh boot`) clean-builds, runs a bounded
68020 observer and requires exactly one `boot PASS: reached CODE 3+$03e4`
record. Any loud stop, debugger error, nonzero observer exit or deadline expiry
fails. The observer checks the original main-entry bytes before placing its
breakpoint. The boot test ends at main entry; it does not claim startup or play.

The runner clears stale logs/state, propagates debugger failures, returns 124
on timeout and cleans up its owned processes on exit. Build evidence is in
`amiga/.run/regression-build.log`; the observer log is `amiga/.run/gdb-out.log`.

Harness verification includes ten host acceptance/rejection fixtures and an
intentionally nonterminating observer that returns 124. M1.3a updates the boot
observer to wait for CODE 1+$AA, after the original Core relocation, then checks
the unchanged main bytes before placing its breakpoint. `make regression`
passes on `a1200-020`: exactly one `boot PASS: reached CODE 3+$03e4`, no loud
stop before that endpoint, normal observer exit and both clean-build audits.
Initialization beyond that point still has the named NewHandleClear stop.

## Line-A and stack probe

Clean-build with `make -C amiga LINEAPROBE=1`, then run from `amiga/`:
`EXTRA_ARGS=--warp_mode=1 GDBSCRIPT=line_a.gdb ./diag_run.sh 30`.
The probe uses real native Line-A instructions on the dedicated 64 KB stack;
it does not replace original game instructions.

M1.1 evidence: vector at VBR+$28 ($00000028 on the tested A1200) changes from
$00F80ADE to the port handler and is restored after both RTS and ExitToShell.
D0.W zero/positive/negative returns produce CCR $14/$10/$18 from input $1F;
Toolbox retains $1F. A callback deliberately overwrites CCR and A5, and the
caller still receives CCR $14 and A5 $12345678. QDExtensions selector
$56780001 dispatches as selector 1. The entry SP is exactly stack base+65532.
CurrentA5 $004905F8 minus CurStackBase $0047DE98 is 75,616, matching the original
CODE 0 header. Probe and production link audits pass (36/35 retained symbols).
Low-memory instruction redirection remains M1.4; these values currently live
in the private shadows. Production startup now reaches main (see below).

## A5 initializer model

`make a5world-check` validates the original CODE 0 header and hashes the original
CODE 1+$0118–$0193 initializer before modeling DATA/ZERO and DREL. It checks
exact input consumption and the planning model's golden digests. `make
host-tests` includes malformed/truncated streams, zero-length zero runs,
short/long and STRS-tagged relocations, 32-bit addition wrap and dump mismatch
checks. This is a host model, never a substitute for running CODE 1.

At the first instruction of Core+$03E4, dump exactly `[A5-75616,A5)` and obtain
the actual STRS data pointer (CODE 1+$08 after startup). Then compare with:

```sh
python3 tools/a5world_check.py 'tmp/runtime-data/Alone In The Dark' \
  --a5 <actual-address> --strs <actual-address> --dump tmp/amiga-a5-globals.bin
```

The initializer owns the below-A5 globals. Loaded jump entries above A5, the
CODE 1 trap-patch storage, and the port's shadows are separate M1.3/M1.4 checks.
No mismatching bytes are ignored. The tool reports each of the first twenty
mismatching A5 offsets and fails on a wrong dump length or any mismatch.

M1.2 verification: all host checks pass. The original has 11,418 DATA bytes,
560 ZERO bytes, 280 zero runs, 276 DREL entries (255 A5 / 21 STRS), including
63 long-form offsets. Both streams consume exactly into 75,616 bytes. A local
comparison fixture passes at zero mismatches; corrupting one byte reports
A5−75,516 and exits 1. This fixture is not a live Amiga dump; that evidence is
still required by M1.3.

M1.2a startup-census correction, found while preparing M1.3: explicitly include
CODE 1+$0060 (LoadSeg) and +$00CC (UnLoadSeg). Their original prologues drop a
return address, so the ordinary function-prologue heuristic missed them.
Byte-checked roots add 11 trap sites and the conditional $A9FF Debugger word:
1,129 sites / 244 words, with 115 unresolved transfers still listed. The
low-memory scan adds ResLoad at +$006A and LoadTrap at +$00BE, giving 58
references at 29 addresses. The runtime report now requires every observed
(segment, offset, trap) site to exist in the static census, not merely its
trap word. Acceptance: all 632 sites in the M0.2 reference log are covered;
host fixtures reject an unseen site even when its trap word is known.

M1.2b startup low memory: `StartupLowMemory.h` holds ten original-byte-checked
CODE 1 sites. Patching is atomic and happens before takeover. The A5 allocation
now includes 80 shadow bytes at A5+$0EC0; CurrentA5 and CurStackBase are real
allocation addresses, CPUFlag=3 matches the Mac IIx reference, LoadTrap=0, and
the fallback address mask is $FFFFFFFF (the port's StripAddress identity).
The other 48 census sites remain M1.4 work.

`make startup-lowmem-check` compiles the actual C++ patcher on the host and
compares its table to the original-resource census. All ten instruction lengths
and operations are preserved; all 44 original-byte mutations are rejected with
no partial patch. `make host-tests` includes the input-free patcher fixtures.

Bounded native check: `GDBSCRIPT=startup_lowmem.gdb EXTRA_ARGS=--warp_mode=1
./diag_run.sh 30` from `amiga/` passes for all ten operands (A5 $00490610,
shadows $004914D0, CurStackBase $0047DEB0). A deliberately corrupted local
resource copy returns false before screen initialization, verified with
`GDB_ENTRY=MacLoader::prepareResourceForks GDBSCRIPT=startup_reject.gdb`.
The original file and restored staging copy retain the same SHA-256. Host
checks, the original A5-model check and both link audits pass (38 probes).
The current game reaches the initialization stop described below.


## Original startup and trap patches

M1.3 replaces resident pre-resolution with CODE 1+$14. Only CODE 0 metadata and
CODE 1 are copied at launch; JT entries 0–9 are loaded and the other 458 retain
the original unloaded form. `GetResource(CODE)` creates aligned private copies.
CODE 1 expands DATA/ZERO, applies DREL, patches LoadSeg/UnloadSeg/ExitToShell,
and performs every CREL relocation. Resource handle lock state comes from the
resource attributes. Full zone/purge ownership remains M1.5; disk reads M2.2.

The per-trap callable original is `AFFE, trap-word, RTS`, accepted only within
the port's stub array. OS patches use the register/return conventions measured
from the System 7.5.5 dispatcher at $DD60–$DDE2; the local reference capture is
`tmp/m1.3-dispatch.log` (explicit PASS), with RAM/ROM bytes retained in `tmp/`.
The M0.2 trap log confirms zero D0 from Get/SetTrapAddress, the locked resource
state $A0, and cache-flush success. StripAddress intentionally retains native
32-bit addresses. Unsupported HWPriv selectors and SysError remain named stops.

The expanded `LINEAPROBE=1` / `line_a.gdb` probe verifies callable originals,
OS patch input registers, preservation of D1/D2/A1/A2, both A0-result variants,
D0.W-derived CCR, Toolbox Pascal argument/result cleanup and balanced stacks.
It also exercises vCacheFlush and HWPriv 1/3. All pass, alongside the earlier
Line-A vector, 64 KB stack, callback CCR and QDExtensions selector checks.

For production startup evidence, run from `amiga/`:

```sh
GDBSCRIPT=original_startup.gdb EXTRA_ARGS=--warp_mode=1 ./diag_run.sh 30
```

The observer checks original loader/main bytes, CODE residency and the first
Core CREL long. It dumps `tmp/amiga-a5-globals.bin` at main and prints the actual
A5/STRS bases for `a5world_check.py`. It succeeds only at the expected subsequent
`MEMORY MANAGER / NEWHANDLECLEAR`, Engine+$004A, trap $A322. This stop belongs to
M1.5, and is not a gameplay pass. `runtime_status.gdb` independently reports it.
The boot observer independently reaches main and passes (M1.3a).

Production evidence: A5 $004680D8, STRS $002E88C4, zero mismatches across all
75,616 bytes. Core header becomes $000A; Core+$000E is $0045BE8E, exactly
$FFFF3DB6 + A5 modulo 32 bits. Initial CODE mask $3 becomes $B at main.
The independent status observer reports 68020, FPU/MMU/JIT=0, trap $A322 at
Engine+$004A. Host checks and production link audits pass (40 probe symbols).
