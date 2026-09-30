# Development

## Build dependencies

The production game is the Amiga executable; there is no host game renderer.

- GNU make, a shell and Python 3 (plus `capstone` for the 68k sweeps).
- `m68k-amiga-elf-gcc/g++`, `elf2hunk`, vasm and Amiga NDK headers.
- `unar` and `hfsutils` to extract the original release.

`amiga/env.sh` adds the development toolchain under `~/.local` to PATH.
FS-UAE launchers source `amiga/fsuae.sh`, which uses
`${FSUAE_COMMON:-$HOME/.local/share/amiga/fsuae_common.sh}` for shared,
PID-scoped process management. The default debugger port is **24377**, outside
the shared helper's 40-port hash range; `DEBUG_PORT` can override it. Only this
project's recorded emulator may be stopped. Any remaining listener causes a
named busy-port failure; it is never killed merely for owning the port.
This completes M2.3g34a: the shared default collided with Pokeri at 2377.
Default/override/busy-port fixtures pass; a real occupied TCP listener survives
a refused launch, and native startup connects on 24377. The helper remains an
external dependency. `KICKSTART`
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

The temporary default is `a4000-020` (`AMIGA_MODEL=A4000`), approved by the
owner on 2026-09-30 to shorten test runs. It uses AGA, 68EC020 at maximum
emulator speed without cycle-exact timing, 2 MB chip / 8 MB fast, and no
FPU/MMU/JIT. `AMIGA_CONFIG=a1200-020` (or `AMIGA_MODEL=A1200`) retains the
14 MHz cycle-exact hardware baseline. Explicit `AMIGA_CONFIG` takes precedence
over the model selector. Fast runs establish functionality, not A1200 timing. Other CPU configurations fail
with `CONFIG / DEFERRED CPU TARGET`; their support is deferred to M5.0.
The changed default passes the bounded original-code boot observer (exit 0);
the emulator reports `CPU=68020, FPU=0, MMU=0, JIT=0`, prefetch fast 24-bit.
Eight configuration selection/rejection checks and shell syntax checks pass.
All three launchers share these settings and write the emulator core log to
`amiga/.run/logs/fs-uae.log.txt`.

`stage_original_data.sh` copies the original application folder into `data/`
beneath the executable directory on the emulated hard drive. The port executable
and diagnostic files remain outside this Mac-visible namespace. Override
`AITD_APP_RSRC` and `AITD_DATA_DIR` for extraction locations; the two original
root extras and companions must be beside `AITD_APP_RSRC`. Saves and preferences
retain their separate `Saved Games/` and `prefs/` native mappings. The launcher
also stages the port-owned `resources/overlay.rsrc` beside the executable. A
manual installation must copy that file to `PROGDIR:overlay.rsrc`; a missing or
invalid overlay fails explicitly.

## Debugging

```sh
cd amiga
. ./env.sh
make clean && make -j4 PROBES=1
EXTRA_ARGS="--warp_mode=1" GDBSCRIPT=runtime_status.gdb ./diag_run.sh 60
```

The runner stops early when an event-driven observer finishes; otherwise its
seconds argument is a safety ceiling, not proof of success. Debugger command
files run in batch mode so command errors return a failing process status. It stops only the
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

M1.2b startup low memory: `LowMemory.h` includes ten original-byte-checked
CODE 1 sites. Patching is atomic and happens before takeover. The A5 allocation
now includes 80 shadow bytes at A5+$0EC0; CurrentA5 and CurStackBase are real
allocation addresses, CPUFlag=3 matches the Mac IIx reference, LoadTrap=0, and
the fallback address mask is $FFFFFFFF (the port's StripAddress identity).
M1.4 extends this to the complete live table, described below.

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


## Complete low-memory redirection

`LowMemory.h` extends the Vette same-length A5 redirection to all 58 live
operands at 29 addresses. The shadow area is 160 bytes at A5+$0EC0. The $016C
word shares the low half of $016A Ticks. MOVE destination fields and source
instructions with a trailing destination extension have distinct encodings;
the patcher preserves every other operand and all CREL fields.

`make lowmem-check` compiles the actual C++ patcher, compares its complete
table with `make lowmem-scan`, checks all 13 original CODE fingerprints and
lengths, and verifies no absolute Page-0 operand remains in the census live set.
The static census still reports its 115 unresolved indirect transfers; this
is not a claim that arbitrary unseen code has been proven safe. Modified
original CODE is rejected, including modifications outside the listed sites.
Host fixtures reject all 264 single-byte site corruptions without a partial
patch, wrong lengths, repeat patching and invalid segment IDs. They verify
shadow bounds and permit only the intentional Ticks overlap.

Native acceptance (`GDBSCRIPT=lowmem.gdb EXTRA_ARGS=--warp_mode=1
./diag_run.sh 30`) passes: 58 sites validated before takeover, 50 applied to
CODE 1/Core/Engine at the current stop, ten fields advance Ticks by twelve,
and the published shadow equals `g_macTicks`. A changed final byte in CODE 3,
outside every patch site, is rejected before screen takeover using
`startup_reject.gdb`. Restored original staging passes boot regression.

The original-startup dump remains exact (A5 $00468AF0, STRS $002E92DC, zero
mismatches in 75,616 bytes). Both production audits pass (42 probe symbols).
Address redirection does not supply missing subsystem values: zone/error
shadows belong to M1.5, system identity to M1.6, and scrap/sound state to their
services. That low-memory checkpoint reached Engine+$004A; the current stop is listed below.


## Zone allocator core

M1.5 is split into independent core (M1.5a) and runtime integration/reference
acceptance (M1.5b). `MacHeap` owns no host allocations: the caller supplies an
aligned arena, and data blocks plus non-moving master-pointer blocks live
inside it. Pointer and locked-handle barriers bound compaction. Handle flags
live beside master-pointer arrays, never in address bits. Free/largest-space
queries account for actual blocks. Resizing preserves payloads; failed
reallocation preserves the old pointer. Emptying preserves handle identity,
while disposal makes the master slot reusable.

`make host-tests` includes allocation, zeroing, lock/purge interactions, in-place
pointer growth, handle growth/shrink, MoveHHi, reusable master slots, overflow
rejection and 2,500 deterministic fragmentation steps with every live payload
checked after each step. Interleaved master blocks exercise movement around
pinned metadata. `python3 tools/check_mac_heap.py --sanitize` additionally runs
address and undefined-behavior sanitizers; it passes. The core is connected to Memory Manager traps and resource handles.

The API/zone-field reference is Apple's [Inside Macintosh: Memory Manager](https://developer.apple.com/library/archive/documentation/mac/pdf/Memory/Memory_Manager.pdf).
`tools/mac_traps.lua` now records zone, ApplLimit, zcbFree (the FreeMem value),
master-block size, MemErr and raw master-pointer data in its existing trap
action. Using a second breakpoint at the dispatcher would omit game records:
MAME runs only the first matching breakpoint. The local reference capture
`tmp/m1.5-reference.log` finishes with an explicit PASS. At the first
Engine+$004A NewHandleClear, free=$53F8; after MaxApplZone and startup work,
the next call at that same site has free=$2B0820. The 12 MoreMasters calls
allocate 64 master pointers apiece, consuming $108 bytes each. These are
reference observations, not values for the port to return unconditionally.


## Application-zone integration and reference acceptance

The application zone reserves 3,145,728 bytes of fast RAM; a separate 131,072-byte
system zone serves system allocations. Mac globals and stack remain outside the
zone. Resource handles now use its master blocks, flags, allocation and disposal;
whole-fork disk buffering has been replaced by bounded source reads (M2.2b2).
MemErr and ApplLimit are published into private low-memory shadows, and ResError
reads the actual ResErr shadow (including original-code writes).

Clean `HEAPPROBE=1` plus `GDBSCRIPT=heap.gdb EXTRA_ARGS=--warp_mode=1
./diag_run.sh 30` passes three native Line-A stages: clear allocation, Ptr size,
handle size/state/lock/movement, Empty/Reallocate/RecoverHandle, system-zone
selection, PtrToHand contents, MemErr and exact FreeMem recovery. The separate
LINEAPROBE run passes register, CCR, callback, stack, vector and callable-original
checks. Production host tests, sanitizers, original-byte checks, boot regression,
low-memory publication and runtime observer all pass on the pinned 68020.
The original A5 dump has zero mismatches across 75,616 bytes (A5 $00786E48,
STRS $00443ED0). The next named stop is Gestalt('sysv'), Core+$3D36.

The paired heap checkpoint is **before the first Core+$3D36 Gestalt('sysv')**.
MAME's zone header reports FreeMem=2,821,316; native FreeMem=3,096,720. A full
block walk independently equals each header. The allowed difference at this
checkpoint is 275,404 bytes, fully accounted for (zero unaccounted margin):

| Source of additional native free space | Bytes |
| --- | ---: |
| Zone span: native 3,145,728 versus Mac 3,025,368 | 120,360 |
| Nine unused Mac CODE blocks, exact original bytes (4–6, 8–13) | 149,260 |
| Other Mac handle blocks, beyond four common resources and the 132-byte handle | 6,628 |
| Additional native 32-byte handle, including header | -56 |
| Larger native headers/alignment for the five common handles | -96 |
| Mac pointer/master blocks 3,872 versus native 4,536 | -664 |
| Zone header/trailer 52 versus 80 | -28 |
| **Total** | **275,404** |

This measures allocation differences; it does not assign guessed purposes to
unidentified Mac manager blocks. The nine unused CODE payloads total 149,180
bytes and are byte-identical in the Mac dump; avoiding these copies follows D1.
The separate native globals/stack and fixed SIZE arena explain the zone-span
difference. No fake FreeMem constant is returned.

`original_startup.gdb` writes the native heap to `tmp/amiga-heap.bin`. The local
MAME capture at the byte-checked $DD60 dispatcher saved [AppZone, bkLim) on
A1AD with D0='sysv' and finished with `PASS heap-dump captured` and
`PASS heap-reference capture completed`. Recheck the paired evidence with:

```sh
python3 tools/check_heap_capture.py tmp/m1.5-mac-heap.bin tmp/amiga-heap.bin \
  'tmp/runtime-data/Alone In The Dark'
```

The observer requires the measured baseline and verified unused resource bytes;
any changed allocation balance requires a new explained capture, not a widened
percentage tolerance. Native master pointers remain clean addresses, with flags
in side storage. Startup and the native probe exercise StripAddress, HGetState
and HSetState without relying on the reference's high-byte pointer flags.


## System identity (M1.6a)

The original reference capture (`tmp/m1.6-reference.log`, explicit PASS) gives:

| Query | D0 | A0 response |
| --- | --- | --- |
| Gestalt `sysv` | 0 | $0755 |
| `proc` | 0 | 4 (Mac reference 68030) |
| `qd  ` | 0 | $0230 |
| `help`, `fold`, `evnt` | 0 | 1 |
| `qtim` | $0000EA51 (-5551 in D0.W) | 0 |
| `a/ux` | $0000EA52 (-5550 in D0.W) | 0 |

SysEnvirons version 1 returns the complete 16-byte record
`00010005 07550004 01010005 003A8053`: version 1, Mac IIx (5), System 7.5.5,
processor 4, FPU and Color QuickDraw present, keyboard 5, AppleTalk driver $3A,
system-volume reference $8053. These describe the Mac reference, not native
Amiga hardware; the Amiga remains 68020 with no FPU. The File Manager catalog
must map the returned Mac volume reference. SysVersion's shadow is $0755.
Unsupported SysEnvirons layouts and unmeasured Gestalt selectors remain stops.

The normal game skips QuickTime's Gestalt call because the QuickTime trap is
absent. A local reference probe queried `qtim` through the original, byte-checked
Core+$3D36 instruction, then restored D0/A0/SR and re-executed the original
query. Its caller received the original result. The remaining answers and
SysEnvRec were captured without intervention. `tools/mac_traps.lua` now
records all SysEnvRec bytes on the original trap return.

`identity.gdb` validates the actual SysEnvirons record and six natural Gestalt
returns, then compares the eleven Engine flags at Engine+$43E2 against MAME:
`01010101 01010100 0101 01` (offsets 4 through 14). This exposed and fixed an
inherited missing WaitNextEvent entry. Its availability now matches the Mac;
execution remains a named stop pending M3.1. Unknown Toolbox availability is
not claimed from this one observation.

A clean `IDENTITYPROBE=1` build with `identity_errors.gdb` executes native
Line-A instructions: QuickTime and A/UX return the exact captured errors, and
an unmeasured selector stops explicitly. An initial debugger-register injection
still executed the original sysv query, so the maintained probe sets arguments
in actual 68020 instructions. No game instruction is patched. The production
identity observer and diagnostic error probe both pass in bounded 68020 runs.

The next stop is HFSDispatch selector 8, GetFCBInfo, at Core+$4144. File Manager
work is M2.1 after M1.7's system windows. Full startup's success/requirements-alert
branches remain beyond that dependency, so **M1.6b retains that acceptance
check** after file/resource integration; matching identity flags is not reported
as a successful application launch.


## User-mode service bridge (M1.7a)

The Line-A handler recognizes a deferred-service result before changing USP or
CCR. It returns via RTE to a trampoline derived from Vette's existing user-mode
VBL trampoline. The trampoline parks D0–D7/A0–A6, CCR and the resume PC, calls
C++ in user mode, then restores the resulting image after moving it over consumed
Pascal parameters. The bridge preserves callable-original Toolbox return PCs
and OS flag variants. OS results set CCR from D0.W; Toolbox preserves CCR.
Nested ordinary traps suppress callback delivery until the outer service ends.
Recursive services and unsupported supervisor/exception frames are named stops.

Clean `SERVICEPROBE=1`, then `GDBSCRIPT=service.gdb EXTRA_ARGS=--warp_mode=1
./diag_run.sh 30`, passes: four services, two callable originals, four nested
ordinary traps, one callback, all 15 registers, OS/Toolbox CCR and balanced stack.
The nested traps' saved exception SRs positively establish user-mode execution;
a zero counter cannot pass. Existing LINEAPROBE, clean production boot,
original startup and identity observers pass. HFSDispatch now enters one user
service and reaches the same named GetFCBInfo stop (zero completed services).

This is independently verified bridge work, not OS-window acceptance. The
machine is still taken over during services. M1.7b retains the full 1 MB/64 KB
file-read, checksum, picture, timing and OS-handback acceptance on the 68020.
No disk-read or display-continuity success is inferred from this ABI probe.


## System-window core (M1.7b1)

`make regression` runs `window-core` followed by a clean production `boot`.
The window case generates its 1 MiB fixture in ignored staging, clean-builds
`WINDOWPROBE=1 PROBES=1`, runs a bounded observer, and checks all three 98,304-byte
bitplane snapshots against the generated pattern. A stale file, missing PASS,
nonzero runner status, late display publication or wrong saved-file bytes fails.
The snapshot SHA-256 is
`0482278141cfa90510f767999d9e6b5a21c72429ad8d315b68f224fe1c9b81ba`.
These are chip-memory snapshots, **not captures of rendered video**; M1.7b2
retains actual-picture acceptance. The owner subsequently permitted leaving
that verification pending when the reference capture methods require access
that is not granted; see the pending section in `open-work.md`.

The window restores the OS Line-A and keyboard vectors, adds a priority-127
port VERTB server to the saved OS chain, restores OS interrupt enables while
retaining the port's enables, and permits scheduling. The operation runs in
the user-service task. On return it forbids scheduling, flushes stale keyboard
state while interrupts still run, then briefly masks interrupts to retake the
vectors. Copper/display DMA and Paula vectors are never deliberately replaced.
The existing 50-field/60-tick VBI clock continues through OS windows; the probe
checks the exact field/tick ratio and the private Ticks shadow.

The diagnostic sends a silent 1 KiB chip-memory loop through Paula AUD0 and
counts actual completion interrupts both inside and outside windows. Every one
of the sixteen primary reads must include an audio interrupt. Extra DOS checks
cover missing files, short reads, EOF, a 32-byte save and byte-exact native/host
readback, plus oversized requests rejected without entering a window. The
primary read checksum is FNV-1a `$59BC1DC5`. No original instruction is patched.

The first expanded test exposed a late display update (line 72) when the
128-key flush ran with interrupts disabled. Keeping that loop under the OS
keyboard vector with interrupts enabled removed the measured failure; the
maintained observer now rejects any late update. Window costs include this
flush and scheduler work; the beam epoch uses 256 units per raster line, with
313 PAL lines per field. These are functional-boundary measurements, not an
optimisation profile or a claim about real-time host speed.

`FileAccess::dos` opens/seeks/reads/closes each bounded request inside a window.
`FileAccess::whdload` uses a bound resload table, GetFileSize plus IOERR to
separate an empty file from a missing one, LoadFileOffset, and SaveFile.
Neither backend accepts a transfer above 64 KiB; whole-file saves above that
limit fail explicitly until persistent durable writes (M3.6). An unbound
resload backend returns unavailable. M7.2 must bind the real slave table and
run actual WHDLoad integration tests; this checkpoint makes no claim of an
actual WHDLoad launch. Host sanitizer fixtures exercise adapter outcomes;
a native fixture checks D0/D1/A0/A1 marshalling and preservation of all eleven
C callee-saved registers while the fake entry deliberately clobbers them.

Final core regression: zero late publications, maximum line 4; the primary
reads span 400 fields and 480 ticks. There are 230 Paula interrupts overall,
37 inside windows, and positive audio observations in all 19 successful read
windows (16 primary plus short/EOF/readback). All 21 OS windows together cost
16,059 beam-epoch units entering and 591,506 leaving: about 2.99 and 110.03
raster-line equivalents per window, respectively. Exit includes the interruptible
keyboard flush; it is not 110 lines with interrupts masked. Host checks and
clean production boot pass. The next real game stop remains GetFCBInfo.
Original startup also passes at A5 `$00787228`, STRS `$004442B0`: zero
mismatches across 75,616 bytes, with the paired heap check reporting zero
unaccounted bytes (Mac 2,821,316; native 3,096,720 free).


### Rendered-capture limitation (M1.7b2, owner-deferred)

After the host restart, the committed tree and build were intact. The recovery
observer completed with explicit PASS and byte-identical before/during/after
bitplanes; this still does not establish video appearance. A local app bundle
under ignored `tmp/` made the existing FS-UAE binary discoverable to computer
use, but access was not approved, and the owner explicitly declined it.

The requested reference review found:
- Slicks `amiga/diag_capture.gdb` dumps logical pixels; its
  `src/ui/screen_capture.h` encodes those pixels and a palette as a BMP.
- Revs `docs/headless-fsuae.md` warns that GDB greys/freezes the display.
  Its launcher and Vette's use F12+S with `FSEMU_SCREENSHOTS_DIR`.
- Rescue `docs/boost-cinematic-plan.md` describes live, non-debugger runs
  captured with host Screen Recording permission. Its SDL PNG writer captures
  the separate host renderer, not the Amiga emulator output.

None supplies unattended rendered FS-UAE captures within the granted access.
Do not label a logical export or a paused-debugger image as this acceptance.
M1.7b2 remains pending by the owner's instruction, while M2.1 is the next active
implementation item. No new screen permission or synthetic key posting is used.


## File Manager contract (M2.1a)

The expanded byte-checked reference logger records complete parameter blocks
on both sides of direct File Manager calls. The maintained
`check_file_reference.py` validates the pairing and required positive/negative
controls. See [file-manager.md](file-manager.md) for the measured FCB fields,
reference counts and outstanding implementation requirements. The original
Core+$4144 instruction selects **GetFCBInfo**, not GetWDInfo; the runtime label
is corrected. The native request's reference 0 exposes the inherited internal
Resource Manager index and must be replaced with an open-fork identity in M2.1b.
No File Manager service is claimed implemented by this diagnostic change.


## Catalog and application-fork identity (M2.1b1)

Production `GDBSCRIPT=file_catalog.gdb EXTRA_ARGS=--warp_mode=1 ./diag_run.sh 60`
checks the original GetFCBInfo/OpenWD calls and stops positively at SetVol,
Core+$4066. It requires the 39-entry catalog, 32 data files totaling 5,315,994
bytes, correct application fork/name and the WD reference consumed by SetVol.
See [file-manager.md](file-manager.md) for the Mac comparison and limits.
`make host-tests` includes sanitizer tests of paths, refs and exhaustion.
`original_startup.gdb`, `identity.gdb` and `runtime_status.gdb` retain their
checks at the new stop; two user services complete, with zero OS windows.
A5 and heap comparisons remain exact. Rendered-picture acceptance is still
owner-deferred; this checkpoint does not imply file-read or video acceptance.

Clean 68020 `make regression` passes both `window-core` (including exact
bitplane snapshots) and production `boot`. Host tests and link audits pass.


## Startup directory sequence (M2.1b2a)

`file_catalog.gdb` now runs through the original three successful OpenWD calls,
two SetVol calls, Preferences FindFolder and missing-movies fnfErr. It checks
original bytes, real arguments/results and Pascal stack cleanup, then requires
the named Get1NamedResource stop at Engine+$3CDC. `identity.gdb` expects seven
Gestalt calls because the newly reached FindFolder glue queries `fold` again.

The reference logger records FindFolder outputs from byte-checked glue;
`check_file_reference.py LOG --startup-directories` checks the ordered directory
sequence as well as the existing file contract. The bounded reference completed
normally with 98 paired file calls. Production startup, host tests, exact A5/heap
comparisons and clean 68020 window-core/boot pass. Seven user services complete,
zero metadata OS windows. Rendered screenshot acceptance remains pending.

M2.1b2b implements the remaining file core before M2.2. The original-game PAK
read acceptance is explicitly retained at M2.1c after Resource Manager support;
a native test fixture cannot satisfy that integrated acceptance.


## Buffered data-fork regression (M2.1b2b)

`amiga/regression.sh file-read` generates an ignored 200,003-byte fixture,
clean-builds `FILEPROBE=1`, and runs `file_read.gdb` with the normal bounded
runner. Native assembly wrappers issue real Open/HOpen, Read, Seek, GetFPos,
GetEOF and Close Line-A instructions. `FileProbe.cpp` verifies bytes, errors,
marks, ioActCount, condition codes and exact window counts. The observer also
continues through OS restoration and checks that the intentionally open final
stream is closed, with no remaining handles. Missing PASS or a timeout fails.

`make regression` runs file-write, file-read, window-core and a clean
production boot in that order. Host sanitizer tests cover the pure cache and fork-position model.
The synthetic names exist in the catalog only for the diagnostic build. No
original data is copied into the executable or committed. Production directory,
identity and original-startup observers retain the Get1NamedResource boundary;
M2.1c still requires original PAK reads/checksums. Actual WHDLoad persistent
streams and remaining variants are separate pending work. Writable data forks
are covered by the file-write regression below.

### File Manager query reference

`tools/mac_file_queries.lua` uses the documented headless MAME configuration
with debugger logging to measure indexed/exact PBGetFCBInfo returns. It verifies
original trap bytes and exits positively after six diagnostic calls; it never
counts as original-game PAK-read evidence. Check its log with
`tools/check_file_queries.py LOG --status RUNNER_STATUS`. Capture failures,
missing stages, incorrect errors and timeouts fail acceptance.

Set `AITD_FILE_QUERIES=directories` for the 21-call directory-state reference
fixture. Its HSetVol/HGetVol and WD measurements are checked with
`tools/check_file_queries.py LOG --directories --status RUNNER_STATUS`.
Set `AITD_FILE_QUERIES=wd` for the 27-call WD lifetime/filtering fixture, and
check it with `--wd` instead of `--directories`. The native `file-read` fixture
now covers 39 stages including hierarchical defaults, WD queries and closure.

### Buffered-write and mutation regression

`amiga/regression.sh file-write` adds a DOS backend fixture and real Line-A
Open/HOpen, Write, SetEOF, GetEOF/GetFCBInfo, Read, FlushVol and Close calls after
the read/directory fixture. It requires FILEPROBE=1 and FILEWRITEPROBE=1.
The case checks exact bytes, marks/EOF, CCR, the 25-pair permission matrix,
protected-file defaults/errors, shared writes and close order, cached-reader
coherence and volume-name/reference forms. It requires 387 runtime windows,
24 DOS writes (65,536 maximum), 18 flushes including shutdown and an empty
stream ledger after cleanup. Host readback verifies 17 backend bytes, six
shared-file bytes, four data bytes plus Finder metadata, and three bytes left dirty
until shutdown. Diagnostic files are recreated in
ignored staging for each run. `make regression` includes this case.

Run `tools/mac_file_mutations.lua` with the documented headless MAME command,
then `python3 tools/check_file_mutations.py LOG --status RUNNER_STATUS`.
The bounded reference fixture checks the original startup observer bytes,
runs File Manager traps from owned stack memory, creates only `AITD Port Write
Probe`, and requires successful delete/flush before its PASS. It never selects
a display mode or uses host window access. A failed Create stops without
opening or overwriting an existing file. On any later failure, inspect the log
and stopped disk for that named scratch before retrying. These API fixtures do
not constitute original-game save/load or PAK acceptance.

`tools/mac_file_sharing.lua` is a second scratch-only headless reference fixture;
check it with `tools/check_file_sharing.py LOG --status RUNNER_STATUS`. Its 222
calls cover permissions, shared data/independent marks, modified flags, both
close orders, file locks and volume lookup. The checker requires the actual
debugger stage register to match each row, the existing reference on a failed
conflicting Open, and successful scratch deletion/flush. Stage constants use
`0x` prefixes so values such as D0 cannot be parsed as register names. The
fixture's `AITD Port Sharing Probe` is its only created/deleted file.

The native fixture applies DOS protection to `locked-probe.bin` in a system
window. Host chmod alone is unsuitable: FS-UAE cannot open that read-only host
file through this stream backend. All files and FS-UAE `.uaem` metadata remain
ignored staging inputs. A scratch FileInfoBlock on the word-aligned Mac stack
was observed at alignment 2 and yielded shifted fields; runtime open metadata
uses the catalog's AllocDosObject/FreeDosObject pattern instead.


### Named catalog mutations and Finder metadata (M2.1b2c9b)

`tools/mac_file_catalog_mutations.lua` uses the same headless CPU-only protocol.
Check its 36 calls with `python3 tools/check_file_catalog.py LOG --status STATUS`;
the process must exit normally. The sole created/deleted file is `AITD Port
Catalog Probe`. This measures Create/HCreate, Delete/HDelete, named Get/SetFInfo
and hierarchical variants, duplicate/busy/locked/missing errors, fresh file IDs,
Finder bytes, dates and modification-date publication at FlushVol. Original
Core+$4142 is byte-checked before installing the owned stack stub.

Native `file-write` stage 43 adds 15 catalog checkpoints. It validates normal
startup decoding of a seeded companion, deletion of data plus companion,
locked-file metadata, initially absent Preferences-directory creation, and independent host readback of a created file's four
bytes and checksummed Finder record. The modification date stays unchanged
while data is pending and advances when Close flushes it. Metadata writes use
OS windows and staged replacement; malformed/orphan companions and incomplete
transactions fail explicitly. The host checker removes only verified diagnostic
output before subsequent production runs.

The Finder output test exposed a GCC 15.1 m68k byte-loop miscompile:
`MOVE.B (a0)+,(a0,d0.l)` used the incremented register for its destination,
shifting the returned bytes by one. Catalog memory and disk bytes were exact;
the parameter-block dump and disassembly isolated the error. Four explicit
endian-safe copies replace that loop, and the native fixture checks all 16 bytes.


### Independent fork regression (M2.1b2c9a)

`tools/mac_file_forks.lua` is the owned `AITD Port Fork Probe` reference; run it
with the documented headless MAME command and check the actual process status
using `tools/check_file_forks.py LOG --status STATUS`. All 60 ordered results,
fork bytes, FCB flags, open references and final cleanup are required. It checks
Core+$4142 and HOpenRF at Core+$4158 before running any diagnostic traps.

Native `file-write` stage 44 covers separate data/resource streams and companion
lifetime, including loading a seeded companion on the next startup path. Host
readback compares both durable fork files and hashes the whole application
resource after a data-fork write. Verified diagnostic outputs are removed before
production regressions. The application source remains the existing raw fork;
only its optional `.data` companion stores data-fork changes. Ordinary files
use `.rsrc` and `.finfo`; companions are never separate virtual catalog files.


### Installed-file metadata (M2.1b2c9c1)

Re-run `tools/extract_original_data.py` to create the 36 `.finfo` companions.
Extraction requires `lsar` and `xattr` alongside the existing unar/hfsutils tools.
It compares the archive entry name, fork layout, sizes, compression method,
type/creator/flags and extracted Finder record before emitting a companion.
Original Mac timestamp integers come directly from the checked 112-byte StuffIt
header. Displayed lsar dates and host filesystem timestamps are not substituted.
The current development staging helper requires the application companion and
copies the data-folder companions alongside their unchanged payloads.

Run `tools/mac_file_installed.lua` with the headless reference command, then
`tools/check_file_installed.py LOG tmp/runtime-data --status STATUS`. It is
read-only and compares application, Camera00.PAK, ITD_Ress.PAK and Present.PAK.
The current reference volume's MacBinary import shifted creation/modification
dates by -7200 seconds; Finder also cleared the data files' initialized flag and
placed the application icon at x=128. The checker verifies those exact measured
differences instead of treating all fields as identical. The port preserves the
archive metadata and extraction's Finder bytes; it does not reproduce incidental
host-timezone conversions or the reference Finder's icon placement.

Native `file-write` stage 44 checks all returned Finder fields, original dates,
logical fork sizes and open attributes for the same four files before the fork
mutation fixture (now stage 45). The regression uses 268 runtime windows; stream
read/write/flush counters remain those of the fork fixture. The additional
application metadata is also persisted when its diagnostic data write closes.


### Indexed file-info queries (M2.1b2c9c2a)

`tools/mac_file_index.lua` creates only `AITD Port Index Probe` beneath the
reference application directory, populates it in reverse order with 67 supported
printable-ASCII names plus a subdirectory, queries it, and removes everything.
Run headless and validate with `tools/check_file_index.py LOG --status STATUS`.
The 218-call fixture verifies all returned names/IDs and excludes directories.
It also covers null output-name pointers, negative named indices, classic/default
selection, bad volume/directory and a WD plus bad explicit directory. Successful
cleanup and normal process exit are required; an existing scratch directory is
never reused or overwritten.

Native stage 46 checks ordering against known existing save files, the grave
accent's special position, canonical name outputs, null-name identity, errors,
classic/default selection, WD precedence and reindexing after deletion. Host
sanitizer tests cover all 67 characters and reverse insertion order. `file-write`
is included in the current 387-window regression. The dedicated application directory also supports indexed queries; System/root
and the legacy mixed native directory remain explicit unsupported boundaries.


### Original application-folder files (M2.1b2c9c2b1)

The extractor also preserves `ListBod2.PAK` (268,430 data bytes),
`Quick Reference` (4,973 data / 712 resource bytes), and
`Register Triple A Pack` (0 data / 87,427 resource bytes). Ordinary resource
forks use raw `.rsrc` companions; the application retains its existing raw-fork
layout. Both fork records must agree with the shared original StuffIt header,
including resource-first offsets, lengths, methods and Finder fields. Missing
or duplicate records and invalid AppleDouble extents fail explicitly.

All four nonempty forks compare byte-for-byte with read-only MacBinary exports
from the System 7.5.5 reference application folder. The three full file
(data then resource) SHA-256 values are respectively
`5c552161db462f80e82346494a304d133ca502c92ab299a77b82ca988fd1893e`,
`6173b910b6b572a00bfef3ca40b7e738712ef7a1f533c90c4bc549a200696e69`, and
`a90c4bbebe9615a900ddfbd8f5c5d845ec8e304970a558aea0a663a0c8b7c870`.
The metadata tests cover two-fork records and reject incomplete/mismatched
pairs. These outputs are integrated into staging and the native application catalog.


### Application namespace regression (M2.1b2c9c2b)

`mac_file_installed.lua` now makes 13 read-only calls: seven named original-file
queries, the four application-file indices, end-of-directory and a missing name.
The checker compares indexed IDs/metadata to named results. The three added root
files retain their Finder flags on the reference disk, with icon coordinates
(y=52, x=0/128/256); these measured installation changes are checked explicitly.
Native stage 44 checks their original metadata, fork sizes, canonical indexed
names and both -43 results, finishing at step 10. The complete production catalog
contains 42 entries; directory calls need no DOS windows, while streamed
resources now add 13 runtime windows (M2.2b2). Current File-write totals include the later OpenDF, HGetVInfo and async fixtures below.

After the production boot build, run `python3 tools/check_file_namespace.py` with
`amiga/env.sh` sourced. Its three bounded native startup runs require normal exit:
an unknown ordinary file raises the catalog count to 43, an unknown directory
returns `CATALOG / UNSUPPORTED DIRECTORY`, and an orphan `.rsrc` returns
`CATALOG / ORPHAN COMPANION`. Each fixture owns and cleans only its named scratch.
The observer finishes the real catalog builder before takeover; no game file is
modified and no host window access is used.


### Volume-parameter regression (M2.1b2c9c2c1)

Run `tools/mac_file_volparms.lua` using the documented headless MAME command,
then `python3 tools/check_file_volparms.py LOG --status STATUS` with its actual
exit status. The read-only 22-call fixture checks the original Core+$43F4
`7030 A260` bytes and the standard +$4142 observer bytes. Its initial GetVol
supplies an actual working-directory reference for the round-trip case.
No mode selection, original-code patch or host-window access is used.

Native `file-write` stage 47 finishes with `g_fileVolumeProbeStep=35`; the marker
includes `volparms=exact`. These catalog-only queries add no system windows. Record bytes, untouched buffer tails,
ioActCount, D0/ioResult and CCR are checked. File-read, window-core, boot and the
42-entry original-directory observer remain regression gates.


### OpenDF dispatch regression (M2.1b2c9c2c2)

Run `tools/mac_file_opendf.lua` headless and check the actual process status with
`python3 tools/check_file_opendf.py LOG --status STATUS`. It owns only
`.AITD Port DF Probe`; failed Create stops before any open. The 69-call fixture
checks Core+$3F78 (`701A A060`), both synchronous dispatch encodings, a leading-dot
filename, permissions 0–4, writer conflicts, independent shared marks, locks,
classic/HFS directory selection, errors and deletion/flush before completion.

A060 ignores ioDirID and resolves an explicit volume reference at its root.
The fixture proves it uses the default directory with reference zero and ignores
an invalid ioDirID, while A260 validates the directory ID. The immediate catalog
query and captured name bytes establish the scratch file before either open.
Error probes additionally distinguish bad starting IDs/file parents (-43) from
missing intermediate directories (-120), and prove failed opens clear ioRefNum
except the existing reference returned for a writer conflict. A bare leading-dot
HOpen addresses drivers; the ordinary-file HOpen error probe uses a leading colon.

Native stage 48 reaches `g_fileOpenDFProbeStep=17`, including matching errors for
HOpen/HOpenRF, dot-name read/write, both aliases and protected files. Host checks
verify open-specific path resolution without changing directory-query semantics.
The current file-write totals, including the HGetVInfo/async fixtures below, are 387 windows, 33 reads / 866,733 bytes, and
24 writes / 470,069 bytes with 18 flushes including shutdown. All owned scratch
forks/companions must be absent afterward; the restored stream ledger is empty.
File-read, window-core, production boot and the 42-entry original directory
observer remain required. Original game PAK reads remain separate acceptance.


### HGetVInfo regression (M2.1b2c9c2c3)

Run `tools/mac_file_vinfo.lua` with the documented headless MAME command, then
`python3 tools/check_file_vinfo.py LOG --status STATUS` using its actual exit
status. The 16-call read-only fixture checks both original callers' bytes,
volume/index/name/WD selection, untouched error outputs, the complete HFS record,
and opening/querying its System Finder ID. The reference reports drive 8; the
port's sole virtual drive is 1. Its disk geometry is deliberately mapped from
DOS rather than copied from the reference volume (see file-manager.md).

Host tests cover selection, every output field, guard bytes, live catalog counts,
capacity aggregation and buffered-growth reservation. Native file-write stage 49
reaches `g_fileVInfoProbeStep=12`; each successful record is compared to the same
call's six-field `g_volumeBackingProbe` snapshot. Eight successful queries add
eight OS windows; invalid selections add none. The System lookup checks the
returned WD rather than assuming a reference survives the earlier CloseWD test.
Both globals are retained by the probe link audit.

Acceptance including the async fixture below: file-write passes with 387 windows, 33 reads / 866,733 bytes and
24 writes / 470,069 bytes / 18 flushes including shutdown. File-read, window-core,
production boot and the original 42-entry directory observer remain required;
rendered-picture verification is still owner-deferred. Original initialization
still stops at Engine+$3CDC Get1NamedResource. Seven directory services plus
13 resource services/windows now give 20 total services (M2.2b2). This does not establish original PAK-read acceptance.


### Async reference and native fixtures (M2.1b2c9c2c4)

Run `tools/mac_file_async.lua` with the standard headless MAME command twice,
setting `AITD_ASYNC_CLOBBER=0` then `1`. Check each actual runner status using
`python3 tools/check_file_async.py LOG --status STATUS`. Both modes pass 33 calls
and 25 early callbacks. The checker requires all eleven original caller byte
checks, callback-before-return ordering, PB/result identity, register restoration,
D0/CCR behavior, scratch metadata readback, cleanup and explicit completion.
A normal emulator exit without the completion marker fails.

The clobber mode intentionally changes the callback scratch registers. Its D0
must survive the trap, while D1/D2/A0/A1 must not leak to the caller. The normal
mode checks final errors directly. These paired runs distinguish callback ABI
from ordinary file-service behavior. The reference files remain local-only;
only the fixture and checker are tracked. Native stage 50 checks 67 calls and 51 callbacks, including the synchronous
protected-WD exception and root closure. The final callback makes a nested
synchronous query; assembly sentinels validate D1/D2/A0/A1/A5 after it returns.
The debugger checks supervisor state, completion depth and inactive service state
at every callback entry. `g_fileAsyncStep=67`, `g_fileAsyncCallbacks=51`,
`g_fileAsyncNestedOK=1` and zero final completion depth are required positive
controls, retained by the probe-symbol link audit. Probe assembly has its own
section so file-read/production builds do not retain probe-only references.

File-write requires 387 windows and unchanged final read/write totals; its two
restored closes must leave no open streams. The checker also requires absence
of all `.async-probe` data/resource/metadata companions. Host tests, file-read,
window-core, production boot and the directory observer pass. The original run
still stops at Get1NamedResource; completing census variants is not original
PAK-read or successful-startup acceptance.


### Map-only resource parser (M2.2a)

`make host-tests` includes `tools/check_resource_map.py`. The portable
`ResourceMap` accepts a 16-byte header and a separately retained map; it never
receives a payload pointer or performs allocation/I/O. Its entries preserve the
original type/reference order, signed IDs, attribute bytes and Pascal names.
Each exposes a length-word file offset. Only after the caller reads that word
does `payload` validate the body range and return its stream offset. Zero-length
resources and a valid empty map are supported. Invalid/overlapping map regions,
truncated names/references, duplicate type blocks, capacity overflow and invalid
payload lengths fail explicitly; a failed open leaves no visible entries.

To check local original bytes without committing assets:

```sh
python3 tools/check_resource_map.py --original 'amiga/.run/dh1/data/Alone In The Dark'
```

The ASan/UBSan fixture copies the header/map into separate buffers and compares
all 212 entries against the existing independent Python fork reader, including
name bytes, IDs, attributes, sizes, order and payload FNV checksums. The measured
map is 4,998 bytes; the full application resource fork is 1,424,934 bytes. The
synthetic fixture includes malformed maps, duplicate IDs, empty maps and lengths
that exceed the data region or overflow naive arithmetic.

This is a parser foundation, not completed on-demand loading. Vette's
`ResourceForks` and `PlatformAmiga` also preload whole forks; their parsing
conventions are reused, while bounded I/O must come from this port's File Manager.
The runtime uses file-backed resource sources as of M2.2b2.
Its acceptance must cover direct and indirect resource loads through user-mode
system windows, all original CODE-byte validation, sample resource checksums,
startup window counts and all existing native regressions. Writable maps,
Resource Manager search/handle semantics and overlay support remain M2.2 work.


### Callback-backed resource directory (M2.2b1)

`ResourceForks` now owns validated map copies and accepts a source context, source
length and read callback. Opening reads only the 16-byte header, map and four-byte
length prefixes; each prefix/body range is checked by `ResourceMap`. It retains
metadata and file offsets, with no payload pointer for file sources. Map copies
are capped at 256 KiB and the existing combined 768-resource limit remains;
unsupported sizes fail rather than allocating from untrusted lengths.

The `read` API fills caller-owned storage in transfers of at most 65,536 bytes.
Invalid destination capacity performs no reads, zero-length resources need no
buffer, callback errors propagate, and a short successful transfer returns -39.
The caller must discard incomplete destination contents on error. A failed open
releases partial maps and publishes no entries. Source contexts remain caller-owned
until close. At M2.2b, ResourceForks retained sorted handle indices while
ResourceMap retained original order; M2.2e now preserves map order throughout.

`tools/check_resource_source.py`, included in `make host-tests`, uses ASan/UBSan
and a guarded source that rejects any payload read during open. Its two-resource
fixture opens with four reads totaling 86 metadata bytes, then reads a 100,003-byte
resource in two bounded transfers with guard bytes intact. It covers read errors,
short reads, empty resources, two-fork identities, failure cleanup and the resident
compatibility adapter. The full host suite and all native regression gates remain
required because the adapter now uses the same map parser as file sources.

The resident compatibility adapter remains for host fixtures only. Platform
startup and zone-handle fills use file-backed sources as of M2.2b2 below.


### Streamed startup resources (M2.2b2)

`amiga/regression.sh resource-read` clean-builds a production executable, checks
positive preparation/runtime counters, and captures STRS 0 (1,810 bytes) and
mctb 128 (32 bytes) from their live zone handles. `check_resource_reads.py`
compares both dumps byte-for-byte with the original fork and prints their SHA256
checksums. No completion marker, missing dump, timeout or runner error can pass.

Platform startup keeps one DOS handle, a 4,998-byte map and resource metadata;
it no longer allocates/loads the 1,424,934-byte application fork. Preparation
reads 201,058 bytes in 228 operations: the header/map/length words and one CODE
resource at a time for the existing original-byte validation. All 58 low-memory
sites are checked before takeover; only CODE 0 and CODE 1 remain resident then.
Discarded validation buffers do not serve runtime resource requests.

Original startup subsequently performs 13 source reads / 68,336 bytes in 13 OS
windows before the unchanged Engine+$3CDC Get1NamedResource stop. Its directory
observer now requires 20 balanced services (seven file + thirteen resource).
Source requests are capped at 65,536 bytes; the largest observed startup request
is 27,692 bytes. GetResource, GetNamedResource, InitMenus, GetMenu, GetNewCWindow,
GetNewPalette, GetCursor, GetPicture and GetNewDialog use the user-mode bridge.
An indirect load outside that bridge is `RESOURCE READ OUTSIDE USER SERVICE`,
never a supervisor-mode DOS call. Failed reads empty the incomplete handle and
return the I/O error; later calls can retry. Source close errors are reported.

`g_resourceSourceReads/Bytes/Max` cover preparation plus runtime;
`g_resourceRuntimeReads/Bytes` isolate takeover reads. `g_resourceSourceOpen` and
`g_resourceSourceCloseErrors` make cleanup observable. All are retained by the
link audit. File-read/write fixtures retain their own unchanged transfer counters
and additionally require a closed resource source after OS restoration.
Writable resource maps, remaining Resource Manager calls and overlay semantics
are still M2.2 work; streaming acceptance does not prove original PAK reads.


M2.2b2 validation also reruns `original_startup.gdb`: the host A5 model matches
all 75,616 debugger-dumped bytes (zero mismatches). File-write/read, window-core,
boot, resource-read and the original directory observer complete with explicit
PASS records and normal runner exits. The bitplane snapshot hash is unchanged;
actual rendered-video acceptance remains owner-deferred.


### Named/ID resource lookup reference (M2.2c1)

Run `tools/mac_resource_named.lua` with the documented headless MAME command,
then check its actual exit status:

```sh
python3 tools/check_resource_named.py tmp/LOG --status STATUS \
  --original 'amiga/.run/dh1/data/Alone In The Dark'
```

The observer byte-checks original Engine+$3CDC (`A820 245F`) and its STR# argument,
then captures the original Pascal name `General` and successful handle. It executes
20 read-only calls through a scratch stub without changing original instructions.
Before each call it seeds ResErr ($A60) with $8888 and D0 with $12345678, so stale
success cannot pass. It requires Pascal stack cleanup, cached-handle identity,
errors and D0 results. The captured STR# 128 body must equal all 612 original
bytes (SHA256 `76033c1f20d7086387ee1baf6a7fc255f162961f217421a4c77373ea6e260af1`).
The script removes its owned prior dump before launch; no original file is written.

Measured on this System 7.5.5 volume:

- Get1NamedResource accepts General/general/GENERAL as the same cached handle.
  An accented spelling, absent name, differently cased type code and empty name
  return nil with ResErr -192. Empty names do not select unnamed STRS 0.
- GetNamedResource gives the same named results but preserves incoming D0.
  Get1NamedResource returns the zero-extended ResErr word in D0.
- Get1Resource/GetResource reuse the same General handle by ID. Missing IDs
  (zero, positive and negative) and an absent type return nil with **ResErr 0**,
  clearing the deliberately seeded error. This is measured reference behavior;
  do not replace it with the named lookup's -192 assumption. Their D0 is zero.
- Error Messages resolves to a distinct nonnull handle; later General lookups
  still reuse the original handle and clear the previous named-lookup error.

Original Dan1 Get1Resource callers at +$35CE/+$36EA/+$39E4/+$3A66 all contain
`A81F 285F`; these calls were the next implementation step at this reference checkpoint. Multi-fork search order, SetResLoad/purge/reload,
writable-resource naming and non-ASCII case-pair tests remain M2.2 acceptance;
this single-current-fork fixture does not establish those semantics.


### Native named/ID resource lookup (M2.2c2)

Get1NamedResource/Get1Resource now restrict lookup to the current fork; the
existing chain variants share their resource cache. Named misses and empty
names report -192, while ID misses clear ResErr to zero, matching M2.2c1's seeded
reference. Get1NamedResource and ID lookups expose zero-extended ResErr in D0;
GetNamedResource preserves its incoming D0. Null Pascal-name pointers remain a
named unsupported call. Multi-fork search-order and non-ASCII case-pair fixtures
remain part of the remaining Resource Manager work.

At this checkpoint, native file-write stage 51 reproduced all 20 reference calls. It required
`g_resourceLookupStep=21`, General FNV `$54B9DC7D`, two runtime resource reads /
863 bytes, and 378 total system windows. The other file transfer totals remain
unchanged. The assembly wrappers expose trap D0 and return the Pascal handle;
returning normally through all wrappers also verifies their stack cleanup.

The production `resource-read` observer stops at original Engine+$3CDE, verifies
nonzero General handle/data, ResErr=0 and D0=0, and captures all 612 bytes before
DetachResource. Its three debugger samples (General, STRS and mctb) must exactly
match the original resource bodies. Original startup then reaches Font Manager
GetFNum (`A900`) at Dan1+$0012; original bytes are `A900 4A6E`. This remains a
named stop for M2.9, not a guessed font answer. The OpenResFile helper that returned
-1 without opening anything is removed; it now stops explicitly until implemented.

The new startup totals are 23 balanced user services, 16 runtime resource reads /
96,648 bytes and 16 OS windows. The loaded CODE mask is `$188B`, with 53 applied
low-memory sites and all 58 sites validated. Directory, original-startup,
identity and low-memory observers now use this measured boundary. Earlier
Get1NamedResource/13-window records document the prior checkpoint. `resource-read`
retains the same preparation count (228 reads / 201,058 bytes), proving no new
preloading. Acceptance passed: the full host suite; native file-write, file-read,
window-core, boot and resource-read; catalog, startup, identity and low-memory
observers. Every run exited normally. The startup A5 dump has zero mismatches
across all 75,616 bytes. Rendered-picture verification remains owner-deferred.


### Resource metadata and lazy-handle reference (M2.2d1)

`tools/mac_resource_handles.lua` runs 18 synthetic calls on the System 7.5.5
reference after checking original Engine+$3CDC (`A820 245F`). It uses scratch
stack instructions, without editing the game's code or files. The paired
`tools/check_resource_handles.py` requires normal runner exit, every ordered
result, stack cleanup, output canaries, handle identity and exact reloaded bytes.
It also checks original Gloss SetResLoad sites +$03CC/+$03E0 and GetResInfo +$03F4.

Measured contract:
- GetResInfo returns General's ID/type/Pascal name with ResErr/D0 zero. It also
  returns Error Messages metadata while its resource handle is empty, both
  before its first load and after EmptyHandle.
- A nil or detached handle returns ID -1, type zero, an empty Pascal name and
  ResErr/D0 `$FF40` (-192). Bytes beyond the returned name remain untouched.
- SetResLoad(false/true) writes ResLoad 0/1 and preserves seeded ResErr and D0.
  With loading disabled, ID and named lookups share a nonnull empty handle.
  Re-enabling loading makes lookup fill that same handle.
- LoadResource explicitly fills/reloads the handle even when ResLoad is false,
  clears ResErr and preserves D0. EmptyHandle clears the body while preserving
  the resource association and ResErr. The reloaded 251-byte STR# 2001 body
  matches the original, SHA256
  `3646fd58d4898bbae89c6e1283418c305adf3016bcce50d8f7ce36e865d38341`.
- DetachResource preserves the body and clears ResErr/D0. GetResInfo then reports
  no resource association. LoadResource on this already loaded detached handle
  preserves its body, clears ResErr and preserves D0. ReleaseResource(nil)
  returns -192 while preserving D0.

The final reference run exited zero and its checker passed. This is reference
acceptance only: native implementation and matching probes are M2.2d2. Automatic
heap-pressure purge, unloaded detached handles, valid ReleaseResource disposal,
multi-fork lookup and writable forks are not established by this fixture.


### Native metadata and lazy handles (M2.2d2)

GetResInfo returns metadata independently of resource residency. Missing or
removed associations return the measured -192 and cleared outputs; bytes beyond
returned Pascal names remain untouched. A volatile byte-copy loop avoids the
known m68k overlapping-address copy defect. Null output pointers stop by name.
SetResLoad updates the private ResLoad byte without changing ResErr/D0. Disabled
lookups return an empty associated master pointer without reading the source.
LoadResource runs through the user-mode service bridge and explicitly fills the
same handle regardless of ResLoad. The measured detached loaded-handle case is
successful without reading; unsupported empty/unassociated cases stop by name.
DetachResource now also clears D0. ReleaseResource(nil) returns the measured
-192 and preserves D0; remaining valid release/flag semantics are M2.2d3.

`ResourceHandleProbe.cpp` reproduces the 18 reference calls before the existing
20 lookup calls. The handle fixture is file-write stage 51 and lookup is now
stage 52. The fixture checks errors, D0, metadata canaries, resident/empty state,
master-pointer identity and disk counters after every operation. Error Messages
has FNV `$20AC017E` after both explicit reload and re-enabled lookup, and after
detach. No metadata or disabled lookup reads resource bodies. The combined probe
requires step 19/21, five resource reads / 1,616 bytes and 381 system windows.
File Manager transfer and cleanup totals remain unchanged. M2.2c2's 378-window
record above describes its earlier standalone lookup checkpoint.

Acceptance: full host suite; native file-write, file-read, window-core, boot and
resource-read; catalog, original-startup, identity and low-memory observers all
passed with normal exits. A5 globals match all 75,616 bytes. Original startup
remains at GetFNum Dan1+$0012 with 16 read windows / 96,648 resource bytes,
23 balanced services and 53 applied/58 validated low-memory sites. No owner
decision changed; rendered-picture verification remains deferred.


### Resource purge/release lifecycle (M2.2d3)

The CPU-only `mac_resource_lifecycle.lua` fixture checks original Engine+$3CDC,
then exercises 28 calls using original CREL 13 (attributes `$28`, 1,288 bytes).
`check_resource_lifecycle.py` requires ordered results, stack cleanup, ResErr,
MemErr, D0, empty/resident transitions and 24-bit Mac master-pointer flags. Its
reloaded dump exactly matches the original, SHA256
`bc4576dd01b2ce1faaebe866250d2366ccc5e5435d876182880a3c76c4ed5336`.
The reference exits zero. Timeout, incomplete captures and corrupt results,
flags or stack records are rejected by the checker.

Measured behavior and native implementation:
- CREL's resource/purge flags are `$60`. PurgeMem with an impossible `$FFFFFF`
  request empties it while returning memFullErr (-108); LoadResource restores
  its exact body and flags using the same master pointer.
- HLock gives `$E0`, and the same purge request preserves the locked body.
  ReleaseResource disposes the resource even while locked. A later lookup
  creates/loads a resource again; reusing a freed master slot is permitted.
  Ordinary and already-empty release also succeed and preserve D0.
- HGetState, HLock, HPurge, HUnlock and HSetState on an empty handle return
  nilHandleErr (-109) in MemErr and sign-extended D0. The native OS dispatch now
  applies this contract; internal resource association is maintained separately.
- DetachResource on an empty resource succeeds (ResErr/D0 zero), leaving the
  measured MemErr -109. LoadResource and ReleaseResource on that detached empty
  handle return -192 and preserve D0/MemErr. LoadResource(nil) succeeds without
  changing D0/MemErr. DetachResource(nil) returns -192 in ResErr and `$FF40` in D0.

File-write stage 53 repeats the 28 calls with per-call read/window counters and
checks CREL FNV `$8D35D0BE` at every resident state, including after purge and
release/relookup. The fixture ends at step 29 with five reads / 6,440 bytes.
Together with the prior probes, file-write requires ten resource reads / 8,056
bytes, 386 windows and 66 resource calls. File Manager totals remain unchanged.
Native master pointers remain clean 32-bit addresses; HGetState verifies their
flags through the existing side metadata. Disk errors and unsupported pointers
still stop explicitly; writable dirty-resource disposal belongs with writable
fork support. The earlier checkpoint totals above remain historical records.

Acceptance passed: the full host suite and all five native regression cases,
plus catalog, original-startup, identity and low-memory observers. Every runner
exited normally. The startup A5 comparison has zero mismatches / 75,616 bytes;
production resource counters and the GetFNum boundary are unchanged. Rendered
video remains owner-deferred. No owner decision is needed for this checkpoint.


### Original-order resource enumeration (M2.2e)

`mac_resource_enumeration.lua` captures 44 CPU-only calls after the original
Engine+$3CDC byte check. `check_resource_enumeration.py` derives expected counts
and order directly from the independent original-fork reader, requires normal
exit, and checks stack cleanup, D0/ResErr, metadata and handle reuse. Current-file
counts are CREL 10, CODE 14 and STRS 1; missing-type counts are zero with no error.
CountResources matches for the application-specific CREL type and an absent type.
This does not establish multi-fork duplicate handling, which remains M2.2f.

Get1IndResource follows original reference-list order, not sorted resource IDs.
CREL enumerates `13,12,3,4,5,6,7,8,9,10`; CODE indices 1/2/14 give IDs 2/13/0.
Zero, negative, out-of-range and missing-type indices return nil, ResErr -192
and D0 `$FF40`. Successful counts and indexed lookups clear ResErr/D0. With
ResLoad false, each new CREL lookup returns a distinct empty resource handle;
GetResInfo still returns its ID/type. Re-enabling loading fills the same first
handle with original CREL 13: 1,288 bytes, SHA256
`bc4576dd01b2ce1faaebe866250d2366ccc5e5435d876182880a3c76c4ed5336`.

ResourceForks no longer sorts its records. Its bounded linear ID lookup returns
indices into the original-order directory; resource-handle and payload indices
therefore stay consistent. The host source test checks unsorted positive/negative
IDs, two-fork order and find/index agreement without body reads, under ASan/UBSan.
Native Count1Resources and Get1IndResource use the current fork; CountResources
supports the current single-fork configuration and explicitly stops if multiple
forks are present until M2.2f establishes that contract.

File-write stage 54 reproduces the 44 reference calls. Every count, metadata call
and disabled-load lookup leaves disk counters unchanged. The final enabled lookup
adds one 1,288-byte read, preserving the original empty master pointer. Terminal
step is 45 and FNV is `$8D35D0BE`. The combined resource probes now check 110
calls, eleven reads / 9,344 bytes and 387 total windows, with unchanged File
Manager transfer and cleanup totals. Prior checkpoint counts above are historical.

Acceptance: host suite (including source ASan/UBSan), all five native regressions
and four startup observers passed with normal exits. All 75,616 A5 globals match.
Original startup remains GetFNum Dan1+$0012, 16 runtime resource reads / 96,648
bytes and 23 balanced services. No owner decision changed; rendered-picture
verification remains deferred.


### Resource-file and search reference (M2.2f1)

`mac_resource_files.lua` runs 63 CPU-only calls after checking Engine+$3CDC.
It exclusively creates `AITD Resource Probe A/B` through the File Manager, then
initializes their resource maps with CreateResFile/HCreateResFile. An existing
scratch name aborts before mutation. OpenResFile, OpenRFPerm and HOpenResFile,
AddResource, UpdateResFile, CurResFile, UseResFile and CloseResFile exercise two
independent maps. Both scratch files are closed and deleted on success. The final
run exited zero, and `check_resource_files.py` passed. Its checker rejects a
timeout, missing completion/cleanup and changed counts/current state/data/errors.
No original resource or game file is modified. Native integration remains f3.

Measured rules:
- Opening makes a file current. Reopening already-open A returns the same
  reference. UseResFile changes the lookup start without reordering the chain.
- Named/ID chain lookup starts at the current file, then visits older files.
  B finds its own STR# 128, then A-only data when missing locally. Selecting A
  hides newer B from lookup; selecting the application restores its original
  General resource. Get1Resource remains strictly current-file-only.
- CountResources traverses **all open maps regardless of current file**, and
  counts duplicate IDs separately. The scratch RPRB type has four entries,
  including ID 7 in both A and B; count remains four with B, A or the application
  current. B's Count1Resources is two. The two shadowing STR# 128 entries add
  two to the pre-open STR# count. Reference baseline is 76 (including System
  resources); native acceptance must compare the delta to its own overlay,
  rather than fabricating the reference System's unused resources.
- Closing current B selects A, then closing A selects the application. Invalid
  UseResFile and repeated CloseResFile return -193 with D0 `$FF3F`, preserving
  the current selection. CurResFile preserves seeded ResErr/D0.
- OpenResFile preserves D0 and returns -1 / ResErr -43 when absent. OpenRFPerm
  and HOpenResFile success leave D0 zero; CreateResFile/HCreateResFile leave
  D0 4/10 in these measured calls. UseResFile/CloseResFile/AddResource clear D0
  on success; UpdateResFile preserves it.
- Update/close followed by HOpenResFile yields the exact four-byte A resource
  again. The six added resource handles are independent; repeated lookups reuse
  each file's handle. Cleanup is positively observed, including a missing-open
  after deletion and restored application current-file state.

The checker validates original Core instruction pairs at +$46F2 (`A81A 3D5F`),
+$4830 (`A81B 6000`), +$4780 (`A9C4 3D5F`) and +$48BE (`A9B1 558F`). This fixture
uses read/write permission 3; it does not establish all permission/error/write
variants. F2 first provides the mutable on-demand fork model and serialization;
f3 connects it to the existing streams and reproduces these native calls.


### Streaming resource-fork serialization (M2.2f2a)

`ResourceWriter` accepts immutable entries containing type/ID/attributes, borrowed
names and a source/offset/length for each payload. Added or changed resources can
supply their own source; unchanged originals remain disk-backed. It emits a
canonical header, length-prefixed data and resource map. Type order follows first
appearance; each type's reference order follows the recipe. Named-empty and
unnamed entries stay distinct. No resource payload is retained by the writer.

Duplicate type/ID pairs retain independent bodies and recipe order. Preflight
rejects invalid source ranges, missing source
callbacks, impossible names, resource count overflow, 24-bit data offsets and
16-bit map/name offsets before opening the sink. Memory consists of bounded
position/type tables, a map (capped at 256 KiB) and one 64 KiB transfer buffer.
Each source read and sink write is at most 64 KiB; short I/O is an error.
The sink must stage into storage separate from the original and publish only on
successful completion. Read/write/begin/commit failures trigger abort; the sink
contract requires failed publication to preserve the old target. This is a
portable transaction contract, not yet a claim about native durable writes.

`check_resource_writer.py` compiles the fixture with ASan/UBSan and compares its
output with the independent Python fork reader. Tests cover a 100,003-byte body,
non-ASCII/embedded-NUL and empty/absent names, interleaved input types, an empty
fork, duplicate keys, source/count/offset/name overflows, short reads/writes and
injected failure at every write boundary, source read, begin and commit. The
original target remains exact in every failure case. The Python reader now
recognizes the canonical `$FFFF` zero-type count for empty forks.

The original-file round trip passed all 212 entries, every name/attribute and
all 1,418,832 payload bytes (212 bounded source reads). The full host suite and a
clean 68020 build passed, including no-float/probe link audits. Explicit volatile
byte-copy destinations avoid the known GCC copy defect; the target object audit
found no shared-base postincrement byte-copy instruction. No native runtime
behavior changed; the helper is not connected to resource-file traps yet.
F2b must supply mutable independent maps and stable identity before f3 binds
this writer to staging streams and verifies the Mac/native resource-file calls.


### Mutable resource metadata directory (M2.2f2b)

`ResourceDirectory` owns up to 16 independent maps and 768 resource metadata
records. Payload sources stay caller-owned. Opening reads only the header, map
and length words; it publishes the new fork only after validation succeeds.
Each fork has a reference, open order, write permission and dirty state. Newest/
older traversal supplies the measured chain order without owning current-file
selection. Identical type/ID pairs in the same or different forks have separate
identities; ID lookup selects the earliest surviving insertion.

Resource identities are monotonic and never reused, including after close/clear;
removed slots may be reused without reviving stale identities. Within each fork,
entry insertion order remains stable. Add/replace deep-copy names, retain source
ranges and preflight the complete candidate serialization through the writer's
allocation-free `measure` operation. Failed range/capacity/name limits or
read-only mutations leave the prior directory intact. Replacement
preserves identity; removal invalidates it. Reads remain bounded to 64 KiB.
These are portable model results; native trap error translation remains f3.

Serialization uses the existing staging sink and deliberately retains dirty
state and old sources. `rebase` validates a newly published map's canonical
ordering, keys, names, sizes and attributes before switching all source ranges
and clearing dirty. It retains identities and publishes nothing on parse/read or
metadata mismatch. The caller must retain old readable sources until rebase
succeeds, and owns file closure/publication. Native persistence is not yet wired.

`check_resource_directory.py` tests metadata-only opens/rebases, duplicate IDs
within and across forks, source reads, copied names, stable order/identity,
change/remove/add, read-only and range rejection, failed writes/opens/rebases, close/reopen
and slot reuse, all 16 fork slots and the 768-resource capacity. ASan/UBSan and an
independent reader verify the changed 70,001-byte resource and added/removed
entries. An original-fork run opens and rebases all 212 entries using exactly 214
metadata reads each, retains every identity, and streams an independently exact
round trip of all metadata/payloads. No original bodies are read while opening.

Acceptance: both independent round trips and all host tests passed. A clean
68020 build passed no-float/probe audits. The directory and writer target objects
contain no shared-base postincrement byte-copy instruction. This change supplies
portable helpers; f3 must connect them to native streams, resource handles and
the 63-call Mac resource-file fixture before that API scope is accepted.


### Native directory-backed original resources (M2.2f3a)

ResourceForks now delegates map ownership and source reads to ResourceDirectory.
Its existing Item/index interface maps each native resource-handle slot to the
stable directory identity. The preparation path and all current Toolbox readers
therefore exercise the new directory on the 68020, while preserving resource
order, source callbacks and existing cached-handle indices. Resident compatibility
remains only for host fixtures. Dynamic open/create/write traps remain pending.

The production resource-read observer additionally requires an active read-only,
clean directory map and matching nonzero identities/sizes for all 212 cached
metadata entries. Every retained Item payload pointer is still null. Preparation
remains 228 reads / 201,058 bytes; startup remains 16 resource reads / 96,648
bytes and 23 balanced user services before GetFNum Dan1+$0012.

Acceptance: full host suite, file-write's 110 resource calls, file-read,
window-core, boot, resource-read and all four startup observers passed with normal
exits. All 75,616 A5 globals match. Source opening/error/short-read tests now link
and exercise the same directory/writer implementation used by the native loader.
No owner decision changed; rendered-picture verification remains deferred.



### Native staged resource writes (M2.2f3b)

`ResourceStage` supplies the writer's explicit-lifetime DOS sink. It creates a
separate `.aitd-new` file, writes sequential chunks of at most 64 KiB, then
flushes/closes it before publication. An existing target moves to `.aitd-old`;
publication replaces it and removes the backup. Publication or backup-removal
failure rolls back to the previous target. A failed rollback/abort returns the
explicit recovery-required error (-32760), retains evidence and prevents reuse.
Existing staging/backup names are rejected without touching them. Callers must
close target streams before publication; dynamic resource traps and directory
rebase remain M2.2f3c. This is operation-failure rollback, not a power-loss guarantee.

The sink callbacks require the active user-service bridge. File-write stage 55
uses diagnostic-only trap A0FA to exercise that same bridge and OS-window guard.
The nine cases cover new/replacement publication, explicit/incomplete abort,
injected publication and backup-cleanup failure with different replacement
bytes, stale temporary/backup preservation, and payload-source failure. Native
readback verifies the entire 70,003-byte payload (FNV `$A04280DF`) and resource
metadata. Independent host parsing checks both 70,314-byte output forks, all
payload bytes, no transaction leftovers and unchanged stale-file sentinels.
The stage uses 56 windows; the combined probe requires 443, with prior File
Manager transfer/cleanup totals and 110 resource-call checks unchanged.

ResourceWriter now propagates abort failure instead of hiding it behind the
initial write error. Its sanitizer fixture verifies the recovery error and
preserved target/staging evidence. No original game instructions are patched.

Acceptance: full host suite, all five 68020 regressions and catalog, original
startup, identity and low-memory observers pass with normal exits. The target
copy audit is clean. A5 globals have zero mismatches across 75,616 bytes.
Production startup remains at GetFNum Dan1+$0012 with unchanged resource I/O.
No owner decision is needed; rendered-picture acceptance remains deferred.


### Dynamic resource index remapping (M2.2f3c1)

The ResourceForks view now supports the directory's 16 fork keys. Its mutation
interface exposes the owned directory and an explicit refresh step. Refresh
rebuilds the dense resource index in map-open order and per-map reference order;
search still belongs to the measured current-to-older traversal. It returns an
old-index-to-new-index mapping based only on stable resource identity. Removed
identities map to -1. New/reopened resources cannot inherit a prior association,
even when directory slots or type/ID pairs are reused. Refreshed bodies remain
source-backed, with null resident compatibility pointers.

The caller must refresh after a directory mutation and apply the mapping to
cached handles before indexed access. Native trap integration and disposal of
removed handles remain M2.2f3c2; existing runtime calls have not been enabled or
made to claim success. The sanitizer source fixture covers add, replace, remove,
close, reopen, duplicate keys across files, nonnumeric open order, all 16 maps,
clear/reopen, identity invalidation and exact changed payload reads.

Acceptance: full host suite and the expanded ASan/UBSan source fixture pass.
All five native 68020 regressions and four startup observers exit normally with
unchanged counts and GetFNum boundary. The generated resource-view copy audit
is clean; all 75,616 captured A5 bytes match. No owner decision changed.


### Dynamic resource-file services (M2.2f3c2)

Resource-file open/create/update/close and AddResource now use the File Manager
catalog and persistent streams. ResourceFiles.inc owns that integration within
MacLoader. Maps stay metadata-only, added bodies read from their associated
handles, and resource view refresh remaps all handles by stable identity.
GetResource/GetNamedResource traverse current then older maps without wrapping
into newer maps. CountResources counts every open map, including duplicate IDs,
regardless of current selection. UseResFile returns the measured D0/error state.

Update serializes through ResourceStage while old sources remain readable,
closes the target stream only at publication, then reopens it. Successful writes
reset the sparse data view, validate/rebase directory offsets without changing
identity, and update catalog size and Finder metadata. Closing updates first,
then disposes the closed map's handles and selects the next older map when
necessary. Reopening an already open file returns its existing reference.

The native ResourceFileProbe extends the 63-call reference sequence with the
measured dirty-noncurrent-close and invalid-update contracts, using only
named scratch files under Alone Saved Games. It checks errors, D0, Pascal stack
cleanup, current refs, six independent handles, search identity and exact bytes,
including reopen. Its STR# chain count uses the measured +2 delta to the native
baseline; no unused Apple System resources are fabricated. The debugger invokes
an independent host reader before deletion to verify all six persisted payloads,
General names, attributes, order, empty data forks and absent staging leftovers.
Final host checks require both files and companions deleted.

This measured scope covers default/explicit read-write opens and creating maps
in already-created files. Other permissions/errors, creating absent files and
dirty-handle disposal still need paired coverage. ChangedResource, WriteResource
and RmveResource are now covered by M2.2f4b3b2 below. Unsupported forms stop by
trap name. Unmeasured dirty-handle operations and dirty exit still stop explicitly. Application-file
closure and mixed raw-stream/resource updates remain unmeasured loud stops.

The 64-call fixture adds 78 windows and 24 disk reads / 590 bytes. Combined
file-write acceptance is 174 paired calls, nine staging cases, 521 windows and
57 File Manager reads / 867,323 bytes (maximum 65,536). File Manager write,
flush and restored-close totals remain 24 / 18 / 2; ResourceStage writes are
separately covered by staging/independent disk checks. Production startup retains
212 resources, 16 runtime resource reads / 96,648 bytes and 23 balanced services
before GetFNum Dan1+$0012. Other writable variants are ordered as M2.2f4.

Acceptance: the original-byte/reference checker, full host suite, all five
68020 regression cases and four startup observers pass with normal exits.
The final file-write rerun includes the explicit pending-variant guards and
independent six-resource disk check. A5 globals match all 75,616 bytes. The
resource integration copy audit and clean production no-float/probe audits
pass. No owner decision changed; actual rendered-video verification remains
owner-deferred.


### Writable resource mutation reference (M2.2f4a1)

The CPU-only `mac_resource_writes.lua` fixture exclusively creates one scratch
file and performs 50 calls at the byte-checked Engine+$3CDC gate. Its checker
also validates Gloss+$08AC, +$0906, +$090A, +$09CE and +$09D4 original mutation
instruction pairs. The final MAME run exits normally, deletes the scratch file,
and restores the application current resource file. No original assets change.

Measured contract:
- AddResource accepts two resources with identical type/ID in the same file.
  Both survive UpdateResFile, close and reopen. Get1IndResource returns them in
  insertion order; Get1Resource selects the first. Removing that first handle
  leaves the other resource under the same ID. This contradicts the portable
  earlier map/writer duplicate-rejection assumption; M2.2f4b1 corrects the model.
- AddResource and ChangedResource set attribute bit `$02`; WriteResource clears
  it. GetResAttrs preserves D0 and MemErr. WriteResource without ChangedResource
  succeeds but does not persist a changed body: resident `CCCC` reopens as the
  previously written `BBBB`.
- RmveResource clears the resource handle flag but preserves its four-byte body
  and master pointer. Readding that handle as ID 129 succeeds and persists `BBBB`;
  the duplicate at ID 128 still contains `DDDD` after reopen.
- Nil AddResource returns -194 (`$FF3E`) and clears MemErr. Nil/removed
  ChangedResource and WriteResource return -192 (`$FF40`) while preserving seeded
  MemErr. Nil/repeated RmveResource returns -196 (`$FF3C`). Those calls put the
  zero-extended ResErr in D0. GetResAttrs on the removed handle returns zero with
  -192 while preserving D0/MemErr. Invalid UpdateResFile returns -193 while
  preserving D0/MemErr.
- Successful mutations clear ResErr, MemErr and D0; UpdateResFile preserves D0.
  Cached lookup of the already loaded first duplicate preserves seeded MemErr,
  while lookup that loads its body clears MemErr. The checker distinguishes
  these states and checks stack cleanup, independent handles and resource flags.

The checker passes the actual capture and rejects timeout, missing completion,
and corrupted attribute, duplicate-count, body, handle-flag, error and register
records. This is Mac reference evidence; native mutation/dirty-attribute support
is still pending. Remaining permission and dirty-lifecycle reference cases are
M2.2f4a2, before native integration resumes.

The full host suite passes. No native runtime code changed in this reference
checkpoint; existing native regression results remain the ab2a3ff baseline.
No owner decision is needed.


### Resource permissions and creation reference (M2.2f4a2a)

`mac_resource_permissions.lua` exclusively creates one scratch name, proves
ownership before deleting/recreating it, and captures 59 CPU-only calls. The
final headless MAME run exits zero and deletes/unlocks the scratch file. The
checker validates the Engine gate plus Core+$46F2/$4780/$4830/$48BE original
call pairs, seeded registers/errors, stack, handles and exact reopened bytes.

Measured contract:
- CreateResFile creates an absent file/map. Repeating it on an existing valid
  map returns -48, leaves D0=4 and preserves MemErr; its resource stays intact.
  The earlier resource-file fixture separately covers an existing data file
  with no map. An empty resource fork and a 16-byte all-zero header both fail
  OpenRFPerm with -39 and reference -1. The raw write's actual count is 16;
  this does not establish a universal error for every malformed layout.
- OpenRFPerm permissions 0–4 all open an unlocked file and read the exact
  four-byte `ABCD` resource. On a locked file, permissions 0/1 still open/read;
  2/3/4 return -54 and reference -1, with zero-extended D0 and cleared MemErr.
- On a read-only open, ChangedResource returns -61 without setting the changed
  attribute. WriteResource then succeeds without writing the modified resident
  `EFGH` bytes. AddResource returns -61 and leaves the resource count at one.
- RmveResource on that read-only map succeeds in memory, clears the resource
  flag and preserves the handle/body. UpdateResFile then returns -61 while
  preserving D0/MemErr. CloseResFile also returns -61 but **does close the file**:
  CurResFile is the application afterward. Reopening retrieves original `ABCD`;
  the failed added ID is absent. The detached body still exists independently.
  Native implementation must separate in-memory map mutation from disk write
  permission and must not retain a read-only file just because its update fails.

The strict checker rejects ten timeout/incomplete/corrupted evidence cases,
including bad lock errors, malformed-header write count, read-only count/body/
attributes, current-file restoration, close error and stack cleanup. Native
permission and mutation behavior is still queued in M2.2f4b. Dirty lifecycle
and exit reference coverage remains M2.2f4a2b. No original assets change and no
owner decision is needed.

The full host suite passes. This checkpoint changes reference tooling only;
native runtime regression evidence remains the ab2a3ff baseline.


### Dirty resource lifecycle and exit reference (M2.2f4a2b)

The scratch-only `mac_resource_dirty.lua` capture completes 45 calls and deletes
both exclusively created files. Two bounded CPU-only MAME runs exit zero with
identical results. `check_resource_dirty.py` checks stage order, seeded D0,
ResErr/MemErr, Pascal stack cleanup, live handle identity, flags and exact bytes.
It deliberately does not interpret stale master pointers after a file closes.

- ReleaseResource leaves a dirty handle resident and associated, with attribute
  bit 2 set; it preserves seeded D0/MemErr. Lookup returns that same body/handle.
- DetachResource on the dirty handle returns -198 (`$FF3A`), preserves MemErr,
  and leaves the body/association intact. After WriteResource it detaches
  successfully, clears the resource flag and preserves the body. A later lookup
  creates an independent resource handle containing the written `CCCC` bytes.
- EmptyHandle discards dirty `DDDD`; LoadResource retrieves the previously written
  `CCCC` under the same handle. The captured full GetResAttrs word is `$E002`
  while empty and `$0600` after reload in both runs. These upper bits are recorded,
  not interpreted as portable resource attribute bits; the trace/poison check
  below establishes their uninitialized origin. UpdateResFile then preserves MemErr.
- Closing a current dirty map persists `EEEE`. Closing either a clean or dirty
  noncurrent map preserves the application current file. Reopening the dirty
  noncurrent map retrieves its exact `FFFF` resource, then both files are deleted.

`mac_resource_exit.lua` adds 13 calls around a real Mac application exit. It
checks the Engine+$3CDC gate and all original CODE 1+$0048 main-return and
+$04AA trap-unpatch bytes, exclusively creates a resource containing `EXIT`,
and leaves it dirty/open. It enters that original return path to restore the
runtime's trap patches and call the OS ExitToShell, avoiding game preference
cleanup. Finder is positively observed, then a fresh application launch opens
and reads the exact resource before closing/deleting the scratch file. This
proves OS-exit persistence, not game quit-path or reset/power-loss durability.
The run exits zero; `check_resource_exit.py` requires both launch byte guards,
ordered exit/Finder/reopen evidence, exact body, registers, stack and cleanup.

Both checkers reject a combined 16 timeout, incomplete and corrupted captures.
The full host suite passes. Native runtime code is unchanged, so its five
regressions/four startup observers remain at the ab2a3ff baseline. Native variants
continue in M2.2f4b; application-file closure and mixed raw/resource updates stay
named stops until measured. No owner decision changed.


### Same-file duplicate model correction (M2.2f4b1)

ResourceMap and ResourceWriter now accept repeated type/ID keys within one type
reference list, as measured by the 50-call Mac mutation fixture. Each duplicate
retains its own name, attributes, payload range and insertion position. Existing
range, capacity, overlapping-reference and duplicate-type-block checks remain.
ResourceDirectory selects the lowest surviving insertion identity for ID lookup,
so removing an older entry and reusing its physical slot cannot move a new
entry ahead of an existing duplicate. Rebase retains each entry's identity.

ASan/UBSan fixtures cover parser order, independent duplicate payloads/names,
writer round trips through an independent Python reader, directory remove/add/
replace/rebase/reopen, and native ResourceForks handle-index remapping. Metadata
operations and lookup read no resource bodies. The directory fixture reopens
and rebases the two duplicates using exactly four metadata reads each. The
original-fork checks retain all 212 entries and 1,418,832 payload bytes exactly.

The full host suite, all five native 68020 regressions and all four startup
observers pass with normal exits. File-write retains 173 paired calls, nine
staging cases and 521 windows; resource-read retains 16 runtime reads / 96,648
bytes. All 75,616 A5 bytes match, and the three changed resource-model objects
pass the generated copy audit. Production startup still stops at GetFNum;
remaining resource mutation/permission/lifecycle traps are M2.2f4b. No owner
decision changed; rendered-video verification remains owner-deferred.


### GetResAttrs upper-byte diagnosis (M2.2f4b prerequisite)

Instruction traces of the empty/reloaded dirty-handle calls show the System
7.5.5 wrapper at `$41768` reserving an uninitialized result word. The ROM at
`$408134A0` writes only the low attribute byte (`MOVE.B 4(A2),13(A6)`). The
wrapper copies the entire word back to its caller, exposing old stack contents
as the high byte. The observed `$E002`/`$0600` are not portable attributes.

`AITD_RESOURCE_ATTR_POISON=1` enables two guarded diagnostic breakpoints in
`mac_resource_dirty.lua`. They verify the wrapper/ROM instruction bytes before
setting the internal result's high byte to `$5A` and `$A5`. The full 45-call
fixture returns `$5A02` and `$A500`, with unchanged low attributes, errors,
registers, bodies, close/readback and scratch cleanup. The bounded MAME run exits
zero and `check_resource_dirty.py --poison` passes. The unpoisoned traced run
also exits zero and passes its checker. Native GetResAttrs should zero-extend
the defined attribute byte; it must not reproduce stack garbage. No game
instructions or original files change, and no owner decision is needed.


### Noncurrent resource close and invalid update (M2.2f4b2)

The resource-file dispatcher now allows closing a noncurrent map and returns
-193 for an invalid UpdateResFile reference, preserving D0. Existing closure
updates the requested map, closes its stream and disposes its associated handles;
it changes current selection only when that map was current. Application closure
and unmeasured raw/resource-stream mixing remain explicit stops.

The native fixture now leaves B's three added resources dirty until close while
the application is current. It checks current-file selection after closing B,
a repeated invalid close, and closing clean noncurrent A; resource lookup still
selects the original application's General resource. The independent disk reader
checks all six exact A/B bodies, names/IDs/order and empty data forks before
scratch deletion. A new 64th call checks invalid update's error, D0 and Pascal
stack cleanup. The fixture composes the original 63-call file-reference contract
with the dirty-close and mutation-error reference captures; those checkers also
revalidate original call bytes. Total file-write coverage is 174 calls, nine
staging cases and unchanged 521 windows / 57 reads / 867,323 bytes.

Before implementing WriteResource via the whole-map publisher, M2.2f4b3a must
establish the isolation of one resource write from another dirty resource.
That dependency is explicit rather than assuming UpdateResFile is equivalent.

Acceptance: both Mac reference checkers pass, the full host suite and all five
68020 regressions exit normally, and all four startup observers pass. All
75,616 A5 bytes match. Production resource reads remain 16 / 96,648 bytes before
GetFNum Dan1+$0012; no original instructions changed. No owner decision is
needed. Rendered-video acceptance is still owner-deferred.


### WriteResource isolation reference (M2.2f4b3a)

`mac_resource_isolation.lua` exclusively creates one scratch file with two
resources, then completes 40 calls with original Engine gate guards. Both
resources are dirtied; WriteResource(A) clears only A's changed flag. B remains
dirty. Empty/reload retrieves A's written `CCCC`, but retrieves B's old `BBBB`
instead of its discarded dirty `DDDD`. Update/close/reopen retains those exact
bodies. The second phase changes both resources again, writes B, proves A still
dirty, and reloads B as written `FFFF`. UpdateResFile then writes A's remaining
`EEEE`; both exact bodies survive close/reopen. The scratch file is deleted and
the application current file restored. The bounded CPU-only MAME run exits zero.

The strict checker verifies ordered calls, errors, D0/MemErr, stack, independent
live handle identities, defined attribute bytes, exact bodies and cleanup. It
also checks original Gloss ChangedResource/WriteResource instruction pairs.
Undefined GetResAttrs upper-byte scratch is intentionally excluded, following
the guarded trace/poison diagnosis. Ten incomplete/corrupted captures are rejected.

This establishes that a whole-map update cannot stand in for WriteResource:
unselected dirty bodies must keep their saved source until explicitly written,
while UpdateResFile writes all remaining changes. Selective source-backed
publication and native integration are M2.2f4b3b. Native runtime is unchanged;
its regression baseline remains abbbf61. No owner decision is needed.

The full host suite passes for this reference-tooling checkpoint.


### Selective resource publication model (M2.2f4b3b1)

ResourceDirectory serialization and rebase accept an optional per-identity
payload selector. It can substitute only a body's source, offset and size;
keys, names, attributes and ordering stay unchanged. Selection occurs on a
publication recipe, leaving live metadata and saved sources intact until
successful rebase. Unselected resources stream from their existing saved source.
Rebase validates metadata against that same selection and switches all offsets
while preserving identities. The caller must keep selection and sources stable
through both calls. Calls without a selector retain their prior behavior.

The ASan/UBSan fixture writes A as 70,001 `C` bytes while B remains saved `BBBB`,
then writes B as three `D` bytes while A stays unchanged. An independent Python
reader checks both complete forks, including names, IDs, attributes and order.
Changing the old resident A buffer afterward does not change its saved/reloaded
body. Opens and rebases use four metadata-only reads; body transfers are bounded
to 64 KiB. No pending resource body is copied into retained staging memory.

The fixture rejects selector errors and invalid ranges before staging starts,
and injects failures at every write boundary plus source reads and publication.
Failed serialization keeps the prior target and live metadata intact; failed
rebase and mismatched selection preserve the original metadata/source bindings.
The full host suite and all 212 original resources pass, including exact
original-fork serialization and stable-identity metadata-only rebase. Native
mutation dispatch is the next component, M2.2f4b3b2.

Acceptance: all five native 68020 regressions and four startup observers pass
with normal exits. File-write retains 174 calls / nine staging cases / 521
windows; startup resource reads remain 16 / 96,648 bytes before GetFNum. All
75,616 A5 bytes match, and the changed directory object passes the generated
copy audit. No owner decision changed. This commits the independent publication
model; the native traps remain explicit stops until their integration fixture.


### Native resource mutations and isolation (M2.2f4b3b2)

The loader tracks per-entry dirty/never-published state alongside handles, remapped
by stable identity. ChangedResource marks a resident body without replacing the
saved source. WriteResource selects only that body's handle source for staged
publication; UpdateResFile selects every remaining dirty body. Successful rebase
switches saved offsets and clears only published state. Empty/reload of an
already saved dirty resource reads its old source and discards the pending change.
Map-change bookkeeping remains separate from body dirtiness, preserving the
measured MemErr difference between an initial-map update and a clean update.

AddResource sets the changed attribute. GetResAttrs zero-extends the defined
attribute byte and preserves D0/MemErr; removed handles return zero/-192.
RmveResource invalidates the resource identity and clears its handle association
without freeing the caller's body, allowing re-add under another ID. Nil/add and
nil/removed change/write/remove errors use the measured results. Clean writes
without ChangedResource do not publish resident edits. Dirty release preserves
the handle; dirty detach returns -198 without changing it. Unmeasured operations
retain named stops, including empty/reload of never-published handles.

The native fixture runs the 50-call mutation and 40-call isolation contracts,
checking exact error/register/stack results, defined attributes, body bytes,
independent duplicate handles and first-duplicate lookup. Two injected publication
failures (publish rename and backup cleanup) retain the dirty handle and exact
old empty fork, verified independently before a successful retry. Independent
readers also check the final mutation fork (duplicate ID 128 `DDDD`, re-added ID
129 `BBBB`) and isolation fork (`EEEE`/`FFFF`), names, attributes, reference order,
empty data forks and absent transaction leftovers. Final acceptance requires
both scratch files and companions deleted.

Three additional native calls check dirty ReleaseResource, rejected dirty
DetachResource and retained changed attributes against the dirty-lifecycle Mac
capture. All preserve the handle/body and measured D0/MemErr. Combined acceptance
is 267 paired resource calls, nine existing staging cases and two mutation
rollback cases. The mutation fixture adds 206 windows; complete file-write totals
are 727 windows and 132 File Manager reads / 868,833 bytes, maximum 65,536.

Validation: original-byte/reference checkers, full host suite, all five native
68020 regressions and all four startup observers pass with normal exits. The
final file-write rerun includes direct dirty release/detach checks and both
independent rollback/final-fork readers. All 75,616 A5 bytes match; production
still stops at GetFNum after 16 resource reads / 96,648 bytes. A clean production
build restores the non-probe executable with no-float/probe audits passing.
No owner decision changed; rendered-video acceptance remains owner-deferred.

The final MacLoader object has no shared-base postincrement byte-copy occurrences.
The queued QuickDraw pattern dump remains necessary before accepting M2.3a.


### Pending resource-map write reference (M2.2f4b3c1)

`mac_resource_map_edits.lua` and `check_resource_map_edits.py` establish 44
ordered calls using an exclusively created scratch file. WriteResource(A)
succeeds while B has never been published: A reloads as `AAAA`, while B remains
resident `BBBB` with its changed flag. After removing B, updating and reopening,
A remains exact and B is absent. The second phase publishes both, removes B,
changes A to `CCCC` and writes A while removal is pending. A reloads exactly;
B stays absent before and after update/close/reopen. Both detached B handles
are explicitly disposed, the scratch file is deleted and the application
current resource file is restored. Original Engine and Gloss call bytes match.

Empty/reload of never-published B is **not** a valid saved-body contract.
The observed LoadResource returns -39, clears its changed flag and leaves a
resident resource handle. Guarded ROM instruction and I/O probes explain why:
the first read takes four bytes at fork offset $014E as length $6974, then
ReallocHandle allocates that amount. The body read at $0152 transfers only four
bytes and returns EOF. An independent scratch-fork dump finds `00006974` there,
beyond the old empty map; these are unrelated residual bytes, not B's body or
length. The on-disk header still describes the old empty map after the selected
write. Do not reproduce this accidental allocation size or failed-read bytes.
The native unpublished-empty/reload loud stop remains queued under M2.2f4b5.
`AITD_RESOURCE_MAP_DIAGNOSTICS=1` enables byte-guarded read/allocation logging
for this call without changing the 44-call sequence.

The checker validates errors, D0/MemErr, stack cleanup, stable live handles,
defined low attribute bytes, valid bodies, removals, reopen and final cleanup.
It deliberately excludes failed-read body/size values. Three bounded headless
captures exit zero and pass; ten corrupt/incomplete/timeout variants are
rejected. The separate raw scratch-fork diagnostic also completes with cleanup
and exit zero. The full host suite passes. This reference-only checkpoint
leaves native runtime and its e81915f regression baseline unchanged; native
integration is M2.2f4b3c2. No owner decision changes.


### Native writes amid pending map edits (M2.2f4b3c2)

ResourceDirectory publication can omit an entry from the saved map while keeping
its live identity, metadata and independent source. Rebase retains those entries,
owns any name previously borrowed from the old map, and keeps the directory dirty.
Validation and required name allocations happen before live metadata changes.
WriteResource uses this only for other never-published resources: their resident
bodies are neither read nor saved. A later UpdateResFile publishes them normally.
A pending removal is included in the selected write; the following clean update
preserves MemErr as measured. Newly written additions retain the separate map-work
flag used by the previously measured update contract.

`AITD_RESOURCE_MAP_VALID=1` selects the 37-call valid reference path; the checker
requires `--valid`. It verifies writing A while B is unpublished, A's exact reload,
B's unchanged resident bytes/dirty flag, explicit update followed by B's exact
reload, both resources after reopening, then removal of B and another write/reload
of A. The reference exits zero, restores current-file state and deletes its scratch
file. Both reference modes pass, and ten corrupted/timeout valid-mode captures
are rejected. The undefined unpublished empty/reload case remains a named stop
under M2.2f4b5; its accidental bytes/allocation are not emulated.

The native fixture matches all 37 calls, including errors, MemErr, D0, stack,
handle states and exact bytes. Four new injected failures cover publish rename
and backup removal while a peer is unpublished and while a removal is pending.
Each preserves live dirty state and the previous fork. Independent readers verify
the empty/both-resource rollback targets, the selected-only fork, later both-resource
publication and final single-resource fork, with no transaction leftovers and
complete scratch cleanup. Combined native coverage is 304 paired resource calls,
six mutation rollback cases and nine staging cases; file-write uses 837 windows
and 160 File Manager reads / 869,391 bytes, at most 65,536 per transfer.

The sanitizer fixture verifies omitted bodies are not read, metadata/source identity
survives rebase, later publication/removal is exact, and failed selection/staging/
rebase keeps live state intact. The full host suite passes. The expanded native
fixture exceeded its old 60-second limit; that run failed and was not accepted.
File-write now has a 120-second bound, with all other regression bounds unchanged.
All five native 68020 regressions and all four startup observers pass with normal
exits. All 75,616 A5 bytes match. Production still reaches GetFNum after the same
16 resource reads / 96,648 bytes. Final production link/no-float/probe audits pass;
MacLoader and ResourceDirectory objects have no shared-base postincrement byte
copies. No owner decision changed; rendered-video acceptance remains deferred.


### Native resource permissions and creation (M2.2f4b4)

Resource-file opens now use the File Manager's measured permissions 0–4,
including locked-file read/default opens and rejected locked writes. Resource
metadata and bodies still use direct bounded reads on read-only streams, without
filling the data-fork read cache. CreateResFile creates an absent catalog/data file
before initializing its resource map; an existing valid resource fork returns
-48 and stays intact. Empty forks and the measured 16-byte zero malformed header
return -39 with a failed reference and closed stream. Other malformed layouts,
creation over malformed content, application closure and mixed raw/resource
writes retain their existing loud stops.

ChangedResource and AddResource reject read-only maps with -61 and the measured
MemErr/D0 results. A clean WriteResource remains successful without persisting
resident edits. RmveResource works in memory, detaches the handle and leaves its
body owned by the caller. UpdateResFile then reports -61; CloseResFile reports
the same error but closes the read-only map/stream and restores current-file
selection. Writable publication failures retain their previous close behavior.
The portable directory rejects serialization of a read-only map even after its
in-memory removal; its host fixture verifies the original source remains intact.

The native 59-step fixture follows the Mac capture with exact errors, registers,
stack, attributes, live bodies and reopen checks. Its two lock/unlock setup steps
use native DOS protection through the existing system-window/diagnostic-service
pattern; they do not implement Mac SetFLock/RstFLock game traps. The other 57 calls
are paired traps, bringing combined coverage to 361 calls. Detached and rejected-add
handles are disposed explicitly after the fixture. Three independent disk checks
prove the original `ABCD` resource, name, ID, attributes, empty data fork and absent
transaction leftovers survive create-existing and read-only errors. The scratch
file and companions must be deleted before acceptance.

The permissions fixture adds 107 windows. Complete file-write totals are 944
windows, 207 reads / 870,393 bytes, 25 writes / 470,085 bytes, 19 flushes and two
restored closes; transfers remain at most 65,536 bytes. All six prior mutation
rollback cases and nine staging cases remain required. The original-byte/reference
checker and full host suite pass. All five native 68020 regressions and four
startup observers exit normally and pass. The final file-write rerun also verifies
the guard that limits close-after-permission-error to read-only files. All 75,616
A5 bytes match; production remains at GetFNum after 16 resource reads / 96,648 bytes.
MacLoader/ResourceDirectory generated-copy audits and the restored clean production
build's no-float/probe audits pass. No owner decision changed.


### Complete native dirty lifecycle fixture (M2.2f4b5a)

The independent lifecycle portion now has all 45 Mac-reference calls in one native
fixture: dirty release preserves association/body; dirty detach returns -198;
write followed by detach keeps the caller's body and allows a distinct fresh
resource handle. Empty/reload discards a saved resource's dirty resident edit and
restores its old saved bytes, clearing its changed flag. Dirty current close
persists `EEEE`; dirty noncurrent close persists `FFFF` while leaving the
application selected. Every call checks errors, MemErr, D0 and stack cleanup;
body/handle-state and identity checks cover the live transitions. GetResAttrs
continues to compare only its defined low byte.

An independent parser verifies both closed forks before deletion: exact LIFE 128
bodies, Scratch names, zero attributes, empty data forks and no staging remnants.
Final acceptance requires both scratch files/companions deleted. The fixture adds
96 windows and 45 paired calls: combined file-write coverage is 406 paired calls,
59 permission steps, six mutation rollback cases and nine staging cases. It uses
1,040 windows and 237 File Manager reads / 871,061 bytes; write/flush totals remain
25 / 470,085 bytes / 19. Existing runtime implementations pass the full contract
without another runtime change. Original-byte/reference and full host checks pass.
All five native 68020 regressions and four startup observers pass with normal
exits. All 75,616 A5 bytes match; production still reaches GetFNum after 16
resource reads / 96,648 bytes. Production link/probe/no-float and generated-copy
audits pass. No owner decision changed.

### M2.2f4b5b — dirty resource exit persistence

ExitToShell now enters the user-service bridge and closes/publishes dynamic maps
before switching back to the native host stack. The application source remains
open until restored-OS cleanup. Publication errors stop at `RESOURCE EXIT IO
ERROR`; application-map mutation remains unsupported.

`amiga/regression.sh resource-exit` runs three fresh 68020 processes. The failure
case injects a rename failure, requires ResErr -36, an active service and open
stream, and the exact resident `EXIT` body. The independently parsed disk fork
must remain empty, with no staging remnants, before owned scratch cleanup is
allowed. The successful case leaves LIFE 128 (`Scratch`, body `EXIT`) dirty and
open, then returns through original CODE 1+$48, its unpatch routine at +$4AA and
ExitToShell. A fresh launch reads back the same resource, closes and deletes it.
All thirteen calls retain the measured Mac error/register/stack/body contracts.

The diagnostic build temporarily redirects the guarded Core main entry to the
fixture and immediately restores all original bytes. FS-UAE's remote stub
silently ignores register and memory writes; byte readback established that the
observer cannot inject the call itself. Production contains no diagnostic hook.
Both the original source bytes and the live CODE 1 exit/unpatch bytes are checked;
the only expected difference is the established low-memory rewrite at +$48.
The original return address is verified on the stack before the fixture runs.

Positive exit evidence includes balanced user services, no remaining streams,
closed original source, restored Line-A/vector ownership, callbacks cleared,
multitasking enabled, matching DMA/interrupt/View state and all four Paula voices
zeroed. The observer then requires native main to return zero and positively
reaches the CRT's final return instruction. This proves original-runtime exit
persistence, not the game's menu quit path, Workbench startup or reset/power-loss
durability. Every breakpoint is a positive address check; a timeout is a failure.
The host checker rejects missing statuses, duplicate/incomplete/wrong-phase logs,
unexpected stops and timeout records, and refuses pre-existing scratch files.

Unpublished empty/reload and dirty resize/dispose/purge remain named stops until
required by original execution. Writable prefs/save and overlay integration are
next (M2.2g); no owner decision changed.

Acceptance: all six native regression cases and the four startup observers pass
with normal completion, as does the full host suite. The final production build
passes link/probe/no-float checks; MacLoader and ResourceDirectory generated-copy
audits are clear. All 75,616 A5 bytes match. File-write remains at 406 paired
calls / 1,040 windows; original startup remains at GetFNum with 16 resource reads
/ 96,648 bytes. Both successful exit phases balance 11 user-service calls and
reach native main result zero and the final CRT return. No timeout is counted.

### M2.2g1 — source-backed port overlay foundation

`tools/build_overlay.py` deterministically generates the committed
`resources/overlay.rsrc`: an empty 286-byte classic resource fork containing no
original game data. `--check` verifies regeneration and independent parsing;
`make host-tests` requires it. Fonts and measured dialog layouts remain at their
planned milestones. The narrow Git exception applies only to this port-owned
fork; original resource forks remain ignored.

`ResourceForks::openWithOverlay` opens the overlay at reserved key 15 before the
application at key 0. Both maps are read-only. Later dynamic maps precede the
application, whose older map is the overlay. Sanitized callback-backed fixtures
verify this ordering, no body reads during opening/traversal/remapping, exact
bounded overlay payload reads, rejection of overlay writes, and complete rollback
if either source fails. The generated empty map takes two reads / 46 bytes and
adds no resources to the application view. Existing resource-source fixtures
continue to pass. This independent foundation does not yet wire the overlay into
native startup; M2.2g2 retains that and writable prefs/save path acceptance.
The full host suite and a clean production `resource-read` regression pass with
normal completion. Production still has 212 resources, 201,058 preparation bytes
and 16 runtime reads / 96,648 bytes, with the same GetFNum stop; the new API is
not yet selected by native startup.

### M2.2g2 — native overlay and writable paths

Startup opens the generated overlay read-only as a separate bounded source,
then its map before the application's map. The loader verifies the exact
application → overlay → end chain and leaves the application selected. The
empty overlay has Mac resource-file reference zero, consumes two metadata reads
/ 46 bytes, adds no resources and performs no runtime reads. Its DOS source is
closed during restored-OS cleanup; missing/invalid input and close errors fail
explicitly. Both ID and named searches use the shared tested order. DLOG, DITL
and ALRT search the overlay first under D5, while single-file lookups remain
local. No layouts or placeholder fonts have been invented for this step.

The native `resource-exit` regression now runs failure, original exit and fresh
readback/delete for both `Saved Games/Resource Exit` and `prefs/Resource Exit`.
Every process additionally selects System reference zero, verifies an empty CODE
count, and restores the original application selection. Disk parsing requires
exact LIFE 128 / Scratch / EXIT bytes and no staging leftovers; failures preserve
the old empty fork and live dirty body. Every phase checks both source closures,
service/window state and native main/CRT return. Location-tagged output prevents
a saves result from being accepted as preferences evidence. Two additional
processes require exact `OVERLAY UPDATE` / `OVERLAY CLOSE` stops for attempts to
update/close System reference zero, without creating scratch or closing either
source. Overlay resource mutations also remain a named stop until measured;
the port map is not exposed as a writable File Manager stream.

The same thirteen-call lifecycle also passes on the Mac in its actual blessed
folder, `7.5.5 2GB (D):System 7.5.5 (min):Preferences:`. The first attempt used the
wrong System folder name and returned dirNFErr; it was rejected. An HFS directory
inspection established the exact path before the successful bounded run.
`AITD_RESOURCE_EXIT_PATH` supplies the reference-only scratch path, and the
checker requires that path on both launches. The existing `Alone Prefs` is never
modified. This verifies the file/resource services, not the game's eventual
preferences format, screen-size choice or save/load UI.

M2.2's measured service and integration scope is complete. Unmeasured resource
variants remain named stops as listed in design §4.5. Original-file read
acceptance is next (M2.1c); the production startup stop remains GetFNum.

Acceptance: the full host suite, all six native regression cases and all four
startup observers pass with normal completion. Both explicit overlay-stop cases
also pass their exact reason checks; the final production build passes
resource-read, no-float/probe audits and the MacLoader/ResourceDirectory generated
copy audit. All 75,616 A5 bytes match. Original application preparation remains
228 reads / 201,058 bytes; the separate empty overlay adds 2 reads / 46 bytes.
Original runtime remains 16 resource reads / 96,648 bytes. File-write remains
406 paired calls / 1,040 windows. No timeout or failed exploratory run is counted;
rendered-window acceptance remains owner-deferred. No owner decision changed.

### M2.1c1b — installed data layout

The original installer places ListBod2.PAK in Alone Data. Extraction, staging and
reference population now reproduce this; see `install-original-data.md` for the
original installation evidence and `file-manager.md` for native acceptance.
Fresh/repeated extraction and staging preserve exact bytes and reject conflicting
legacy root copies. All six native 68020 cases, four startup observers and the
full host suite pass. Current catalog totals are 42 entries, 33 data files and
5,584,424 data bytes. File-write's corrected root enumeration uses 1,039 windows;
all other transfer totals remain unchanged. Startup still stops at GetFNum.


### Installed font lookup and native-driver boundary (M2.1c3 implementation)

The overlay now contains the port-owned Times FOND/NFNT. GetFNum loads and
validates the family and linked bitmap before returning its ID. The first
original Dan1 lookup returns 20 with the Mac stack/D0/error contract; both
resident resource bodies compare exactly with the generated source. Unsupported
font layouts/collation and text rendering retain named stops. The second
original lookup is still pending behind M2.1c3c; M2.1c3 is not complete.

Continuing startup exposed execution of the original MDRV and its `.BD_PAS16`
probe. That exploratory run is rejected under D8. Production now stops explicitly
at `NATIVE SOUND DRIVER` before loading any MDRV body. Original bytes identify
Core+$10E2's Jnth search before +$1102's MDRV fallback, +$1CC6's loader call and
+$1CF4's entry-pointer store. Native driver initialization is the next prerequisite.
No original code is patched by this change.

All six native 68020 regression cases, all four startup observers and the full
host suite pass with normal completion. Resource-read passes both fresh and
existing default-preference inputs: 53/27 OS windows and 43/42 or 35/34 service
entries/completions respectively, with one service active at the deliberate stop.
Original application preparation stays at 228 reads / 201,058 bytes. Overlay
preparation is four reads / 100 bytes. Runtime application reads are 20 / 104,340
bytes; font bodies add two / 1,314. File-write retains its 406 paired calls,
1,039 windows, six mutation rollback cases and nine staging cases.

The catalog observer now verifies one GetVol and all four original SetVol calls,
including the preferences selection and named restoration, against the Mac trace.
The identity observer includes the eighth `a/ux` query returning -5550/A0=0,
already measured in M0.2. The 75,616-byte A5 comparison has zero mismatches.
The clean production build passes no-float/probe audits (73 symbols). No timeout
or failed exploratory observer is counted as a pass; rendered-window verification
remains owner-deferred. No owner decision changed.

### Native-driver reference contract (M2.1c3c1)

The bounded original Mac probe now verifies both startup driver calls, their
arguments, resulting configuration, stack and D2–D7/A0–A6 preservation, then
positively reaches the second Times lookup (20). Its fresh 29,256-byte driver
dump matches the original unpacked body exactly. The checker rejects missing
calls, wrong state/registers, early or duplicate completion and nonzero/timeout
status. Reproduction and byte attribution are in `sound-driver.md`.

The complete host suite and fresh reference run pass with normal completion.
This independent measurement changes no native runtime; the prior native
regression results still describe the production stop before MDRV loading.
Native installation remains M2.1c3c2, preserving the full original acceptance
requirement. No owner decision changed.

### Native driver startup subset (M2.1c3c2a)

The original loader now installs the port-owned Jnth 11 entry without any game
patch. Native selectors 21/24 initialize voice/channel state and quality and
match both Mac return contracts, including thirteen preserved registers and
unchanged caller stack. The instruction cache is flushed after the loader's
MoveHHi. Other selectors/configurations remain named stops; MDRV is never
loaded. The next original stop is Engine+$2DEE `MENU MANAGER / COUNTMITEMS`.
The second Times lookup is still pending behind intervening services: its
attempt was rejected at that menu stop. M2.1c3c2 and M2.1c3 retain full integrated
acceptance; menu-record support is the next named prerequisite.

The complete host suite, six native regression cases, four startup observers,
first-font body comparison and both driver-call checks pass normally. Final
production passes the driver/font observers and both fresh/existing-preference
resource boundaries: 55/29 windows and 45/45 or 37/37 paired services. Overlay
preparation is 5 reads / 124 bytes; its three runtime bodies total 1,318 bytes.
Original application preparation remains 228 / 201,058; runtime is now 21 /
104,397 after loading MENU 128. All 75,616 A5 bytes match. File-write remains at
406 paired calls / 1,039 windows, with all rollback and staging cases passing.
Original preferences were preserved before the file-write fixture and restored
exactly after the final fresh-start check.

Final link/no-float/probe audits pass (76 probes). The generated-copy inspection
finds one shared-base postincrement byte copy in the existing initGraf patterns,
the already-queued M2.3a defect; ResourceDirectory has none. No new driver copy
uses that form. No timeout, failed second-font attempt or obsolete overlay-size
observer is counted as passing. Rendered-window acceptance remains owner-deferred;
no render/audio/full-startup acceptance or owner decision changed.

### Startup menu records (M2.1c3c2b)

CountMItems, GetMenuItemText and SetMenuItemText now operate on the actual packed
menu handles. The game still strips its own command suffixes. The bounded Mac
capture checks 33 calls; paired native execution checks 32, with identical game
labels, flags, item attributes and all twelve mutations. The one explicit
difference is the reference System-only Control Panels item, with no command
suffix/key; the native resource chain has no DRVR entries. The game registers
the same application commands. See `menu-manager.md` for byte guards and exact
comparison scope, including preserved registers and cached-dimension invalidation.

The host suite passes, including 510 sanitizer-checked replacements and malformed
record tests. Clean production boot/resource-read and all seven menu, driver,
font, catalog, startup, identity and low-memory observers pass normally. Fresh
and existing preferences use 58/32 OS windows and 48/48 or 40/40 paired services;
original preferences are restored afterward. Application runtime reads are now
24 / 104,667 bytes after all four MENU resources; preparation and overlay
transfer counts are unchanged. All 75,616 A5 bytes match. Link/no-float/probe
audits pass (76 symbols); generated byte-copy inspection finds only the already
queued M2.3a initGraf defect.

The menu checkpoint reached Core+$4B48 GetDeviceList. The logical device
selection below now passes, while integrated driver/font, graphics, PAK and intro
acceptance remain pending. Failed probe actions, missing-call captures and a
wrapped/truncated observer log were rejected before the paired pass. No timeout
or deferred rendered-window check is counted as passing; no owner decision changed.

## Graphics-device reference contract

M2.1c3c2c1's bounded original startup capture validates the four Core device
selection calls, 640×480×8 GDevice/PixMap fields, the 256-entry CLUT header,
HasDepth mode $83, the rectangle result and the original one-device selection
through the second Times lookup. The checker also rejects eight corrupted
captures; its incomplete-capture checks run in `make host-tests`. See
[graphics-device.md](graphics-device.md) for reproduction and exact scope.
The native implementation below uses this independently checked contract.

## Native logical graphics device

M2.1c3c2c2 supplies the real 640×480×8 buffer and consistent GDevice/PixMap,
monochrome screenBits/window-manager bitmap and region bounds. Original
GetDeviceList, HasDepth, OffsetRect and GetNextDevice pass paired Mac/native
checks, preserve their measured stack/register contract, and select one device.
The full 307,200-byte pixel buffer is dumped and checked; all relevant record
fields match the reference. The next named stop is Core+$0500 SetDepth,
PaletteDispatch selector $0A13. The palette is un-realized storage; eight-bit
drawing, palette use, GWorld construction and presentation stop explicitly.

Validation: clean production boot/resource-read, the device/menu/driver/font,
file-catalog/identity/original-startup/low-memory observers, full host suite and
both link audits pass. Menu records and both driver calls retain their paired
Mac results; the first Times result and installed font bytes still match. All
75,616 A5 globals match exactly. Existing preferences use 32 windows and 40/40
services. Fresh-preferences device selection also passes with 58 windows and
48/48 services; the original existing preference files were restored afterward.
Resource reads remain 24/104,667 original bytes and 3/1,318 overlay
bytes. No second Times, palette, rendered frame or full startup acceptance is
claimed. SetDepth remains first in the queue; M2.3/M2.4/M2.7 retain full graphics
acceptance. No owner decision changed.

## SetDepth startup

M2.1c3c2c3 implements the original already-active mode request: selected device,
depth 8, flags 1, values 1. Mac/native captures return zero OSErr with ten-byte
cleanup and preserve D3–D7/A2–A6. Complete device and PixMap records and the full
color table remain unchanged; all 307,200 native pixel bytes also remain
unchanged. Device/master/PixMap/backing identity is checked. Other SetDepth
requests retain the named stop. See [graphics-device.md](graphics-device.md).

Clean boot/resource-read, the SetDepth/device/menu/driver/font and catalog/
identity/original-startup/low-memory observers, the host suite and both link
audits pass. All 75,616 A5 globals match. The new stop is Dan2+$30E2 GetGWorld,
selector 5. Loading Dan2 adds CODE 13 (17,292 bytes) and CREL 13 (1,288 bytes):
26 runtime resource reads / 123,247 bytes in total. Existing preferences use
34 OS windows and 42/42 services. Fresh-preferences SetDepth also passes with
60 windows and 50/50 services; existing preferences were restored afterward.
Overlay reads stay 3 / 1,318 bytes. Dan2 changes
the loaded-segment mask to $3B8B but adds no low-memory sites: 58 validated,
55 applied. The observer's old mask was rejected, then updated from that
measured residency and the original site table; its live patch/tick checks pass.

The SetDepth checker initially required all of incoming D0 to equal $0A13.
Original bytes prove MOVE.W leaves its pointer-dependent upper half intact;
the checker now validates the selector word and tests this case explicitly.
The native handler already used the low word. Timeouts, incomplete captures,
wrong requests/results and duplicated positive records remain failures. Full
palette, offscreen/rendered graphics and the second Times lookup are pending;
no owner decision changed.

## Current-world startup query

M2.1c3c2c4 implements original Dan2+$30E2 GetGWorld. The reference/native pair
returns the current WMgrPort and main GDevice, pops eight bytes, and preserves
D0–D7/A2–A6. All portable bytes of the 108-byte port agree, and the query leaves
it unchanged. The reference revealed that WMgrPort's old-style bitmap has the
eight-bit device's base and 640-byte stride, while screenBits is an 80-byte
monochrome view over the same base. Native records now match, including
WMgrPort's default txSize=0; the redundant separate monochrome buffer is gone.
The live native observer proves both records use the device's real backing.

GetGWorld allocates no synthetic world and leaves current-port state intact.
The next request, GetNewDialog(1000) at Dan2+$341C, stops explicitly as
`DIALOG MANAGER / SCREEN SIZE SELECTION`, selector 1000, before constructing or
showing D4's excluded dialog. The fixed 320×200 choice remains first in the
queue. Further world bindings, drawing, palette realization, viewport output
and the second Times call remain pending. This query does not establish any
rendered-frame acceptance.

Validation: clean production boot/resource-read, GetGWorld/SetDepth/device/menu/
driver/font and catalog/identity/original-startup/low-memory observers, the full
host suite and both link audits pass. All 75,616 A5 globals match exactly.
Existing preferences use 34 windows and 42/42 services; fresh preferences pass
the same query/record checks with 60 windows and 50/50 services. Existing
preferences were restored afterward. Runtime reads remain 26/123,247 original
bytes and 3/1,318 overlay bytes; low-memory checks validate 58 sites with 55
applied. Every bounded acceptance run exited normally with its positive marker.
No owner decision changed.

## Original screen-choice contract

M2.1c3c2c5a separates the original/reference measurement prerequisite from
the pending native D4 implementation. Both original size inputs reach item 2
and WIND 128, with only PREF byte 7 changed to zero. The original call is
unconditional; a preference override cannot remove the dialog. Original-byte
guards cover preference loading/defaults, the selector/caller and window
selection. Both headless captures exit normally with positive markers; the
checker rejects eight malformed/status/input cases. Full host tests pass.
Native behavior is unchanged from the GetGWorld checkpoint; its next stop
remains SCREEN SIZE SELECTION. See [screen-choice.md](screen-choice.md).

## Hidden size-dialog construction

M2.1c3c2c5b1 implements the measured GetNewDialog(1000) dependency while
keeping D4's dialog hidden. The native constructor uses a real old-style port,
private DITL, two control handles and one text handle, and leaves qd.thePort
unchanged. It preserves D3–D7/A2–A6 and pops ten bytes. All portable record
fields, the full item list, controls, text and five regions match the Mac.
The source DITL is byte-identical afterward. Unsupported definition drawing,
presentation and constructor forms remain explicit stops. Owned-handle cleanup
is implemented; integrated original disposal/selection acceptance remains
M2.1c3c2c5b2. See [screen-choice.md](screen-choice.md).

The next named stop is Engine+$4782 QUICKDRAW / GETMAINDEVICE, before the
original SANE positioning calls. No original instructions were changed.
Clean boot/resource-read, the full startup observer set, paired graphics/menu/
driver/font checkers, the host suite and both link audits pass. Final-build A5
globals match all 75,616 bytes. Existing preferences use 36 windows and 43/43
services; fresh preferences use 62 windows and 51/51 services. Both constructor
record checks pass, and existing preferences are restored after the fresh run.
DLOG/DITL 1000 add two reads / 140 bytes: runtime original reads are now
28 / 123,387 bytes; overlay reads remain 3 / 1,318. Low-memory validation remains
58 sites / 55 applied, with segment mask $3B8B. These are logical-record checks,
not viewport/rendered-frame, full screen-selection or second-Times acceptance.
No owner decision changed.

## Main-device query for original positioning

M2.1c3c2c5b2a adds GetMainDevice at Engine+$4782. The original-byte-guarded
Mac/native pair returns the existing main handle with no argument cleanup,
preserves D0–D7/A1–A6, and leaves the full device record and current port intact.
There is no allocation, mode change or synthetic device. The next stop is
Engine+$47C2 SANE / FP68K, selector $200E, before the first positioning
conversion. The remaining arithmetic and fixed-choice requirements stay first
in the queue as M2.1c3c2c5b2b.

The exploratory reference trace `tmp/m2-sane-position-reference.log` completed
all ten original positioning calls normally. Selectors $200E/$1004/$2000/$0016/
$2010 convert a word, multiply by a single, add a word, truncate the extended
value, and convert to a word on this path. In particular, 355 × 0.5 becomes
177.5 and is truncated to 177; the vertical result is 205. This identifies the
next work; it is not native arithmetic acceptance or proof of other operands.

Validation: clean boot/resource-read, all maintained startup observers, paired
main-device/hidden-dialog/world/depth/device/menu/driver/font checks, the full
host suite and both link audits pass. All 75,616 A5 globals match exactly.
Existing and fresh preferences pass with 36/62 windows and 43/51 completed
services; the existing preferences were restored afterward. No new resource
reads are introduced: 28 / 123,387 original bytes and 3 / 1,318 overlay bytes.
The local SANE trace additionally passes exact rational operand/result, register,
stack and destination-bound checks; arithmetic implementation and full D4
selection remain pending. No owner decision changed.


## Integer-only original positioning

M2.1c3c2c5b2b implements the five original SANE operations with integer-only
68020 arithmetic. All ten original calls match the Mac operands/results,
registers, stack, FPState and bounded writes. Paired instrumentation found an
uninitialized MBarHeight shadow; the measured value 20 now produces the original
177/205 position. The native observer checks actual exception-frame flags
because debugger SR at original entry was stale. No FPU, Mac dialog drawing or
menu bar is introduced. See [sane.md](sane.md) for scope and reproduction.

Validation: 2,455 sanitizer/oracle cases, 41 original Mac fixtures, all ten
paired original calls, clean boot/resource-read, all thirteen startup observers
and the full host suite pass. Final link audits pass (76 probes), and all 75,616
A5 bytes match. Existing/fresh preferences pass with 36/62 OS windows and 43/51
completed services; existing preferences were restored. Resource reads remain
28 / 123,387 original bytes and 3 / 1,318 overlay bytes. Low-memory checks remain
58 validated / 55 applied, with live menu-height and ten-field tick checks.
Every accepted bounded run exited normally with its positive marker.

The next named stop is Engine+$48A2 MoveWindow. Remaining hidden positioning,
world binding and fixed-choice/item/disposal work remains M2.1c3c2c5b2c, with
integrated second-Times, viewport and rendering acceptance retained. Separately,
the owner clarified D5: replace all Mac dialog presentation, including new-game
and save/load, with an in-game interface. The updated design and M3.3 acceptance
record that decision; hidden records do not authorize Mac UI rendering.


## Hidden window positioning

M2.1c3c2c5b2c1 implements the original hidden MoveWindow request without drawing.
Its bitmap origin and three empty global regions match the Mac; local content,
items, controls, text, current port and window chain remain unchanged. Stack and
preserved registers pass. The next stop is Dan2+$30FE ModalDialog. Full fixed
selection remains queued, with no change to D4/D5/D7 or rendered acceptance.

A failed record comparison exposed ambiguous hexadecimal offsets in the Mac
capture scripts: `a0`/`a4` were read as registers. Corrected constructor/movement
captures supersede the earlier tail-byte evidence and establish editField=-1,
now initialized natively. A constructor probe/write watchpoint verifies its
preservation. Opaque unused TextEdit state is excluded across implementations,
but every dialog byte except bitmap bounds remains unchanged within each side.
The broader emitter audit is newly queued ahead of continuing selection.

Final clean boot/resource-read, all fourteen startup observers, the full host
suite and paired constructor/movement, SANE, main-device, world/depth/device,
menu, driver and font checks pass. All 75,616 A5 bytes match. Fresh/existing
preferences pass with 62/36 windows and 51/43 completed services, with existing
files restored afterward. Resource reads remain 28 / 123,387 original bytes and
3 / 1,318 overlay bytes; low-memory sites remain 58 validated / 55 applied.
No-float and probe audits pass (76 symbols). Accepted runs use the final stable
build and normal exits with positive markers. An earlier observer run overlapped
a rebuild and timed out; it was discarded, not counted as passing. Evidence and
reproduction are in [screen-choice.md](screen-choice.md); final native logs use
`tmp/m2-hidden-move-accepted-` and the fresh run is `tmp/m2-hidden-move-fresh.log`.


## Reference-capture literal audit

M2.1c3c2c5b2r makes generated hexadecimal operands explicit in 36 emitters,
adds a host regression over all 41 maintained Mac/MAME Lua scripts, and requires
exact input readback in the 41-case original SANE fixture. All sources compile
in MAME; fresh constructor/movement/menu/SANE captures exit normally and pass.
Paired native records remain valid with the corrected references. Menu semantic
bytes were unaffected; only trailing dump padding changed. The full host suite
passes, including source-checker mutations and fixture-input rejection cases.
The native executable is unchanged; the prior native regression results remain
applicable. Detailed exposure and replacement evidence are in
[mac-reference-loop.md](mac-reference-loop.md). Fixed size selection is again
first in the implementation queue; no owner decision changed.

## Hidden fixed-choice services

M2.1c3c2c5b2c2a implements D4's immediate item-2 policy, the original button
lookup, private dialog disposal and main-world restoration. Both existing size
inputs and fresh preferences pass paired service/selection checks; no dialog is
shown and only PREF byte 7 changes. All four private handles are released,
returning 384 physical bytes, with cleared allocation flags and an unused slot.
Original instructions remain unchanged. The next named stop is GetFontInfo,
Misc1+$0610, before WIND 128 creation. The unfinished WIND acceptance is retained
in M2.1c3c2c5b2c2c behind the new font-metrics prerequisite.

The full host suite, clean-build boot/resource-read, fourteen affected startup
observers and their paired contract checks pass. A5 remains exact across 75,616
bytes; low-memory validation/application remains 58/55. The 68020 no-float and
76-symbol probe audits pass. Original MDRV remains absent. Native evidence is
`tmp/m2-choice-accepted-*`; selection/reference reproduction is documented in
[screen-choice.md](screen-choice.md). One menu observer lost its connection
without completion and was rejected; its retry completed and passed the full
paired check. A debugger expression error in the initial choice observer was
also rejected and corrected before the accepted three preference runs.

## Original startup font-metrics contract

M2.1c3c2c5b2c2b1 captures and verifies 25 GetFontInfo records and 50 CharWidth
results for the original five font/size and five style combinations. The bounded
MAME run exits normally; original bytes, input tables, eight-byte output extents,
stack/register preservation and saved text-state restoration all pass. Rejection
checks and the full host suite pass; the literal audit now covers 43 scripts.
The native first-call input and both tables match in a read-only stop snapshot.
This is a reference-only prerequisite: native code and its GetFontInfo stop are
unchanged, so the previous native regression evidence remains applicable.
Installed definitions and native service acceptance remain at the top of the
queue. Reproduction and measured cases are in [font-manager.md](font-manager.md).

## Installed startup font metrics

M2.1c3c2c5b2c2b2 installs 25 port-owned bitmap faces and implements GetFontInfo
and CharWidth from their FOND/NFNT bodies. All 75 original calls match the Mac
contracts, including output bounds, stack/register preservation and restored
text state. Existing, fresh and low-resolution preferences pass; all 30 installed
font bodies match the generator byte-for-byte. The final guarded run is
`tmp/m2-metrics-native-final.log`, paired with
`tmp/m2-font-metrics-reference-accepted.log`. No original instructions changed,
no FPU is required, and these services draw no dialogs. Other glyph advances
remain explicitly placeholder design; rendered-font acceptance remains M2.9.

The full host suite (including font sanitizer checks), fifteen startup observers,
paired service checks and clean production boot/resource-read regressions pass.
File-write and all eight save/preference exit phases pass; original save and
preference directories are restored. A5 matches all 75,616 bytes, low-memory
sites remain 58 validated / 55 applied, and no-float/76-symbol probe audits pass.
Original resource reads remain 28 / 123,387 bytes. Existing/fresh runs complete
64/90 windows and 118/126 services respectively. Overlay metadata preparation
uses 33 reads / 572 bytes; runtime bodies total 31 / 80,800 bytes.

Early observer failures (unloaded segment and debugger macro argument parsing)
were rejected and corrected. A run affected by editing its active launcher was
also rejected; the stable-launcher reruns passed. Evidence uses
`tmp/m2-metrics-accepted-*` and `tmp/m2-metrics-regression-*`.
Startup now stops explicitly at Engine+$1038 AEInstallEventHandler, selector
$091F. Handler registration is the next dependency; WIND 128, the second Times
lookup, rendering and full M2 acceptance remain pending. Original MDRV stays absent.

## Original Apple Event registration contracts

M2.1c3c2c5b2c2b3a measures all four original registrations and 17 separate
lookup/replacement/error fixtures. Both bounded Mac modes exit normally with
positive markers and pass the independent checker, including input readback,
output bounds, stack/registers and malformed-capture rejection. All 44 Mac
scripts pass syntax and literal audits; the full host suite passes. The native
executable is unchanged and still stops at AEInstallEventHandler, so its previous
regression evidence remains applicable. Native state and paired acceptance are
retained as b3b at the top of the queue. See [apple-events.md](apple-events.md).

## Native Apple Event registrations

M2.1c3c2c5b2c2b3b retains the four original callback/refCon registrations in an
application-owned table, with measured exact lookup, replacement and invalid
handler errors. Four original calls and 17 CPU-executed native fixture calls pass
the independent Mac contracts. Six unsupported forms stop explicitly without
changing state. Actual probe shutdown clears the table, closes both resource
streams, removes Line-A and returns zero from native main. Original instructions
are unchanged and no callbacks run from interrupts. Event delivery remains M3.4.

All 16 startup observers and paired service checks pass, as do the full host
suite, clean boot/resource-read, file-write and eight save/preference resource-exit
phases. A5 matches all 75,616 bytes; low-memory sites remain 58 validated / 55
applied. Existing/fresh preferences retain 64/90 windows and 118/126 services.
Original resource reads remain 28 / 123,387 bytes; overlay bodies 31 / 80,800.
Production no-float and 77-symbol probe audits pass. Original preference/save
directories are restored. Evidence is `tmp/m2-ae-accepted-*`,
`tmp/m2-ae-regression-*`, `tmp/m2-ae-native-cpu-fixture-final.log`, and
`tmp/m2-ae-native-final-clean.log`; reproduction is in [apple-events.md](apple-events.md).

Rejected debugger-driven fixtures led to direct write/readback instrumentation:
this FS-UAE debugger ignores register and memory writes. The accepted fixtures
construct inputs on the CPU and use read-only observers. A file-write run hit
its 120-second deadline; the runner interrupt was confirmed in the remote log.
It was rejected, and the unchanged clean retry passed with a 240-second bound.

The next named stop is GetCTable(128), Engine+$110E, before WIND 128 creation.
Colour-table ownership and bytes are the next ordered dependency; palette
realization, the second Times lookup and full M2 acceptance remain pending.

## Original GetCTable ownership contract

M2.1c3c2c5b2c2b3c1 captures the original GetCTable(128) return and all 256
subsequent index mutations, plus 21 separate ownership/seed/disposal calls. The
returned handle is detached from the resource map: when clut 128 is already
loaded, GetCTable returns that same handle, clears its resource state and assigns
a new seed. Subsequent requests reload original bytes into distinct handles.
Mutation and disposal tests prove the alias relationship; seed calls establish
one consumed seed per successful table request and none for the measured missing
ID. This rules out a copy-only implementation that retains the old resource map
entry. See [color-table.md](color-table.md) for exact scope and reproduction.

Both bounded Mac capture modes exit normally and pass byte, input, stack/register,
state and output checks. Syntax/literal audits cover 45 scripts; the full host
suite passes. A checker line-anchoring mistake was corrected before acceptance;
no failed capture was counted as a pass. Native code is unchanged, so the
previous native regression evidence remains applicable. Native detachment and
paired acceptance remain b3c2 at the top of the queue.


## Native startup colour table

M2.1c3c2c5b2c2b3c2 implements the original GetCTable(128) request through the
user-mode resource service. The returned handle is detached, gets a fresh seed,
and survives all 256 original index mutations with its RGB values intact.
The 21 CPU-executed ownership cases match the Mac, including alias mutation,
reload, disposal, missing tables and interleaved seeds. The fixture uncovered
an unsupported disposed-handle size query; released master slots now return the
measured -111 error. Arbitrary pointers remain named stops. No original game
instructions changed. Reproduction and scope are in [color-table.md](color-table.md).

The full host suite, 17 startup observers with paired contracts, clean boot and
resource-read regressions pass. Fresh and existing preference inputs pass;
original preferences are restored. Final fixture and production captures exit
normally with positive markers. All 75,616 A5 bytes match the original model;
low-memory sites remain 58 validated / 55 applied. No-float and 77-symbol link
audits pass. Evidence is `tmp/m2-ctable-accepted-*`, `tmp/m2-ctable-host.log`,
`tmp/m2-ctable-final-runs.log`, `tmp/m2-ctable-native-fixture-final.log` and
`tmp/m2-ctable-native-final.log`; final fixture dumps are preserved separately.

Startup now completes 65/91 OS windows and 119/127 user services for existing/
fresh preferences. Original runtime resource reads total 29 / 125,443 bytes;
overlay bodies remain 31 / 80,800. The next named stop is NewPalette at
Engine+$1158. Original MDRV remains absent. WIND 128, the second Times lookup,
PAK-read acceptance and rendered intro output remain pending. D4/D5/D7 still
exclude Mac dialog/menu presentation; no owner decision is needed here.

## Original NewPalette construction contract

M2.1c3c2c5b2c2b3d1 measures the original 256-entry NewPalette request, full
4,112-byte result and twelve ownership/lifecycle cases. RGBs are copied, usage
is $000A and tolerance is zero. The palette owns a separate four-byte private
allocation; DisposePalette frees both without changing the source table.
Original/live bytes, exact data extents, stack/register preservation, fixture
input readback, mutation isolation and errors pass. See [palette.md](palette.md).

Both bounded Mac captures exit normally, all 46 scripts pass syntax/literal
checks, and the full host suite passes. Accepted evidence is
`tmp/m2-palette-reference-accepted.log`, `tmp/m2-palette-ownership-accepted.log`
and `tmp/m2-palette-reference-host.log`, with each capture's dumps preserved.
A checker initially rejected missing floppy-sound samples as capture errors;
that overly broad check was corrected before the accepted runs. Native code is
unchanged from 5e568da and retains its verified NEWPALETTE stop. Native
construction is b3d2 at the queue head; no palette realization or intro-frame
acceptance is claimed.

## Native palette construction and disposal

M2.1c3c2c5b2c2b3d2 implements the measured NewPalette form and unattached
DisposePalette ownership. The original constructor and twelve CPU-executed
lifecycle cases match the Mac: complete 256-entry records, independent RGB
copies, source preservation, both owned allocations freed, and exact stack/
register/error contracts. Actual probe shutdown releases both zones, closes
resource streams, removes Line-A and returns zero. Other forms remain named
stops. No original instructions changed; see [palette.md](palette.md).

All nineteen startup observers and paired contracts pass, as do the host suite,
fresh/existing preferences, boot/resource-read and final clean fixture/production
runs. The final production executable matches the startup regression binary.
All 75,616 A5 bytes match; low-memory sites remain 58 validated / 55 applied.
No-float and 77-symbol audits pass. Native palette construction adds no resource
reads or OS windows: existing/fresh runs remain 65/91 windows and 119/127
services, original resource bodies 29 / 125,443 bytes, overlay 31 / 80,800.
Original preferences are restored. Evidence is `tmp/m2-palette-accepted-*`,
`tmp/m2-palette-native-host.log`, `tmp/m2-palette-final-runs.log`,
`tmp/m2-palette-native-fixture-final.log` and `tmp/m2-palette-native-final.log`.

The initial SANE observer failed because it inspected released supervisor-stack
storage after a VBL callback. Instrumentation verified CCR=0 before RTE and at
the callback's restore point, while the reused old frame read 4 afterward. The
observer/checker now validate live frames and callback routing/restoration;
no SANE or trap-return runtime code changed. Rejected runs remain local; the
accepted evidence is `tmp/m2-palette-sane-live-frames.log`.

Startup advances to Engine+$1172 SETPALETTE. Its binding and device effects are
the next ordered prerequisite. Original MDRV remains absent; WIND 128, second
Times, original PAK reads, palette realization and intro-frame acceptance remain
pending. There is no Mac UI rendering or owner decision change.


## Original default-palette binding contract

M2.1c3c2c5b2c2b3e1 measures the original SetPalette(-1) request and independently
checks its binding with GetPalette(-1). Only palette byte 6 changes; the private
allocation, device records, logical CLUT, full physical framebuffer and hardware
palette remain unchanged. Stack/registers and original/live bytes pass. The
probe distinguishes physical NuBus video from debugger logical-address aliases.
Incorrect query/opcode and aliased pixel evidence were rejected before acceptance;
see [palette.md](palette.md) for reproduction and the measured contract.

The bounded accepted Mac run exits normally, all 47 scripts pass syntax/literal
checks, and the full host suite passes. Native runtime code is unchanged from
546480a, so its prior regression evidence remains applicable. Native binding and
paired startup acceptance remain e2 at the queue head; no rendered acceptance or
owner decision change is claimed.


## Native default-palette binding

M2.1c3c2c5b2c2b3e2 implements the original SetPalette(-1, palette, true) request.
The default binding, exact palette mutation, private allocation and unchanged
device/screen/palette state match the Mac. Uninitialized calls and unsupported
forms stop explicitly. A CPU fixture leaves a palette bound through actual
shutdown, then verifies cleared binding/zones, closed streams, restored Line-A
and a zero result. Original game instructions are unchanged; see [palette.md](palette.md).

All nineteen startup observers and paired contracts pass on the final binary,
as do fresh/existing preference variants, clean boot/resource-read, the shutdown
fixture and a final full host suite. No-float and 78-symbol audits pass. A5 remains
exact across 75,616 bytes; low-memory sites remain 58 validated / 55 applied.
Existing/fresh startup completes 67/93 OS windows and 121/129 services. Original
resource bodies total 31 / 130,660 bytes; overlay bodies remain 31 / 80,800.
Original preferences are restored and the final production hash is stable.

Shared-host load caused earlier deadlines to expire; those runs were rejected.
After interruption, live processes were checked before resuming the unfinished
observers. The shutdown fixture initially lacked QuickDraw initialization;
instrumentation established depth zero. Normal initialization and explicit
assembly-label addresses corrected its setup/observer. The new uninitialized-call
guard received a complete refreshed final native suite. Evidence and reproduction
are in [palette.md](palette.md); final host evidence is
`tmp/m2-setpalette-host-final.log` and the full native suite is
`tmp/m2-setpalette-final-startup-suite.log`.

The next named stop is Misc1+$1296 SETWTITLE. Original WIND 128 request acceptance
is next in the queue, followed by measured window-title state. Original MDRV is
absent; no Mac dialog/menu presentation or rendered-intro acceptance is claimed.


## Hidden window title state

M2.1c3c2c5b2c2d implements the original hidden title update using owned title
handles and the installed system font's 95 measured printable advances. The
paired original call preserves its input, ports, regions and all window-record
bytes except cached title width (85 to 34); the result is a six-byte Pascal
`Hider` string. WIND title/goAway/refCon offsets are corrected against original
bytes. No original instructions or Mac UI presentation are introduced.
See [window-title.md](window-title.md) for scope and reproduction.

The full host suite, twenty startup observers and paired contracts, fresh/low
preference variants, clean boot/resource-read and final title capture all pass
with normal exits. A5 is exact across 75,616 bytes; low-memory sites remain
58 validated / 55 applied. No-float and 78-symbol audits pass. The clean binary
matches the one used for startup regressions, and original preferences are
restored. Existing/fresh runs complete 68/94 OS windows and 124/132 services;
original resource bodies are 32 / 130,692 bytes, overlay bodies 31 / 80,650.

The initial native capture had stale overlay metrics and was rejected. The
regenerated overlay is 81,462 bytes; the host suite's old exact-size assertion
was updated after independently measuring the new artifact. A reference-checker
WIND offset error was also rejected and corrected. Accepted evidence uses
`tmp/m2-title-reference-contract.log`, `tmp/m2-title-native-final.log`,
`tmp/m2-title-startup-suite.log` and `tmp/m2-title-host-final.log`.

Startup now stops at window SetPalette, Misc1+$10FA, with original MDRV absent.
Integrated WIND 128 selection acceptance is next, followed by the newly queued
window-binding form. Second Times, original PAK reads and rendered intro remain
pending; no owner decision changed.


## Integrated WIND 128 selection

M2.1c3c2c5b2c2c extends the fixed-choice observer to the actual original
Misc1+$109A request, distinguishing it from WIND 131. Existing size-one, fresh
preferences and existing size-zero runs request WIND 128 and match the Mac's
complete preference byte changes. The live instructions and sole relocated
operand pass original-byte checks. Hidden dialog/service checks still pass and
the next stop remains window SetPalette, Misc1+$10FA.

All three bounded runs exit zero with positive markers; checker rejection cases
and original byte checks pass. Original preferences are restored. The runtime
executable is unchanged from 4b54e82, whose full host suite, twenty startup checks,
boot/resource-read and link audits remain applicable. This is selection acceptance,
not viewport or rendered output. See [screen-choice.md](screen-choice.md).


## Window palette and client clear

The original MoveWindow/ShowWindow transitions now match the Mac's complete
palette/private/CLUT effects. Original window colour resources drive the black
320×200 client clear; its exact dirty rectangle is retained. No Mac chrome is
rendered. The next named stop is `8-BIT PRESENTATION`, before window binding.
M2.5a brings the required display path forward; see [palette.md](palette.md).

All 21 startup observers and paired checks, preference variants, host suite,
clean boot/resource-read and link audits pass on the same executable. Original
preferences are restored. A5 remains exact, low-memory sites are 58/55, and
existing/fresh runs use 70/96 OS windows and 124/132 services. Original resource
reads are 34 / 130,788 bytes; overlay reads remain 31 / 80,650. The paired checker
also validates the exact reference cursor exception and rejects corrupt captures.
This is logical state/pixel acceptance; rendered AGA/intro checks remain pending.


## First eight-plane client publication

M2.5a converts the live WIND 128 client rectangle into eight AGA planes and
publishes complete bitmap/palette state during VBI. The first clear matches the
Mac logical CLUT and measured video colours, then startup reaches window
SetPalette at Misc1+$10FA. No original game instruction changes. The integer
reference converter uses explicit dirty rectangles and Vette's previous-update
synchronization; optimization remains deferred.

The independent five-frame native fixture verifies full and partial updates,
palette-only preservation, viewport movement, alternating buffers and restored
OS cleanup. All 21 startup observers and paired contracts, preference variants,
host tests, clean boot/resource-read and system-window memory checks pass.
See [aga-display.md](aga-display.md) for commands, captures and the exact build.
Rendered output, PAL/NTSC and pointer acceptance, and full intro verification
remain in the ordered M2 queue.


## Window palette binding

The original SetPalette(window, default palette, true) now binds the visible
front window without changing its already-realized colours or pixels. Paired
captures verify original/relocated bytes, stack/register behavior, private seed,
full palette/CLUT and display preservation. Capture the native service after
its dispatcher publishes the preceding clear; see [palette.md](palette.md).

Default-binding, client-clear, original-startup, native-driver and first-frame
regressions pass, along with fresh/low preferences, the host suite, clean boot
and resource reads. A5 is still byte-exact, original MDRV is absent, and startup
now stops at ActivatePalette, Misc1+$1100. That measured dependency is next in
the queue; M2 intro and rendered acceptance remain incomplete.


## Already-realized palette activation

ActivatePalette at Misc1+$1100 now accepts the measured already-realized,
active palette bound to the visible front window. The original Mac call leaves
all palette, device and pixel state unchanged; the native service preserves
that state and queues no extra frame. Unmeasured activation states stop loudly.
See [palette.md](palette.md) for the original bytes and paired capture procedure.

Six relevant startup observers and paired checks, host tests, fresh/low
preferences, clean boot/resource reads and exact A5 comparison pass. Original
preferences are restored and original MDRV remains absent. Startup subsequently passes ShowHide, game-port binding, TickCount and unchanged
window geometry; intro and rendered acceptance remain pending.

## Colour-window geometry and background visibility

Use `color_window_geometry.gdb`, `window_move_geometry.gdb` and `showhide.gdb`
with their corresponding Mac observers and paired checkers. The contracts and
local evidence are in [window-geometry.md](window-geometry.md). Host geometry
checks are part of `make host-tests`. ShowHide's background clear is verified
against its full complex region and must leave the viewport, palette and frame
queue unchanged. Current startup observers pin UnionRect at Dan2+$01DA; a timeout or a different stop is not acceptance.


## Startup clock query

TickCount now returns the existing private Macintosh clock with the measured
stack/register contract. Original bytes, the full-width Mac fixture and native
clock source pass paired checks; see [amiga-arch.md](amiga-arch.md). The bounded
window-core run verifies 407 PAL fields / 489 ticks and exact 1 MiB reads across
OS handbacks. Host tests, existing/fresh startup, AGA publication and resource-read
regressions pass. All 75,616 A5 bytes match, both link audits pass, and original
preferences are restored. Existing/fresh startup uses 75/101 OS windows and
129/137 services; original resource reads total 39 / 177,820 bytes. Original
MDRV remains absent. Evidence is in local `tmp/m2-tickcount-*` logs.

The clock query advances into drawing setup. Logo/intro and rendered-window
acceptance remain pending; no owner decision changed.


## Unchanged startup window geometry

The original size/origin requests now preserve the already-correct visible
320×200 window. Paired captures verify original bytes, arguments, stack and
preserved registers, all window/region/device/palette records and all 307,200
screen pixels. No display update or OS handback is added. The native stop is
now QUICKDRAW / SETPT at Dark+$4F88. Actual resize/movement and unsupported
window arrangements remain named stops; no Mac chrome is drawn.

The final paired capture is `tmp/m2-reassert-native-final.log`, checked against
`tmp/m2-resize-reference-accepted.log`. Host tests and both link audits pass.
The relevant startup/display evidence uses `tmp/m2-reassert-*` logs; see
[window-geometry.md](window-geometry.md) for the measured contracts.
Existing/fresh startup and AGA publication checks pass on the final executable:
75/101 OS windows, 129/137 services, one queued/presented frame, all eight planes
and all 256 colours. Original preferences are restored; A5 matches all 75,616
bytes. Original MDRV remains absent. Rendered-window and intro acceptance remain
pending; no owner decision changed.


## Drawing point initialization

SetPt at Dark+$4F88 now writes the original vertical/horizontal words into
the point, with the measured stack/register contract. The paired original/native
check validates live instruction bytes, the exact four-byte write and preserved
neighbouring storage. The final bounded runs in `tmp/m2-setpt-final-*` pass
SetPt, original startup and AGA publication on the same executable. All 75,616
A5 bytes match; no-float and 78-symbol link audits pass. Original resource reads remain 39 / 177,820 bytes, with 75 OS handbacks and
129 services.
Original MDRV is absent. Startup now stops at QUICKDRAW / NEWRGN, Misc2+$1DA6.
See [amiga-arch.md](amiga-arch.md) for the byte guard and contract.


## Empty-region allocation

NewRgn at Misc2+$1DA6 now allocates a real empty ten-byte region in the current
heap. Original Memory Manager queries establish size, flags and owning zone;
the native observer verifies the real master slot and owning block. Paired
bytes, contents, error state and stack/register checks pass. See
[amiga-arch.md](amiga-arch.md) for the contract and original-byte guard.

`tmp/m2-newrgn-final-*` contains normal-exit passes for the paired region call,
original startup and AGA publication on the final executable. The heap suite
passes including 2,500 fragmentation operations; both link audits pass. All
75,616 A5 bytes match. Resource reads remain 39 / 177,820 bytes, with 75 OS
handbacks and 129 services; original MDRV is absent. The next named stop is
QUICKDRAW / NEWGWORLD, selector 0, Misc2+$0074. Full region drawing and intro
acceptance remain pending.


## Owned eight-bit offscreen allocation

NewGWorld at Misc2+$0074 now constructs a real eight-bit world, including its
pixel handle, 27 owned auxiliary handles and private device. Complete defined
records and pointer relationships match the Mac. The measured inverse-table
builder matches all 4,096 entries and 256 collision links; source colour-table
flags are preserved across protected allocation. Main device and screen bytes
remain unchanged. See [gworld.md](gworld.md) for contracts and reproduction.

The full host suite, exact inverse reference comparison, final native allocation,
original startup and AGA publication pass. The accepted final runtime evidence
is `tmp/m2-newgworld-final2-*`; the reference is
`tmp/m2-newgworld-ownership-all.log`. Both link audits pass, and all 75,616 A5
bytes match. Original resource reads remain 39 / 177,820 bytes, with
75 OS handbacks and 129 services. Original MDRV is absent. A stale expected-stop value in an
earlier startup observer was corrected; that rejected run is not acceptance.

The next stop is offscreen SetGWorld, Misc2+$008E. The subsequent original
bind/clip/lock/erase/unlock/restore sequence is one coherent queue item; this
allocation does not claim initialized offscreen pixels or logo/intro acceptance.


## Offscreen buffer initialization

The complete original bind/clip/lookup/lock/erase/unlock/restore sequence now
passes paired record, stack, lock and pixel checks. Its 259,848 visible bytes
clear exactly, all 1,604 padding bytes remain intact, and the native screen
remains unchanged. See [gworld.md](gworld.md) for scope and reproduction.
The production executable now reaches GETPIXBASEADDR at Misc2+$02DA.
Final paired evidence: `tmp/m2-gworld-init-reference-final.log` and
`tmp/m2-gworld-init-native-final.log`, both normal exit 0.
The host suite passes (`tmp/m2-gworld-init-host-final.log`). Startup and AGA
publication pass on the same final executable in
`tmp/m2-gworld-init-startup-final.log` and `tmp/m2-gworld-init-aga.log`.
All 75,616 A5 bytes match, and both link audits pass. Startup now performs
41 original resource reads / 206,540 bytes, with 77 OS handbacks and 131
completed services; original MDRV remains absent. The extra two reads are
newly reached work, not an allocation-side handback. An observer with the old
75/129 counts was rejected, instrumented and corrected. Fresh-preference
endpoint counts are derived as the same prior +26 windows / +8 services;
this change's native acceptance uses the existing-preference route.
This does not claim the remaining M2 acceptance.


## Owned pixel-address access

The original GetPixBaseAddr call now returns the real buffer pointer and the
following original 56-row copy matches the Mac. The pure helper also matches
the measured unlocked reference contract. See [gworld.md](gworld.md) for the
explicit verification scope. The native observer combines startup, paired
copy and AGA checkpoints to avoid repeated launches of the same executable.

A reference probe initially crashed MAME during boot. The macOS crash report
identified a null string passed to the Lua debugger breakpoint binding:
`cpu.debug:bpset` requires an explicit third action argument, even an empty
string. The corrected reference exits normally; crashed runs are not evidence.
The original copy-loop's relocated JSR is validated against A5, not compared
as an unrelocated address literal.

`tmp/m2-pixbase-native-final.log` exits normally and passes the paired pointer
and row-copy check, original main/A5 checkpoint, original-MDRV exclusion and
AGA publication on one executable. All 75,616 A5 bytes match; all eight planes
and 256 colours match the independent display decoder. The helper sanitizer
suite, locked/unlocked reference comparison, Lua literal audit and both link
audits pass. Counts remain 77 OS handbacks, 131 services and 41 original
resource reads / 206,540 bytes. No rendered intro acceptance is claimed.


## Hidden startup menu-list setup

ClearMenuBar, four InsertMenu calls and the suppressed DrawMenuBar now complete
with measured menu order and unchanged application records. The native screen
is unchanged. Reference capture includes a nonempty clear proving that menu
handles/records survive list removal. The final native observer also reaches
both original Times lookups and checks the original native-driver calls in the
same launch; their retained queue acceptances are the next items.
See [menu-manager.md](menu-manager.md) for exact scope and reproduction.

The final reference and native menu-lifecycle captures exit normally. Paired
menu records/order, six call results, unchanged screen, menu-record host suite,
Lua literal audit and both link audits pass. Both original Times lookups return
20; native driver selectors 21/24 retain their measured state/ABI. A5 matches
all 75,616 bytes. The AGA decoder verifies exact pixels, eight plane pointers,
256 colours and VBI publication. Counts are now 81 handbacks, 143 services,
42 original resource reads / 208,858 bytes; overlay remains 31 / 80,650 and
preparation 64 / 81,222. The next stop is UNIONRECT at Dan2+$01DA. This does
not count either pending driver/font acceptance item as removed yet.


## Integrated native driver startup acceptance

M2.1c3c2 is complete using the existing combined native capture
`tmp/m2-menu-lifecycle-native-final.log` (exit 0) and the independent original
`tmp/m2-driver-startup-reference.log` (exit 0). Both original call sequences,
selector arguments, return registers, preserved registers, stack and resulting
native state pass. Second Times returns 20 after exactly two native driver calls;
UnionRect is the next named stop and no original MDRV is resident. The shared
observer also proves inactive voices, unassigned channels, original main/A5 and
AGA memory/publication. The driver observer now delegates to that shared script.
The native acceptance checker requires this integrated endpoint and rejects
missing/reordered calls, wrong results, unfinished services and timeout/error
completion. Sanitizer-backed driver state tests and checker rejection fixtures
pass. No runtime code changed; no repeat emulator launch was necessary.


## Paired installed-font startup acceptance

M2.1c3 is complete. The shared observer now checks the second original call at
Dan1+$0038 directly, preserving its entry D0 for return comparison and requiring
zero ResErr/MemErr. `tmp/m2-font-integrated-native.log` exits 0 and records both
Times=20, eight-byte cleanup, second D0=$00312FF2 preserved and exact installed
FOND/NFNT bodies. Original/reference fixtures, native driver acceptance, font
parser sanitizer tests and checker rejection fixtures pass. AGA publication
still passes and all 75,616 A5 bytes match. Counts and UnionRect endpoint are
unchanged. No runtime code changed; the one new native run fills the missing
second-call ABI evidence. Remaining font rendering is M2.9.


## Original image rectangle preparation

UnionRect now passes all twenty original Dan2 calls against the Mac, including
identical input and output rectangles. The pure helper matches eleven additional
reference edge/alias cases under sanitizers. See [rectangles.md](rectangles.md)
for the contract and reproduction. The final combined native run exits 0 and
also passes both Times calls, native driver checks, AGA pixels/palette/VBI and
75,616-byte A5 comparison. Both link audits and the 65-script MAME literal audit
pass. No original MDRV is resident. Current counts are 101 windows, 163 completed
services and 62 resource reads / 265,454 bytes; next is DetachResource at Dan2+$0210.
The full host suite passes (`tmp/m2-unionrect-host.log`). Observers are pinned
to that new boundary. Fresh-preference counts are derived,
not a newly accepted run. Original PAK payload acceptance remains pending.


## Already-detached resource handles

M2.3g5 accepts the original Dan2+$0210 DetachResource call. GetCTable already
returned an owned table, so the Mac returns ResErr -192 and zero-extended D0
$FF40, clears A0, consumes four bytes and preserves MemErr, other registers and
the handle/body. The native boundary now returns that error for valid owned
handles absent from the resource association table; invalid handles still stop.
Attached and dirty-resource behavior is unchanged.

`mac_detached_resource.lua` measures the original call plus repeat, locked,
empty and nil cases, using CPU-only fixtures. The independent checker guards
original bytes and the live A5-relocated immediate, then checks results and
2,056-byte table preservation. Native flags remain owned/unlocked and unchanged;
no resource association appears. Cross-platform comparison excludes only the
independently allocated four-byte colour seed, as in prior GetCTable acceptance.

Accepted captures: `tmp/m2-detached-reference.log` and
`tmp/m2-detached-native-final.log`, both exit 0. Run
`python3 tools/check_detached_resource.py tmp/m2-detached-reference.log --status 0
--native tmp/m2-detached-native-final.log --native-status 0` with actual statuses.
The native capture uses the shared menu/startup observer. It also passes all
20 rectangle calls, both font lookups, native driver/MDRV guard, 75,616 A5 bytes
and AGA pixels/palette/VBI. Resource map/source/writer/directory/publication host
checks, startup checker tests, 66-script literal audit and both link audits pass.
The discovery capture's obsolete endpoint failed and is not acceptance.

Counts remain 101 windows, 163 services and 62 original resource reads /
265,454 bytes. Next is NewGWorld at Dan2+$0234, selector zero, with GetCTable's
$8000 table flag. Its input-table allocation behavior is queued as M2.3g6.
Locked/empty/nil variants here have reference evidence; this new native original
capture exercises the resident unlocked table. Prior attached/dirty resource
acceptances remain in force; this does not claim intro or audio acceptance.


## Device-table offscreen allocation

M2.3g6 is complete. The allocator accepts the measured $8000 colour-table flag
without altering the independent copy or caller's table. The existing world
capture/checker now supports both original sites; native record dumping is
shared rather than duplicated. See [gworld.md](gworld.md) for contract details.
The final reference/native captures exit 0 and agree on all defined world records,
27 owned handles, 78,048 pixel bytes and inverse-colour data. Both ordinary and
device-table host inverse comparisons pass, with sanitizers. Existing detachment,
20 rectangle calls, both font lookups, native driver/MDRV guard and AGA checks
pass in the same native launch. All 75,616 A5 bytes match; both link audits and
the literal audit pass. Counts remain 101 windows, 163 services and 62 original
resource reads / 265,454 bytes. Next is named RGBForeColor, Dan2+$02BE.


## Offscreen RGB drawing colours

M2.3g7 is complete. RGBForeColor/RGBBackColor use the owned world’s table and
inverse collision rings, update real port fields and preserve simple patterns.
See [color-drawing.md](color-drawing.md) for contract and verification scope.
The native original two-call sequence and reference 64-call colour fixture pass;
the native helper matches all 66 measured lookup results under sanitizers.
The final combined run exits 0 and passes world records/ownership, detachment,
20 rectangle calls, both Times lookups, driver/MDRV guard, AGA and all 75,616 A5
bytes. Offscreen helper regressions, startup checker tests, 67-script literal
audit and both link audits pass. Counts are 101 windows, 164 completed services,
62 original resource reads / 265,454 bytes. Next is DrawPicture at Dan2+$0382.
The discovery run failed its obsolete endpoint and is not acceptance. Fresh
preferences retain derived counts (127 windows / 172 services), not a new run.


## Indexed picture preparation

M2.3g8 is complete. All twenty original Dan2 pictures now draw into the owned
138×542 world using eight-bit PackBits and its actual inverse colour table.
Detached images use their real heap sizes. See [picture-drawing.md](picture-drawing.md)
for the measured format, original-byte guard and reproduction commands.

`tmp/m2-pict8-reference.log` and `tmp/m2-pict8-native-final.log` both exit 0;
the independent oracle verifies 1,560,960 destination bytes on each side,
including unchanged padding and outside pixels, preserved records and ABI.
The final combined capture also passes device-table GWorld records, detachment,
all twenty rectangle calls, both installed-font lookups, native driver/MDRV
exclusion, AGA publication/pixels/palette and all 75,616 A5 bytes. The full host
suite (`tmp/m2-pict8-host.log`), 68-script Lua audit and both link audits pass.
The initial observer failed before drawing because its size variable used a
register name; that run was rejected and the variable renamed. A later discovery
capture passed pixels; final acceptance additionally checks original live bytes,
startup and display on the final executable.

The next stop is QUICKDRAW / TEXTWIDTH at Dan1+$0216. Counts are 113 OS windows,
211 completed services and unchanged 62 resource reads / 265,454 bytes.
Fresh-preference endpoint counts (139 / 219 services) remain derived, not newly
accepted. No rendered intro or broader scaled-picture acceptance is claimed.


## Startup text measurement

M2.3g9 is complete. The original 220 Dan1 TextWidth calls pass paired string,
range, width, port and ABI checks. The native service validates the installed
Times/plain/14 selection and applies measured integer 8.8 accumulation without
FPU operations. Other selections remain named stops. See
[font-manager.md](font-manager.md#startup-textwidth) for contract and limitations.

Reference captures `tmp/m2-textwidth-fractions2.log` (529 fixtures) and
`tmp/m2-textwidth-original-reference.log` (220 original calls), and final native
`tmp/m2-textwidth-native-final.log`, all exit 0 with positive completion.
The compiled helper matches every fixture under sanitizers. The full host suite
(`tmp/m2-textwidth-host.log`), 69-script literal audit and link audits pass.
The same final native run also passes all twenty pictures, installed fonts,
device-table GWorld records, RGB calls, driver/MDRV exclusion, AGA publication
and all 75,616 A5 bytes. A discovery observer failed after reaching its next
stop; its termination check was corrected and it is not final acceptance.

Current stop: QUICKDRAW / SETGWORLD at Misc1+$0E0A, selector 6. Counts are
113 windows, 431 completed services and unchanged 62 resource reads / 265,454
bytes. Fresh-preference counts (139 windows / 439 services) are derived, not
newly accepted. Intro and rendered-window acceptance remain pending.


## Background drawing-port binding

M2.3g10 is complete. SetGWorld now accepts a validated owned visible colour
window even when it is behind the front window. Original bytes and paired
Mac/native capture prove the background-window binding and ABI; every window,
PixMap, device and screen byte is unchanged. Native palette and publication
state are unchanged. See [gworld.md](gworld.md#visible-background-window-binding).

`tmp/m2-world-restore-reference-final.log` and
`tmp/m2-world-restore-native-final.log` both exit 0 and pass the paired checker.
The same final run passes all twenty pictures, 220 text measurements, installed
fonts, driver/MDRV guard, AGA pixels/palette/publication and 75,616 A5 bytes.
Offscreen inverse/layout sanitizer checks, startup checker tests, 70-script Lua
audit and both link audits pass. Early reference attempts used the wrong segment
base and are rejected. The final reference's later clock-shaped cursor is checked
explicitly instead of reusing the earlier arrow's pixel count.

Next is QUICKDRAW / LOCALTOGLOBAL at Misc1+$0E20. Counts remain 113 windows,
431 services and 62 resource reads / 265,454 bytes. Fresh-preference counts
remain derived. No rendered intro acceptance is claimed.


## Background LocalToGlobal points

M2.3g11 is complete. Both original Misc1 corner-point conversions match the Mac,
including all preserved registers, four-byte stack cleanup, point guards and
unchanged port/PixMap records. The conversion reads the actual selected window's
screen-backed PixMap origin. The unused inherited Vette GlobalToLocal constant
is replaced with a named stop and tracked as M2.3b.

`tmp/m2-localglobal-reference.log` and `tmp/m2-localglobal-native-final.log`
exit 0 with required completion markers. The final combined run also passes
background binding, twenty pictures, 220 text measurements, fonts, driver/MDRV
exclusion, AGA pixels/palette/publication and all 75,616 A5 bytes. Geometry helper
sanitizer tests, startup checker tests, 71-script literal audit and both link
audits pass. See [gworld.md](gworld.md#background-point-conversion) for reproduction.

Next is QUICKDRAW / TESTDEVICEATTRIBUTE at Misc1+$0E3A. Counts remain 113
windows, 431 services and 62 original resource reads / 265,454 bytes. Fresh
preferences remain derived, and rendered intro acceptance is still pending.


## Drawing-device attributes

M2.3g12 is complete. The original bit-13 query reads the actual $B921 device
flags and returns a one-byte Boolean with unchanged padding. D0/D1 low words
and preserved upper words match the measured contract; D2–D7/A2–A6 and the
entire device record are unchanged. The implementation accepts bits 0–15 on
the registered main device and stops explicitly for unsupported inputs.

`tmp/m2-device-attribute-reference-final.log` and
`tmp/m2-device-attribute-native-final.log` exit 0 and pass the reference/native
checkers. The reference includes all sixteen flags with register/padding
sentinels; native acceptance exercises the original query. The same final run
passes both coordinate conversions, background binding, 220 text widths, twenty
pictures, fonts, driver/MDRV guard, AGA publication and all 75,616 A5 bytes.
Device inverse/layout sanitizer tests, startup checker tests, the 72-script Lua
audit and both link audits pass. See [gworld.md](gworld.md#drawing-device-attribute-query).

The next stop is QUICKDRAW / SECTRECT at Misc1+$0E90, before the device iterator
can finish. Counts remain 113 windows, 431 services and 62 original resource
reads / 265,454 bytes. Fresh-preference counts remain derived. Intro acceptance
is still pending.


## Drawing-device rectangle intersections

M2.3g13 is complete. Both original SectRect calls match the Mac: background and
game-window intersections, Boolean/padding, stack/register contract and guarded
destination bytes. Original instructions are unchanged. Fourteen additional Mac
fixtures cover empty/touching/inverted rectangles, signed extremes and aliasing.
All sixteen measured pairs pass the compiled helper under ASan/UBSan.

`tmp/m2-sectrect-reference-final.log` and `tmp/m2-sectrect-native-final.log`
exit 0 with required markers. The final combined native run passes device flags,
both background coordinate conversions, background binding, 220 text widths,
twenty pictures, installed fonts, driver/MDRV exclusion, AGA pixels/palette/VBI
publication and all 75,616 A5 bytes. The full host suite, 73-script MAME literal
audit and both clean-build link audits pass. The discovery observer overwrote
first-window captures on the second device-selection sequence; the final observer
preserves those captures and checks both intersections. Discovery is not acceptance.
See [rectangles.md](rectangles.md#sectrect) for the contract and reproduction.

Next is EVENT MANAGER / WAITNEXTEVENT at Engine+$44F0. Counts remain 113
windows, 431/431 services and 62 original resource reads / 265,454 bytes.
Fresh-preference counts remain derived. No rendered intro acceptance is claimed.


## Startup event polling

M2.3g14 is complete. WaitNextEvent now consumes actual pending window activation
and update state, with the measured EventRecord and Boolean/stack/register
contract. The current no-input route returns activation, game-window update,
background-window update and null. The reference also receives Finder's launch
event; the standalone Amiga launcher has no corresponding producer. The obsolete
Vette mouse-coordinate addition is removed because AitdScreen tracks global
coordinates. Sleep remains ignored by design; nonnil mouse-region wakeups stop.

`tmp/m2-event-reference.log` (eight original calls) and
`tmp/m2-event-native-final.log` (four original calls) both exit 0 and pass the
guarded event/ABI checker. The combined capture also passes all eight repeated
rectangle intersections, device flags, background coordinates/binding, 220 text
widths, twenty pictures, fonts, driver/MDRV exclusion, AGA publication and all
75,616 A5 bytes. The full host suite, 74-script Lua audit and both link audits
pass. Initial checker expectations covered only the two pre-event intersections;
the existing trace established four alternating background/game pairs, and the
checker now validates every pair and destination guard. No emulator rerun was
needed for that observer correction. See [events.md](events.md).

Next is QUICKDRAW / OBSCURECURSOR at Engine+$0FF6. Counts remain 113 windows,
431/431 services and 62 original resource reads / 265,454 bytes. The intro still
has not run; no rendered intro or cursor acceptance is claimed.


## Startup cursor obscuring

M2.3g15 is complete. Cursor state now separates explicit hide level from temporary
obscuring, with VBI mouse movement clearing only the latter. The original call
and repeated calls match the conditional D0 result and preserve stack, other
registers and the cursor image. The AGA pointer gate remains disabled.

`tmp/m2-cursor-reference-final.log` exits 0 and covers the original call, nine
Init/Hide/Show/Obscure fixtures, register sentinels and emulated ADB movement.
The compiled helper matches eleven measured states under ASan/UBSan and also
checks movement while explicitly hidden and hide-count overflow rejection.
`tmp/m2-cursor-native-acceptance.log` exits 0 and passes six original obscure
calls, nine event polls, twenty rectangle intersections, device flags,
background coordinates/binding, 220 text widths, twenty pictures, fonts,
driver/MDRV exclusion, AGA publication and all 75,616 A5 bytes. Full host tests,
updated driver/preference checker tests, the 75-script Lua audit and clean-build
link audits pass. See [cursor.md](cursor.md) for reproduction.

The earlier `native-final` run was rejected by the old fixed four-event assertion.
Its trace established the repeated idle route; the observer now validates every
call without fixing its timing-dependent count. No timeout is accepted.
Initial build attempts exposed the platform's injected integer types; the helper
now follows the repository's host-only stdint include convention.

Next is QUICKDRAW / GETFORECOLOR at Dan1+$623C. The original has performed two
additional resource reads: 115 windows, 433/433 services and 64 reads / 294,970
bytes. CODE mask is $3FBB; overlay counts remain 31/80,650 and preparation
64/81,222, with 244 resources and 58 low-memory patches. Fresh-preference counts
141/441 remain derived. No rendered cursor or intro acceptance is claimed.


## Selected-port colour getters

M2.3g16 is complete. The adjacent original GetForeColor/GetBackColor calls now
copy the selected owned colour port's six RGB bytes with the measured ABI.
Both native original calls preserve the full port and output guards. Four Mac
fixtures verify nontrivial component values. The final reference captures
InitGraf's actual pointer; the first probe's cached GWorld pointer was rejected.

`tmp/m2-getcolor-reference-final.log` and `tmp/m2-getcolor-native-final.log`
exit 0 and pass the colour checkers. The same native run passes cursor obscuring,
events, all repeated rectangle intersections, device flags, background
coordinates/binding, 220 text widths, twenty pictures, fonts, driver/MDRV
exclusion, AGA publication and all 75,616 A5 bytes. Full host tests, the
76-script Lua audit and both link audits pass. An interrupt reused one event
call's popped argument area; the corrected checker validates live return state,
not dead stack storage. See [gworld.md](gworld.md#selected-port-rgb-retrieval).

Next is COLOR QUICKDRAW / RGBFORECOLOR at Dan1+$624A: the existing setter supports
GWorlds, while this original call selects the game window. Counts remain 115
windows, 433/433 services and 64 resource reads / 294,970 bytes; CODE mask $3FBB.
Fresh-preference counts remain derived. No intro frame acceptance is claimed.


## Window RGB setters

M2.3g17 is complete. Window RGBForeColor/RGBBackColor use the main device's real
256-colour table, the measured inverse cube/collision builder and RGB16 matching.
The obsolete sixteen-entry main-device builder is removed. Its replacement uses
and releases private-zone scratch without an OS window, and caches by table seed.
Default pattern state is retained; unsupported nondefault window patterns stop.

`tmp/m2-window-rgb-reference.log` and `tmp/m2-window-rgb-native-final.log`
exit 0 and pass paired original setters, exact port changes, unchanged palette
and patterns, all defined inverse-table bytes and ABI checks. The existing
compiled builder/matcher matches the main table and all 66 reference RGB results
under ASan/UBSan. The final run also passes original offscreen setters, colour
getters, cursor state, events, rectangle intersections, device flags, background
coordinates/binding, 220 text widths, twenty pictures, fonts, driver/MDRV guard,
AGA publication and all 75,616 A5 bytes. Full host tests, the 77-script Lua audit
and both link audits pass. Reproduction is in
[gworld.md](gworld.md#window-rgb-updates-and-the-main-inverse-table).

Next is QUICKDRAW / PAINTRECT at Dan2+$0D52. Counts remain 115 windows,
433/433 services and 64 resource reads / 294,970 bytes, with CODE mask $3FBB.
Fresh-preference counts remain derived. Intro frame acceptance is still open.


## Window rectangle fill

M2.3g18 is complete. `tmp/m2-paintrect-reference-colors.log` and
`tmp/m2-paintrect-native-final.log` both exit 0. The production helper passes ten
complete-screen comparisons (three Mac, one native and six independent edge
cases); the original native call passes byte, ABI, guarded-record, palette and
surrounding-pixel checks. The combined run passes the existing colour, cursor,
event, geometry/binding, device, twenty-picture, 220-text-width, font and driver
checks. Both AGA frames publish with the correct eight planes and 256 colours;
all 75,616 A5 bytes match. Full host tests and both link audits pass, as do the
78-script Lua audit and updated endpoint-validator self-tests. Reproduction is
in [gworld.md](gworld.md#window-rectangle-filling).

The next named stop is COLOR QUICKDRAW / GETCTABLE, selector 129, Dark2+$1FDC.
Counts are 116 windows, 434 entered / 433 completed services (the stopped table
service is active), 65 resource reads / 297,034 bytes; CODE mask remains $3FBB.
Fresh-preference counts of 142 windows and 442/441 services remain derived.
The original MDRV is absent. Intro frame acceptance remains pending.


## Colour-table 129

M2.3g19 is complete. The Mac reference (`tmp/m2-ctable129-reference.log`) and
combined native run (`tmp/m2-ctable129-native-final.log`) exit 0 and pass the
original 2,064-byte table, flags, trailing bytes, generated seed, ownership,
handle-state and ABI checks. A separate original-table regression
(`tmp/m2-ctable129-original-table-regression.log`) exits 0 and preserves the
clut 128 GetCTable/mutation behavior. Full host tests, both link audits and the
79-script Lua audit pass. The combined capture passes rectangle fills, both
AGA publications, colour calls, events/cursor, geometry/device/binding, twenty
pictures, 220 text widths, fonts, driver/MDRV guard and all 75,616 A5 bytes.
See [color-table.md](color-table.md#colour-table-129-m).

The next stop is PALETTE MANAGER / NEWPALETTE, Dark2+$201C. Counts are 116 OS
windows, 434/434 services, 65 reads / 297,034 bytes, CODE mask $3FBB. The table
service now completes. Fresh-preference counts remain derived (142 windows,
442/442 services). Intro frame acceptance remains pending.


## Palette from colour-table 129

M2.3g20 is complete. The second constructor accepts the measured larger source
and uses the existing free ownership slot to assign its reusable identifier.
`tmp/m2-palette129-reference.log`, `tmp/m2-palette-serial-holes-reference.log`,
`tmp/m2-palette129-native-final.log` and the independent first-constructor
regression `tmp/m2-palette129-first-palette-regression.log` all exit 0 and pass.
Full palette/private/source bytes, ABI, sizes, ownership/disposal and identifier
reuse are checked. Full host tests, both link audits and the 81-script Lua audit
pass. The integrated capture also passes both table forms' reached state,
rectangle fills, AGA publication, colour calls, cursor/events, geometry/device/
binding, twenty preparation pictures, 220 text widths, fonts, driver/MDRV guard
and all 75,616 A5 bytes. See [palette.md](palette.md#palette-from-colour-table-129).

Next is PALETTE MANAGER / SETPALETTE, Dark2+$20CC. The original has additionally
loaded PICT 1500, MacPlay (small). Counts are 117 windows, 435/435 services,
66 reads / 313,392 bytes and CODE mask $3FBB. Fresh-preference counts remain
derived (143 windows, 443/443 services). Runtime discovery snapshots now include
resource counts to avoid inferring them when advancing the regression boundary.
Intro frame acceptance remains pending.


## Presentation palette binding

M2.3g21 is complete. The new front-window binding reuses Palette8 realization,
changes the association, retains the default palette and publishes new colours.
No Mac title bar is drawn. The original then clears the client white and reaches
QUICKDRAW / DRAWPICTURE at Dark2+$20F2. See
[palette.md](palette.md#presentation-palette-binding) for measured bytes and ABI.

Reference `tmp/m2-binding129-reference-final.log` and native
`tmp/m2-binding129-native-final.log` both terminate with exit zero and positive
acceptance markers. Full palette/private/CLUT and client comparisons pass,
including the following white fill and four complete AGA publications. Host
suite, sanitizer helper comparison, link audits and the 82-script MAME literal
audit pass. Integrated regressions pass both colour-table forms, constructor,
rectangle fills, RGB getters/setters, events/cursor, geometry/device/world
binding, twenty preparation pictures, 220 text widths, fonts, original-MDRV
exclusion and all 75,616 A5 bytes. Counts remain 117 windows, 435/435 services,
66 reads / 313,392 bytes and CODE mask $3FBB. Intro acceptance remains pending.


## MacPlay window picture

M2.3g22 is complete. The existing Vette-derived indexed renderer now supports
owned eight-bit screen windows, their main-device colour matching, rectangular
clipping and translated dirty bounds. Original Dark2+$20F2 preserves all caller
registers and draws PICT 1500 at (4,32)–(196,288). Full-buffer and paired client/
CLUT comparisons pass, including all untouched pixels. The fifth AGA frame
contains the picture; the sixth contains the later original black clear.
See [picture-drawing.md](picture-drawing.md#presentation-window-picture).

Both reference and integrated native runs exit zero. The full native transcript
is `tmp/m2-presentpicture-native-complete.log` (the wrapper tail is insufficient).
Host tests, no-float/probe link audits and the 83-script MAME literal audit pass.
Integrated regressions pass twenty offscreen pictures, 220 text widths, colour
getters/setters, palette construction/binding, table loading, rectangle fills,
geometry/device/world state, fonts, 398 event calls, cursor state, MDRV exclusion
and all 75,616 A5 bytes. Startup stops at SetPalette, Dark2+$214C: 117 windows,
435/435 services, 66 reads / 313,392 bytes, CODE mask $3FBB. The next item measures
palette restoration. Full intro and owner-deferred rendered video remain open.


## Restore the default palette after MacPlay

M2.3g23 is complete. The measured restore uses the existing realization helper
with explicitly validated $800A entry state, updates the incoming private seed,
deactivates the outgoing palette and rebinds the default. Client pixels and
both palette records except that outgoing state word remain unchanged. No Mac
chrome is drawn. See [palette.md](palette.md#presentation-palette-restoration).

Reference `tmp/m2-restorepalette-reference-next.log` and native
`tmp/m2-restorepalette-native-final.log` terminate with exit zero. Full paired
palette/private/CLUT/client and ABI checks pass. Seventh-frame palette-only AGA
publication and the eighth frame at the next stop match the reference. Host
suite, sanitizer comparisons, clean-build no-float/probe audits and the 84-script
MAME literal audit pass. Integrated picture, palette, table, fill, RGB, event,
cursor, geometry, device/world, font, text and A5 checks all pass; original MDRV
remains absent. The observer skips the already-verified repeated event loop
between picture publication and restoration, retaining the initial nine calls.

Next is QUICKDRAW / COPYBITS, Misc2+$24D2. Counts are 128 windows, 463/463
services, 68 reads / 333,998 bytes, CODE mask $3FFB. Fresh-preference counts
remain derived (154 windows, 471/471 services). Full intro acceptance is open.


## First intro CopyBits and Infogrames logo

M2.3g24 is complete. The byte copy preserves indices for the measured equal-seed
colour environments, using Vette's clipping rules with owned buffers and exact
dirty bounds. The entire destination and meaningful source pixels match the Mac;
source row padding is unchanged on each platform. See [copybits.md](copybits.md).

Reference `tmp/m2-copybits8-reference.log` and native
`tmp/m2-copybits8-native-final.log` exit zero. The ninth AGA publication matches
the Infogrames logo, including all planes and colours. Host suite, helper
sanitizers, clean-build no-float/probe audits and 85-script literal audit pass.
Integrated palette/restoration/picture/AGA, table, fill, RGB, font/text, geometry,
device/world, event/cursor and 75,616-byte A5 checks pass; the run observed 612
event calls. Original MDRV remains absent.

Next is native SOUND DRIVER / SELECTOR 22, Core+$1A74. Counts: 128 windows,
68 reads / 333,998 bytes, CODE mask $3FFB. Services are 464 entered / 463
completed with one known $A0F8 call in progress. Fresh-preference counts remain
derived (154 windows, 472/471 services). This stop does not claim service
completion. Full M2 intro and rendered-window acceptance remain open.


## Native effect-stop selector 22

M2.3g25 is complete. Original call/entry/dispatch/body bytes and the full
12,360-byte driver-state transitions establish the stop-effects contract.
The real route is already inactive; an isolated original CPU fixture changes
only the effect flags (and its unused following slot). Native state tests
exercise logical active effects, preserve song/sample/configuration state and
reject assigned physical channels loudly. M4.3 explicitly retains that DMA
stop acceptance. See [sound-driver.md](sound-driver.md#selector-22-stop-effects).

Reference `tmp/m2-driver22-reference.log` and integrated native
`tmp/m2-driver22-native-final.log` exit zero with positive call/return controls.
Native selector 22 is the third completed driver call. Host/sanitizer suite,
clean-build no-float/probe audits, 86-script MAME literal audit, and integrated
logo/CopyBits, picture/palette/AGA, table/fill/RGB, event/cursor, font/text,
geometry/device/world and all 75,616 A5-byte checks pass. The ninth AGA frame
still matches Infogrames. Original MDRV remains absent; the reached stop-effects
call generates no audio event because the effects were inactive.

Next is SOUND DRIVER / SELECTOR 17, Core+$17FC: 135 windows, 480/479 services
with one known driver call in progress, 68 reads / 333,998 bytes, CODE mask
$3FFB. Fresh-preference counts remain derived (161 windows, 488/487 services).
The measured effects playback dependency is next; full M2 remains open.


## Native one-shot effect playback

M2.3g26 is complete. Original selector 17 at Core+$17FC requests 30,783 unsigned
PCM bytes at 8 kHz, no loop, identifier $8000. Full original state/ABI, natural
completion and the entire native sample/converted DMA buffer match their
contracts. The loop-counter pointer is unused on this one-shot route.
Vette's Paula protocol plays period 443, volume 64, with odd-byte padding and
a silent reload. The owned 30,786-byte chip buffer is released only after
quiescing DMA; natural completion and selector 22 share that cleanup.
See [sound-driver.md](sound-driver.md#selector-17-raw-one-shot-effects).

Reference `tmp/m2-driver17-reference-complete.log` and native
`tmp/m2-driver17-native-return-probe.log` both exit zero with positive markers.
Native DMA changes $3F1→$3F0, active/channel become 0/-1, allocation becomes
zero after 232 ticks (231-tick playback plus one VBI-phase allowance). The
host suite, 87-script MAME literal audit, clean no-float/probe link audits and
24 integrated checks pass, including exact effect PCM, nine AGA publications,
logo/CopyBits, pictures/palettes, text/events, geometry/device state and all
75,616 A5 bytes. MDRV remains absent. No rendered-window acceptance is claimed.

Next is SOUND DRIVER / SELECTOR 20, Core+$17C8: 135 windows, 481/480 services
with the known status query in progress, 68 resource reads / 333,998 bytes,
CODE mask $3FFB. Fresh-preference counts remain derived (161, 489/488).
Loops, fractional rates, oversized samples and occupied-voice selection retain
named stops, tracked in M4.3a. Full M2 remains open.


## Effect-status completion and first intro buffer fill

M2.3g27 is complete. Selector 20 returns the first matching identifier's actual
playback state. Original active, completed, stopped-state, missing and duplicate
ID cases pass. Native `tmp/m2-lineto-native-accept.log` (exit zero) observes
199 active query returns followed by the original game's completed query,
with preserved ABI and natural DMA/sample cleanup after 232 ticks. The full
sequence checker passes against `tmp/m2-driver20-reference.log` (exit zero).
No test forces the completed state. See [sound driver](sound-driver.md#selector-20-effect-status).

M2.3g27a is complete: Dark2+$1E44 fills the top 320×140 of the owned GWorld.
Both complete buffers match the expected fill/preservation, and all 648×401
pixel columns match between systems. Port, CLUT, regions and rectangle guards
are preserved. `tmp/m2-paintworld-reference.log` (exit zero) and the same native
run pass the fill check using the existing solid-fill helper. See
[colour drawing](color-drawing.md).

These checks are included in the 27 integrated regressions at the LineTo
checkpoint below. The former 23-query active prefix did not satisfy final
completion acceptance; the 200-query integrated sequence now does.


## Intro line drawing

M2.3g28 is complete. The reached solid one-pixel LineTo at Dark3+$337E
matches the original whole buffer, CLUT, pen-position update and preserved
register/stack contract. Forty-eight original slope/clipping fixtures and five
host buffer cases also pass; see [colour drawing](color-drawing.md).

The instruction/register trace followed two rejected raster hypotheses and
established the Mac's fixed-point edge rule. Reference
`tmp/m2-lineto-registers-reference.log` and integrated native
`tmp/m2-lineto-native-accept.log` exit zero with positive markers. The host
suite, clean no-float/82-symbol probe audits, 90-script MAME literal audit and
27 integrated checks pass, including the full effect-status sequence, exact
PCM/cleanup, offscreen fill, nine startup AGA publications, logo/palette/picture,
text/events, geometry/device state and all 75,616 A5 bytes. The native line
has zero paired pixel mismatches across 648×401.

The new boundary is QUICKDRAW / PAINTRECT, $A8A2, Dan2+$0D52: 139 windows,
689/689 services (baseline 489 plus 200 status queries), none active,
68 resource reads / 333,998 bytes, CODE mask $3FFB, MDRV absent. Fresh-pref
expectations remain derived: 165 windows, baseline 497 plus status queries.
The earlier discovery run reached 115 display publications; only the nine
startup publications have paired AGA acceptance so far.

One observer run (`tmp/m2-lineto-native-final.log`, exit 1) was rejected:
its relocated AGA checkpoint saw eight publications instead of nine. Moving
that observer to the measured first-LineTo state fixed the check without a
runtime change. Repeated cursor observations after the completed sound query
are no longer needed by the startup observer. Full M2 remains open.


## Later intro fill and explicit text boundary

M2.3g29 is complete. The original mode-0 fill at Dan2+$0D52 reuses the
solid eight-bit fill helper. Paired complete buffers/CLUT, 512 covered pixels
(430 changed), surrounding storage, port and ABI checks pass. The matching
state is documented in [colour drawing](color-drawing.md).

The first onward run, `tmp/m2-paintlater-native-discover.log`, timed out
(status 124) and is rejected. Its interrupt snapshot found the Line-A
zero-return loop. A bounded read-only breakpoint at that loop
(`tmp/m2-paintlater-zero-diagnose.log`, exit zero) identified actual DrawText
$A885 at Dan1+$0346; original bytes at +$0342 are `548f3e80a885`.
The disabled-text guard now branches to the existing named-stop report instead
of returning zero. No text rendering or guessed success was introduced.

Original `tmp/m2-paintlater-reference-mode.log` and final native
`tmp/m2-paintlater-native-accept.log` exit zero. Twenty-eight integrated checks
pass: the new fill, prior fill/line/picture/palette/AGA checks, original effect
PCM and real completion, font metrics, events, geometry/device state and all
75,616 A5 bytes. Existing fill-helper host cases, the 91-script MAME literal
audit, no-float/82-symbol probe audits and updated endpoint self-tests also pass.

The fill checkpoint ended at QUICKDRAW / DRAWTEXT, Dan1+$0346, 139 windows,
690/690 services (baseline 490 plus 200 status queries), none active,
68 resource reads / 333,998 bytes, CODE mask $3FFB, original MDRV absent.
Fresh-pref counts remain derived: 165 windows and baseline 498 plus queries.
The selected text state has font 20, size 14, plain face and text mode 1.
Full intro, rendered-window acceptance and M2 remain open.


## Intro copyright text

M2.3g30 is complete. The reached DrawText uses the installed owned font,
measured fractional advances and rectangular clipping. ©/• now have owned
artwork. The obsolete packed four-bit text renderer is removed. No Mac dialog
or menu is drawn. [Font Manager](font-manager.md#intro-drawtext) records the
original string, pen/ABI, pixel bounds and intentional D6 glyph differences.

Original `tmp/m2-drawtext-fixtures-reference.log` exits zero and establishes
natural/repeated text, MoveTo fraction reset and empty-text behavior. Final
native `tmp/m2-drawtext-native-accept.log` exits zero, passes the strict endpoint
and proves the actual DrawText ABI, pen and selected state. Full output bytes
match the independent owned-glyph stencil; visible input columns and CLUT match
the Mac. Allocator row padding differs initially but is preserved independently.
Logical-buffer crops were inspected for coarse placeholder lettering and placement;
this does not replace owner-deferred rendered-window acceptance.

The first discovery run completed normally and passed text, but its audio
observer counted 199 of 201 status queries. It is rejected for full regression
acceptance. Added counter checkpoints show no queries lost across the fill/line
captures in the final run, which observes all 201 queries (200 active, one done)
and natural sample/DMA cleanup after 233 ticks. No acceptance check was relaxed.

The final host suite, 28 integrated regression checks plus DrawText, 92-script
MAME literal audit and no-float/82-symbol probe audits pass. Current boundary:
QUICKDRAW / COPYBITS, Dark+$1DBC, 139 windows, 692/692 services (baseline 491
plus 201 effect-status queries), none active; 68 application resource reads /
333,998 bytes, overlay 31 / 81,214, preparation 64 / 81,786, CODE mask $3FFB,
original MDRV absent. Fresh-pref counts remain derived: 165 windows and baseline
499 plus queries. The owned overlay is 82,026 bytes. Full intro and M2 remain open.


## Title-screen colour copy

M2.3g31 is complete. Dark+$1DBC's srcCopy now remaps different colour seeds
through the existing measured inverse table, preserving the identical-seed
path and existing clipping. [CopyBits](copybits.md#copyright-presentation-colour-mapping)
records original bytes, complete buffers, ABI and D6 pixel differences.

The final native `tmp/m2-copylate-native-callback-safe.log` and original
`tmp/m2-copylate-reference.log` exit zero. The title copy, prior DrawText and
28 earlier integrated checks pass, including the first effect's real completion,
line/fills, logo/palettes, nine AGA publications and all 75,616 initial A5 bytes.
The full host suite, 122 direct/remapped clipping fixtures, 93-script MAME literal
audit, no-float/82-symbol link audits and endpoint/query-accounting rejection
checks pass. Logical client images were inspected; rendered-window acceptance
remains owner-deferred.

Rejected observations are retained locally: the broad conditional discovery
observer timed out before the target; an integrated run hit a GDB “Invalid hex
digit 79” condition error; later runs exposed obsolete endpoint and audio-observer
assumptions. These are not accepted runs. The fill observer now stops at the
original instruction and checks its opcode before entering the dispatcher.
Audio observers match both the original caller return and stack position: a
permitted user-mode VBL callback can enter the shared driver stub first.
Queries during callback/probe intervals are explicitly counted; missing or
inconsistent totals fail. First-effect cleanup checks now run at that completion
point, because the intro subsequently starts a second effect.

A separate bounded post-copy trace (`tmp/m2-copylate-services.log`, exit zero)
explains the variable endpoint count: 64 non-audio services, two non-query driver
calls and additional status queries follow the copy. Six data-file opens and
closes are observed; original PAK payload acceptance remains M2.1c. The constant
service baseline is 557 entered / 556 completed, plus **all** effect-status
queries, including those after the first sound. Fresh-pref baseline 565/564 and
185 windows remain derived, not fresh-start acceptance.

Current boundary: DrawText Dan1+$0346, font 20/plain/14, mode 1, pen (v86,h129),
8 bytes `49fa4d6f74696f6e` (“I˙Motion”). The unowned $FA glyph stops before
rendering. Final counts: 159 windows, 802/801 services with this one active,
245 total status queries; the first effect has 199 observed queries and zero
additional scoped queries in this accepted run. A second effect is active
(starts 2, stops 1, channel 0, 10,202 allocated sample bytes). Resource counts
remain 68 application reads / 333,998 bytes, overlay 31 / 81,214, preparation
64 / 81,786, CODE mask $3FFB, original MDRV absent. M2 remains open.


## Credits spacing and owned dot-above

M2.3g32 is complete. Times/plain/14 GetFontInfo now supplies the measured
12/4/15/0 layout metrics, independently of placeholder bitmap geometry.
The original's line spacing is therefore 16 instead of 14, correcting a
12-pixel baseline error on “I˙Motion”. The owned NFNT includes its dot-above
character; unsupported artwork remains a loud stop. Original instructions
are unchanged. [Font Manager](font-manager.md#credits-line-spacing-and-dot-above)
records bytes, state, fractional pen, ABI and D6 differences.

`tmp/m2-dottext-reference-final.log` (maintained Mac probe with
`AITD_DOT_TEXT=1`) and `tmp/m2-dottext-native-final.log` both exit zero with
positive completion. All 31 integrated checks pass, including both text calls,
title copy, first-effect cleanup, fills/line/logo/palettes, nine AGA publications
and initial A5 bytes. The full host suite, changed-checker selftests, 93-script
MAME literal audit and clean 68020 no-float/82-symbol link audits pass.
Logical credits crops were inspected; rendered-window acceptance is still
owner-deferred. The discovery native run returned the correct text but failed
its obsolete endpoint assertion; it is not an accepted regression run.

After the dot-above DrawText, the accepted observer records nine non-query
services (three each TextWidth, GetResource and DrawText) plus 16 sound-status
queries. No system windows are added. The fixed endpoint baseline is now
566 entered/completed, plus all status queries; fresh-pref 574/574 and 185
windows are derived, not fresh-start acceptance.

Current boundary: LineTo Dan2+$0B5A, 159 windows, 828/828 services, none active,
262 total status queries. The first effect has 201 observed queries and no
additional scoped queries; cleanup completes after 232 ticks. The second effect
is active (starts 2, stops 1, channel 0, 10,202 allocated sample bytes).
The game-window pen (v0,h260) requests (v200,h260), size 1×1, mode 8, fore 16.
Application resources remain 68 reads / 333,998 bytes; overlay 31 / 82,238,
preparation 64 / 82,810, CODE mask $3FFB, original MDRV absent. The owned
font grows by 1,024 bytes; the overlay is 83,050 bytes. M2 remains open.


## Intro game-window lines

M2.3g33 is complete. The visible colour-window adapter reuses the verified
Line8 raster, reports its exact clipped footprint and queues native dirty bounds
through the window PixMap origin. It preserves the offscreen path and rejects
unsupported window/pattern/region states. [Colour drawing](color-drawing.md#game-window-lineto-m23g33)
records the original bytes, complete screen/port contracts and publication.

`tmp/m2-windowline-reference.log`, `tmp/m2-windowline-native-progress.log`
and `tmp/m2-windowline-native-final.log` exit zero with positive completion.
The focused progression run records 112 window lines and 848 publications before
the next stop. The final full run passes all 32 integrated comparisons: the new
window line and AGA publication, both credits text captures, title copy, earlier
line/fills, first-effect completion, logo/palettes, early AGA publications and
all initial A5 bytes. The host suite, three added translated-window/dirty-bound
fixtures, all 48 original slope fixtures, changed-checker selftests, 93-script
MAME literal audit and clean 68020 no-float/82-symbol probe audits pass.

The first native discovery run captured a valid line but expired later in
Planar8 conversion at 240 seconds; it is rejected. The following instrumented
run demonstrates advancing line/frame counters and reaches a named stop normally.
No performance change or game timing change was made. The first line changes
exactly 200 pixels and dirties global (150,420,350,421). Published frame 117
matches that complete framebuffer, with identical queued/active bitplanes and
copper and VBI line zero. Both full input screens equal the preceding title
captures, including their documented Mac-desktop/placeholder differences.

## Accented intro credit and original intro return

M2.3g34 is complete. MacRoman $89 now has owned circumflex-A artwork; the
original `5961896c` (“Yaâl”) bytes and all spacing remain unchanged. The paired
contract and explained placeholder pixels are in [Font Manager](font-manager.md#accented-a-credit-glyph-m23g34).

`tmp/m2-accenttext-reference.log` and `tmp/m2-accenttext-isolated-native.log`
exit zero with positive completion. The native run returns from the original
intro at Dark+$5220 with D0 zero after 5,606 frames. Its next named stop is
CopyBits $A8EC at Dan2+$07FA (M2.3g35). All 33 integrated checks pass in
`tmp/m2-accenttext-regressions.log`: the accented/copyright/dot-above text,
window-line/AGA publication, title colour mapping, fills/lines, first-effect
completion, logo/palettes, earlier publications and all 75,616 A5 bytes. The
full host suite and clean no-float/82-probe build passed for the glyph change;
changed-checker selftests, Python syntax and the 93-script MAME audit pass.

The final capture records 159 system windows, 2,558/2,558 services, none active,
and 1,310 status queries: fixed service baseline 1,248/1,248. The derived fresh
baseline is 1,256/1,256 with 185 windows; this is not fresh-start acceptance.
All sixteen effects have started and stopped, with channel -1 and zero sample
allocation. Driver calls are status queries plus 34. The final publication is
5,607/5,607. Application/overlay counts remain 68 / 333,998 and 31 / 82,238,
preparation 64 / 82,810, CODE mask $3FFB, 58 low-memory sites, 244 resource
records and original MDRV absent.

A 1,200-second timeout, a stale text-only endpoint dump and two interrupted
connections are rejected. M2.3g34a fixes the shared debugger-port collision;
only the isolated normal-completion capture supplies final acceptance. The
legacy standalone AGA observers have stale publication assumptions; M2.10a
records that gap. The integrated frame-9 and window-line frame-117 publication
checks pass. Full intro frame comparison and rendered-window acceptance remain
open; this is not completion of M2.


## Post-intro offscreen CopyBits

M2.3g35 extends the existing owned eight-bit copy adapter to a locked offscreen
destination, using its own colour table/inverse and storage bounds. The original
20×8 call and its exact preservation/ABI contract are in [copybits.md](copybits.md).
There is no new blitter, font substitution or game-code patch. Other unsupported
transfer forms remain loud stops.

`tmp/m2-postcopy-reference.log` and `tmp/m2-postcopy-native.log` both exit zero.
Every defined destination pixel matches the original; full buffers obey the
independent copy/preservation model. All drawn atlas pixels match, while
unpainted allocation bytes and row padding are proved untouched. Native screen
dirty state stays clear and queued/presented counters stay 5,554/5,554 across
this offscreen call. The original startup intro returns D0=0 at Dark+$5220,
with 5,553 frames and 47,451 ticks on the temporary fast A4000/68020 model.
Frame totals differ from the cycle-exact A1200 run; this is state-pair service
evidence, not the pending fixed-seed full-intro acceptance (M2.10).

Execution advances to GetKeys $A976 at Dan1+$583A. The capture reports 194
system windows and 2,721/2,721 completed services, none active, including 1,367
effect-status queries: fixed baseline 1,354/1,354. The derived fresh baseline
is 1,362/1,362 with 220 windows; fresh-start acceptance is still M2.4. All 16
effects have stopped, no sample/channel allocation remains, and original MDRV
is absent. Final publication is 5,556/5,556. The other ledgers remain 68 reads /
333,998 application bytes, 31 / 82,238 overlay bytes, 64 / 82,810 preparation
bytes, 58 low-memory sites, CODE mask $3FFB and 244 resource records.

The full host suite, no-float/82-probe build audits and all 34 integrated
comparisons pass. Changed checker selftests and the 94-script MAME literal
audit pass. The earlier input-only fast capture is rejected: GDB reported
“Cannot execute this command while the target is running,” returned zero and
produced no dump. Only the complete integrated run supplies native acceptance.
The existing standalone AGA observer limitations remain tracked in M2.10a.


## Original GetKeys polling

M2.3g36 implements the original Dan1+$583A call using the current native raw-key
levels and the existing Mac virtual-key translation. This follows Vette's
polling-map approach, independent of queued key events. Aliases such as both
Shift keys are combined. [events.md](events.md) records the measured ABI and
map layout; original game instructions are unchanged.

The original MAME capture `tmp/m2-getkeys-reference.log` exits zero with released,
held A and released A maps. The native `tmp/m2-getkeys-window-core-final.log`
exits zero with eleven guarded key snapshots, ten preserved queued transitions,
and the existing window/file/clock/Paula checks. The production build passes
no-float and 82-probe audits; the host suite, 95-script MAME literal audit and
checker rejection cases pass.

`tmp/m2-getkeys-native.log` exits zero and all 35 integrated comparisons pass,
including the original GetKeys caller, stack, D0.w, preserved registers and
exact guarded output. The startup intro returns D0=0 with 5,563 frames and
47,371 ticks on the temporary A4000/68020 model. Publication ends at 5,566/5,566.
The next stop is native sound-driver selector 13, Core+$137E, argument zero.
That user-mode service is explicitly pending: 2,750 entered / 2,749 completed,
active=1, including 1,363 completed effect-status queries. The fixed baseline
is 1,387/1,386 with 210 system windows. The derived fresh baseline is
1,395/1,394 with 236 windows, still awaiting M2.4 acceptance.

All sixteen effects have stopped and no sample/channel allocation remains.
Driver calls are queries plus 35. Original MDRV remains absent. Application
resource reads advance to 70 / 349,400 bytes; overlay remains 31 / 82,238 and
preparation 64 / 82,810, with 244 resource records, CODE mask $3FFB and 58
low-memory patches. These are resource reads, not M2.1c PAK payload acceptance.
The pending selector is M2.3g37. Full intro-frame and rendered-window acceptance
remain open; the standalone AGA observer limitations remain M2.10a.


## Original sound-driver control word

M2.3g37 adds selector 13’s measured low-word setter. The actual zero argument
and the independent original-CPU $12345678 fixture pass exact full-state and
ABI checks in `tmp/m2-driver13-reference.log` (exit zero). The native model
retains the word without starting a voice; unsupported music calls remain stops.
See [sound-driver.md](sound-driver.md).

The clean 68020 production build passes no-float and 82-symbol audits. All host
tests, 96-script MAME literal audit, checker rejection fixtures and all 36
integrated comparisons pass. `tmp/m2-driver13-native-full.log` preserves the
complete raw debugger output of the exit-zero run; the runner’s displayed
`tmp/m2-driver13-native.log` was limited to its final 3,000 lines. Future full
intro observations should retain the complete output for early-startup checks.

Original intro return is D0=0 at 5,572 frames / 47,493 ticks; the final publication
is 5,575/5,575. The native driver returns from selector 13 and reaches selector 0,
argument $87, at Core+$138C. Counts are 210 system windows and 2,754/2,753 services,
including 1,366 completed effect-status queries and the explicit pending service.
The fixed existing-prefs baseline is 1,388/1,387; fresh 1,396/1,395 and 236 windows
remain derived expectations awaiting M2.4. Driver calls are queries plus 36.
All sixteen effects are stopped with no allocated sample/channel. Resource reads
remain 70/349,400 application bytes, 31/82,238 overlay bytes and 64/82,810
preparation bytes. The 244 records, 58 low-memory patches and CODE mask $3FFB
remain unchanged. MDRV is absent. Rendered acceptance and M2.10a remain pending.
