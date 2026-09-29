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
