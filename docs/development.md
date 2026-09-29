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

`stage_original_data.sh` copies the original application folder into `data/`
beneath the executable directory on the emulated hard drive. The port executable
and diagnostic files remain outside this Mac-visible namespace. Override
`AITD_APP_RSRC` and `AITD_DATA_DIR` for extraction locations; the three original
root files and companions must be beside `AITD_APP_RSRC`. Saves and preferences
retain their separate `Saved Games/` and `prefs/` native mappings.

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
whole-fork disk buffering remains the explicitly queued M2.2 replacement.
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
coherence and volume-name/reference forms. It requires 345 runtime windows,
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
is included in the current 345-window regression. The dedicated application directory also supports indexed queries; System/root
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
`6173b910b6b572a00bfef3ca40b7e738112ef7a1f533c90c4bc549a200696e69`, and
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
contains 42 entries and still performs zero runtime windows during original
directory initialization. Current File-write totals include the later OpenDF fixture below.

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
The current file-write totals are 345 windows, 33 reads / 866,733 bytes, and
24 writes / 470,069 bytes with 18 flushes including shutdown. All owned scratch
forks/companions must be absent afterward; the restored stream ledger is empty.
File-read, window-core, production boot and the 42-entry original directory
observer remain required. Original game PAK reads remain separate acceptance.
