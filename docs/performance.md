# Performance measurement

Use fixed-clock `a1200-020` or `a4000-030-reference`, with CPU/video/memory settings
recorded. Measure guest ticks/fields and completed frames; host wall time measures
emulator throughput. Warp speeds up a diagnostic without being a game benchmark. The
[intro reference](intro-comparison.md) has matched car, frog, walking and transition
results. The following profiles describe retained measurement builds, not universal
frame-rate guarantees.

## Fight-frame service costs

The pinned 15.6672 MHz reference 68030/PAL monster fight records 319 completed
frames and 3,403 fields (`frame4-due-services`). A repeat (`frame4-due-services-repeat`)
reproduces the full frame/state trace, phase counts and dispatch cost exactly.
Its full-phase instruction-PC
profile averages **213.71 ms per frame**, including transitions and required
callbacks. Selected exclusive costs are:

| Work | ms/frame |
| --- | ---: |
| Original Macintosh instructions | 128.59 |
| Trap entry and dispatch (conservative) | 16.56 |
| CopyBits | 13.72 |
| C2P | 13.00 |
| Port state lookups | 5.03 |
| Fills, lines and regions | 3.77 |
| RGB lookup and quick dispatch | 2.19 |
| Particle rectangles and quick dispatch | 1.86 |

Use the full-phase PC bucket for the dispatch budget. CPU exception entry is
currently charged to the first native handler instruction, inflating that
instruction's count and apparent cost (MEASURE.2). The dispatch total includes
that entry cost; do not treat it all as removable register-save work. The
subtree-adjusted report supplies only a **total** estimate, with `buckets: null`
and an explicit unavailable status in JSON. The profile format does not associate
instruction PCs with call-tree nodes, so it cannot recover a faithful category
breakdown after excluding subtrees. Tail jumps and native exception handlers make
classification by node entry target misleading. Full-phase PC buckets include the
excluded work and must not be substituted for adjusted categories. Different builds
can take different intermediate combat routes: these
averages do not establish a matched-state FPS improvement or a hardware result.

FRAME.4's owner-accepted dispatch result is **14.40 ms per fight frame**, down
from the corrected **16.56 ms** baseline. This includes CPU exception entry,
return and guards moved into drawing wrappers; service bodies remain separate.
The `frame4-irq-certificate` profile and its repeat both measure 14.3950108 ms,
with byte-identical frame/state traces (328 fight frames, 3,438 fields). The full
frame average is 209.99 ms; different intermediate combat routes prevent a
matched-state total-frame speedup claim. Quick-trap register/CCR/ABI, frame-pacing
and Apple Event startup checks pass. Callback latency remains bounded at three
Mac ticks on the reference machine. The independent scene verifier and normal
audio/memory circuit both complete ten active gameplay minutes without dropped
input, scene failures, allocation errors or late music notes.

A successful service check is reused within a Mac tick. VBI tick advancement,
service-state mutations and asynchronous song errors invalidate it. Publication
rechecks the tick and song error so an interrupt during validation cannot leave
an obsolete result cached. Frame-owner and stack checks still run for every call.

Zero-byte assembly guard/body labels separate dispatch from drawing without
changing executable bytes. The baseline was re-symbolized with a byte-identical
measurement build: guards and C argument marshalling count as dispatch, while
pen-state and standalone service bodies do not. Mixed C functions still contain
some service work, making this a conservative dispatch bound. Old profile ELFs
without the boundary symbols retain coarse buckets.

## RGB lookup and dispatch

Per-port memoization removes almost all inverse-table searches. A guarded assembly
entry avoids repeated services when none are due, while the original matcher remains
the fallback. Cache storage is 33,120 native bytes across sixteen port slots. Current
whole-trap RGBForeColor cost is about **85.7 µs per call**, including required callbacks.
See [development](development.md#rgb-colour-lookup) and
[testing](testing.md#rgb-lookup-memoization) for the exact-byte/ABI checks.

## Solid particle pens

Direct clipped pen rectangles and a guarded assembly entry avoid generic rectangle
setup. Pixel capacity is refreshed with heap-derived GWorld views. Ordinary thin
Line/LineTo strokes retain the original rasterizer and remain a separate workload.
No framebuffer comparisons, pacing changes or game-code replacements are involved.
See [implementation](development.md#solid-particle-pens) and
[validation](testing.md#particle-rectangles).

## Actor-mask copies

Exact-byte region validation uses 32 entries within 32 KiB. Early mask-bound rejection,
cached GWorld lookup, smaller copy setup and guarded dispatch reduce repeated work.
Full malformed-stream validation still precedes pixel writes. Larger unmasked copies
remain a separate workload. See [implementation](development.md#actor-mask-copies)
and [validation](testing.md#copybits-masks).

## Large BlockMove copies

The reference-68030 `frame5-final` monster profile records **3.38 ms per fight
frame** in all BlockMove trap subtrees (dispatch and required services included),
versus **4.23 ms** in `frame4-irq-certificate`. Copy-adapter subtrees alone take
3.04 versus 3.86 ms. The large `(Dark, $1B7A)` caller takes 2.76 versus 3.37 ms
per frame, averaging 24.3 versus 29.1 ms per call. Its observed buffers are
longword aligned, with 261,452-byte copies; the earlier queue estimate of
1.15 ms per call was incorrect.

The encounters contain 352/328 fight frames and 40/38 large calls respectively;
these are workload averages, not a matched-state total-FPS claim. An isolated
same-buffer test confirms the throughput improvement: four aligned 260,480-byte
copies take 375,494 beam units with the 128-byte loop versus 453,083 with the
single-longword loop (17% less). Both use the same pinned CPU/cache policy.

The retained loop uses 32 `MOVE.L` instructions per iteration, with exact
backwards overlap and small tails. A 32-byte `MOVEM` candidate and a C-wrapped
unrolled candidate did not improve the encounter and were discarded. Most
remaining cost is in the actual data-movement instructions. The owner accepted
this verified improvement in place of the original 2 ms per-frame gate, which
was not met. `MOVE16` is unavailable on the reference 68030; a CPU-specific
040/060 path would require separate validation. The executable continues to
preserve OS/WHDLoad cache ownership.

All 28,388 [copy checks](testing.md#blockmove-copies) pass on both the host
(ASan/UBSan) and native 68030. The bounded monster run completes through death;
production no-float/probe audits pass. Zero-byte copies now also avoid the old
odd-address count underflow. No endurance circuit was needed.

## Effect preparation and polling

Fresh reference-68030/PAL monster profiles `frame6-before` and `frame6-after`
measure **1.50 → 0.52 ms per fight frame** in the union of effect start,
polling and stop subtrees, including their DMA waits. This meets the 1 ms gate.
Starts alone fall from 1.37 to 0.39 ms; polling stays at 0.13 ms. The older
5 ms queue estimate is superseded. Shared `waitPaulaDmaLines` also serves music:
its music calls are outside this effect budget, and nested waits are not counted
twice. Effect-owned waits measure 0.071/0.073 ms per frame.

Both runs use `MONSTERPROFILE=1 FIXEDRNG=1`, deterministic execution, the pinned
15.6672 MHz 68030 and unchanged OS cache policy. They complete through death
without intermediate debugger stops. Before/after contain 352/342 fight frames,
35/37 effect starts and 3,512/3,505 fields. The changed intermediate trajectory
precludes a matched-state whole-game FPS claim; these are effect workload costs.

[Converted PCM reuse](development.md#converted-effect-samples) removes repeated
Chip allocation/conversion without changing sample bytes, pitch, priority or
playback deadlines. The slot fixture checks shared buffers, same-address source
mutation while the old sample remains active, and complete cache release. Host
checks cover odd/aligned sources, byte tails, pinning, eviction, the memory cap
and allocation failure. All seven loop/long/stop/replacement cases and the
fractional-pitch/attack/silent-reload DMA fixture pass against retained Mac
references. SONG 136 passes all 602 timed events, independent channel allocation,
trapless interrupt progress, effect priority and cleanup. The observer's shared
selector-17 reader now accepts helper markers without an exception-frame local.
Physical Amiga performance remains deferred.

### Fight C2P coverage

The reference-68030/PAL profiles `frame7-before` and `frame7-final` measure
**13.25 → 10.91 ms of C2P per fight frame** (17.7% less). Inclusive
`presentMacFrame`, including planning and back-buffer synchronization, measures
**15.33 → 12.70 ms/frame**. Both use `MONSTERPROFILE=1 FIXEDRNG=1`, deterministic
execution, 15.6672 MHz, unchanged OS cache policy (`CACR=$2001`), and no debugger
stops inside measured phases. They complete through death with 342/343 fight
frames and 3,505/3,449 fields. Intermediate combat trajectories differ, so these
are workload costs, not a matched-state whole-game FPS claim.

Previously, independently aligned actor rectangles overlapped. The coordinate
planner now combines clipped spans in horizontal bands before alignment and
converts each pixel at most once. The remaining cost exceeds 10 ms; the
minimum-area alternative is satisfied: an independent row optimizer confirms
minimum legal aligned coverage for all 40 native publications captured from the
first hit (33 have multiple dirty rectangles), as well as 4,096 host patterns.
The native `C2PVERIFY` oracle checks all 187 publications through that bounded
capture with zero mismatches, including pixels outside the dirty areas. These
correctness runs are separate from timing. Capacity overflow retains a safe
bounding-box fallback; no excess area was observed in the captured frames.

The host fixture also checks 400 alternating-buffer frames, clipping, empty and
extreme bounds, non-overlap and bounded-storage fallback. The planner's compiled
scratch/saved-register frame is 444 bytes; together with the presentation
caller's 352 bytes it remains below 1 KiB before arguments and outer
service/interrupt frames (the dispatcher adds 372 bytes).
The production `frame_pacing.gdb` check passes all 106 logo and 840 book steps,
including one wait/publication per complete step and the exact aligned book bounds.
No pixel shadows or game-instruction changes are involved.

## Cycle profiler

`amiga/aprof.sh` gives exact emulated cost, not samples. It runs a private FS-UAE
that AmigaXDev builds (`make setup`): the same barto remote-debugger fork as the shared
ARM emulator, plus its `patches/fsuae-aprof.patch`. Between `monitor aprof start` and
`monitor aprof stop FILE`, the cycle-exact 68020/68030 loop charges every instruction's
cycle units, including wait states, to its PC. This covers original CODE segments,
native code, Kickstart and interrupts. The patch also times every CPU Chip-bus access.
A call tree follows JSR/BSR/RTS and exceptions; each Line-A exception is keyed by its
trap word. Warp does not change emulated cycles. Other CPU loops (MMU, 040/060, fast
mode) refuse to start, and timing matches the emulator's memory model, not proof of
hardware timing.

```sh
. amiga/env.sh
amiga/aprof.sh book 2 50 book               # book steps 2..52, production build
amiga/aprof.sh gameplay 60 100 attic        # INGAME scenes 60..160, first room
python3 tools/aprof_report.py report attic
python3 tools/aprof_report.py annotate attic RegionRows::row
python3 tools/aprof_report.py subtree attic 'JT291->Dark3+$1D50'
```

`aprof.sh` clean-builds the matching executable and defaults to
`a4000-030-reference`. The report rejects incomplete intervals and CODE segment moves; it records room
and camera changes for state pairing. Outputs go to ignored `tmp/aprof/`; the report also
writes the call tree and the hottest instructions there. Original functions are named
`Segment+$offset` from LINK prologues and observed call targets. `JTn->` marks a
jump-table entry, resolved from the live table. Unmatched RTS/RTE counts measure
call-tree noise from stack manipulation and task switches; flat PC times are exact.

### Monster-to-death cycle

```sh
. amiga/env.sh
amiga/aprof.sh monster monster-a
amiga/aprof.sh monster monster-b
python3 tools/aprof_report.py monster monster-b --compare monster-a
python3 tools/aprof_report.py report monster-a-fight
```

This is a fresh Carnby game, idle in the attic, with `INGAME=1`, the existing
`FIXEDRNG=1` diagnostic entropy fixture and `MONSTERPROFILE=1`. No save is loaded:
loading would change the heap and first-time resource work. The launcher pins
reference 68030/PAL and enables FS-UAE deterministic mode. In that mode filesystem
packets complete on emulated hsync boundaries instead of a host worker's schedule;
otherwise even fixed random input can produce different timed combat routes.
These diagnostic timings are not measurements of physical disk latency.

Start at completed scene 200. End each phase at the first queued frame showing:
MONSTER song 136; actor slot 12 with an active animation; Carnby's first hit animation
237; death song 131. Scene numbers are observations, never end conditions. The
buffer records every intervening frame's fields, ticks, song, cumulative effect
starts, both actor animations, monster record words `$1C`/`$20`, room and camera.
The report rejects missing frames, wrong initial/event states and incomplete runs.

`NAME-{attic,entry,approach,fight}.{prof,log,elf,jt.bin}` are ordinary report inputs.
`NAME.frames.csv` is the per-frame log; `NAME.summary.json` contains phase states,
ordered stalls and costs. Stalls are intervals of at least 25 PAL fields (0.5 s).
The repeat check requires the same phase states and ordered stall identities, with
each phase's fields within 2%; scene numbers may differ. Existing output names are
rejected, so a new run cannot silently replace its baseline.

The steady summary excludes complete call-tree subtrees for camera rebuilding
`(Dark2, $5D30)` and the song-change wrapper `(Dan2, $1B22)`, including jump-table
aliases and nested calls without double counting. It divides the remaining CPU
cost by nonstall frames. This is a **subtree-adjusted estimate**: ordinary work
inside stall frames remains in the numerator. The independently measured field
cadence excludes whole stall intervals. Per-phase `report` retains all work.
Custom exclusions are available with `aprof_report.py steady NAME --frames N
--exclude LABEL` (repeat `--exclude` as needed).

The normal observer buffers records in guest Fast RAM (84,028 bytes, diagnostic
build only), performs no frame-time I/O and stops only at phase boundaries. A
conditional startup breakpoint runs before profiling; no conditional breakpoint
is used inside a measured phase. `APROF_FRAME_STOPS=1 amiga/aprof.sh monster
monster-stops` deliberately restores per-frame stops for the observer-bias control.
It is not an acceptance measurement. `WINDOW_FRAME_STOPS` records the count.
The profiler stub accepts address breakpoints, not target-side GDB conditions;
conditions in the older observer therefore stopped the guest at intermediate frames.
This applies PERF.1's rule to this scenario; the separate book/gameplay observer
still needs its queued PERF.1 audit.

The A/B control used the identical executable and deterministic configuration:
803 intermediate debugger stops versus zero produced byte-identical frame buffers
and all four `.prof` files. Thus there is **no measured cycle/field bias in this
pinned configuration**. This does not validate non-deterministic filesystem runs or
other profiling windows; the maintained scenario keeps all stops at event boundaries.

The deterministic reference uses event boundaries, not fixed frame numbers. Faster
service work changes the natural timed encounter route; whole-fight averages from
different builds are not state-paired A/B measurements. The current profile is
`frame4-due-services`:

| Phase end | Frames | PAL fields | Nonstall fields/frame | Adjusted CPU ms/frame |
| --- | ---: | ---: | ---: | ---: |
| MONSTER song 136 | 546 | 2,225 | 3.928 | 79.96 |
| Monster animation active | 1 | 15 | 15.000 | 298.06 |
| First Carnby hit (237) | 108 | 971 | 7.802 | 170.39 |
| Death song 131 | 319 | 3,403 | 9.590 | 200.77 |

The one-frame entry phase is not a steady-state estimate. These are full
inter-frame stall intervals; the observed event does not establish the cause of
the whole interval.

| Observed event | Scene (reference only) | Fields | Seconds |
| --- | ---: | ---: | ---: |
| Song 137 → 136 | 746 | 84 | 1.68 |
| Effect count 1 → 2 | 789 | 114 | 2.28 |
| Effect count 9 → 10 | 854 | 30 | 0.60 |
| Song 136 → 132 | 874 | 69 | 1.38 |
| Effect count 41 → 42 | 1,132 | 25 | 0.50 |
| Room 0/camera 0 → room 6/camera 10 | 1,162 | 244 | 4.88 |
| Song 132 → 131 | 1,174 | 44 | 0.88 |

Song 132 starts before the first hit in this route; follow the hit event for the
fight-phase boundary rather than assuming song order. Nonstall fighting is about **5.21 FPS** in this instrumented
reference run. The adjusted CPU total excludes named one-off subtrees; use the
full-phase PC costs above for subsystem attribution. Neither is a shipping-build
or real-hardware FPS claim.

#### Repeated camera masks

The matched 12-mask rebuild below `(Dark, $3694)` in the approach phase costs
**313.71 ms of port work**, versus 800.76 ms without geometry reuse/local heap
merging: **60.8% less** (`region1-before-approach` / `region1-retained-approach`).
The repeat yields identical counters and costs. Both calls issue 12 FramePoly,
12 InsetRgn and 43 CopyBits calls; original rendering call counts match. Timed
VBL callback/interrupt counts naturally fall with elapsed work. Original code
within this subtree remains 120.6–120.8 ms; these are totals per rebuild, not
per-frame averages printed by the generic subtree report.

All 24 geometry transforms hit exact records computed earlier in the same run.
The bounded cache removes repeated encoding/expansion; local-tail heap merging
removes whole-zone scans during polygon/region resizing. First-seen geometry
still uses the original validated helpers. The separate, mostly cold pair of
rebuilds in the fight phase improves only 334.33 → 323.23 ms of port work; the
60.8% result is **not** a claim for every camera transition. Original background
decompression and other game work remain, so complete scene stalls can still
last several seconds. No framebuffer shadow comparisons or game-code changes
are involved. See [region validation](testing.md#region-rebuilding).

#### Song-start attribution reference

The separately pinned `heap2-tail` / `heap2-final` captures below are the
attribution reference for AUDIO.1, not timings from the current region-cache
build. Re-measure them when implementing audio changes.

The three `startNativeSong` subtrees total **2.616 s**, including **0.508 s** in
`MacHeap::moveHigh`. Their disjoint preparation costs, in milliseconds, are:

| Song | Resource source reads | MoveHHi | MIDI decoding | PCM conversion | Remaining work | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 136 | 357.34 | 185.65 | 59.08 | 98.71 | 187.41 | 888.19 |
| 132 | 407.86 | 233.64 | 114.90 | 135.60 | 229.41 | 1121.41 |
| 131 | 171.50 | 88.28 | 117.18 | 89.59 | 139.97 | 606.52 |

Each named column includes its complete subtree, including interrupts during that
work. The selected subtrees do not overlap; remaining work is the total minus those
columns and includes loader logic, other heap/resource operations, clearing buffers
and audio startup. `loadSongSample` takes 484.11, 575.74 and 204.19 ms for songs
136, 132 and 131 respectively. Those inclusive sample-loading totals contain reads
and heap movement already counted above and must not be added to them.

All three native starts exceed 0.5 s. AUDIO.1 tracks implementation with a target of
≤ 0.3 s per native `startNativeSong` invocation. Full frame intervals also contain
original game work and presentation and are reported separately.

Isolated, single-frame profiles (`heap2-single-136`, `-132`, `-131`) retain the
same MONSTERPROFILE/FIXEDRNG executable and deterministic reference configuration.
They start at queueFrame scenes 699, 797 and 1062 and end at the next unconditional
queueFrame breakpoint, with no intermediate debugger stops. They reproduce the
96/82/44-field intervals and the loader costs in the whole-route profile:

| Song | Frame CPU ms | Original instructions ms | Native song preparation ms | MoveHHi ms (included) |
| --- | ---: | ---: | ---: | ---: |
| 136 | 1,920.20 | 383.18 | 888.19 | 185.65 |
| 132 | 1,654.17 | 207.88 | 1,121.42 | 233.64 |
| 131 | 885.37 | 102.91 | 606.52 | 88.28 |

Field counts measure cadence; CPU intervals include the positions within their
boundary fields. The first frame includes 156.11 ms in original decompression
`(Dark, $2A78)` and `(Dark, $29FE)`, plus original rendering/game work. Its original
instructions alone exceed 300 ms. Thus a 300 ms **whole-frame** gate on this matched
workload cannot be established by reducing native heap or audio cost alone. The
owner-approved separation of audio work therefore measures native song preparation, excluding
original game work and unrelated drawing/presentation.

### Debugger-free hardware audit

Real-Amiga benchmarks are deferred by the owner. The audit is ready for future
runs; emulator verification establishes collection and cleanup, not 68040 speed.

```sh
. amiga/env.sh
make -C amiga clean
make -C amiga -j4 MONSTERAUDIT=1
amiga/monster_audit_run.sh 600
make slave
python3 tools/test_whdload.py --mode quit --cpu 68040 --mmu --startup-prefs \
  --no-filelog --ticks 30000 --seconds 600
python3 tools/check_monster_audit.py path/to/monster-whd.bin --json tmp/monster-whd.json
```

`MONSTERAUDIT=1` enables `FRAMEAUDIT=1`, `INGAME=1` and `FIXEDRNG=1`.
It uses the same scene-200 start and four event boundaries as the profile above,
without GDB. Carnby remains idle; the game runs the encounter and death naturally.
At the final boundary the next normal service return requests ExitToShell. Only
**after restoring AmigaOS and closing game files** does the audit write its report
beside the executable: `monster-whd.bin` or `monster-amigaos.bin`. Each filename is
replaced on a subsequent run; retain separate copies for A/B comparisons.
A bad initial state or full buffer also exits, with a report rejected as incomplete.

Use a separate copy of the installed game for hardware testing. Replace its
`AloneInTheDark` executable with the audit build and supply explicit default
preferences in its `prefs` drawer, generated on the host with:

```sh
python3 tools/check_startup_prefs.py --prepare --folder tmp/monster-audit/prefs
```

The generator refuses to replace an existing directory. Preserve the user's normal
preferences. First-launch preference creation is a different path and can enter
this unattended route without music; a measured run must begin with song 137,
Carnby animation 4 and no active monster. The emulator fixtures stage defaults
explicitly. Run the installed WHDLoad icon, or launch the executable from an
AmigaOS shell after SetPatch. Leave input alone; it quits automatically at death.
Keep the same audit executable, default preferences, video and hardware settings
for comparisons. Capture the CPU model/clock, Fast RAM, storage, SetPatch CPU
library version and WHDLoad options alongside both reports. Existing caches are
observed, never changed by the audit.

For plain-AmigaOS 68040/68060 acceptance, require the instruction-cache enable
bit `$00008000` and data-cache enable bit `$80000000` in both reported values:
`(CACR & $80008000) == $80008000`. Record the full values and investigate any
change in policy bits. Flushes may use transient control bits; equality of the
two endpoints alone cannot prove that every intervening instruction preserved
policy. The source audit is in [development](development.md#plain-amigaos-cache-ownership).
A Kickstart-only emulator run without the CPU library does not satisfy this gate.

The buffer occupies 458,752 bytes of Fast RAM and holds at most 16,384 frames;
the observer adds no allocation, file I/O or debugger stop between measured events. The
FRAMEAUDIT publication buffer is also enabled. Diagnostic memory and logging
therefore differ from production: price later changes against the **same audit
build configuration**, not directly against the smaller PERF.2 profile buffer.

Wire format: a 64-byte big-endian header (`16I`), then PERF.2's 28-byte frame
records. Header words are `AITD`, `MON1`, version 1, row count, terminal phase,
PAL flag, WHDLoad flag, Exec AttnFlags, CACR before game entry, CACR after OS
restoration, cleanup success, and five phase-boundary row indices. The decoder
requires all four contiguous phases and valid event states, checks frame/field
progression including the 16-bit field wrap, and reports fields/frame, nonstall
FPS and stalls of at least 0.5 seconds. This is field cadence, not CPU-only time.
CACR values describe the two capture points; they do not prove cache behavior
throughout the run.

Emulator coverage includes direct AmigaOS PAL/NTSC and WHDLoad 68040/MMU,
normal return, report export and decoding. No physical-Amiga result is implied.
Always clean-build production defaults again before packaging a release.


### Reference-68030 baseline

| PAL, `a4000-030-reference` | Book fold, steps 2–52 | First room, scenes 60–160 |
| --- | ---: | ---: |
| Fields / steps | 132 / 50 | 414 / 100 |
| Time per step | 52.9 ms | 82.8 ms |
| Original game code | 0.5 ms | 53.6 ms |
| C2P | 24.4 ms | 7.6 ms |
| QuickDraw fills, lines, regions | 6.1 ms | 2.7 ms |
| QuickDraw CopyBits | 4.0 ms | 4.7 ms |
| Trap entry/dispatch, state lookups, VBL polling | 13.8 ms | 9.8 ms |
| Other presentation | 2.9 ms | 0.3 ms |
| CPU Chip-bus accesses (included above) | 7.3 ms | 1.9 ms |

In the first room, original game code accounts for most of the frame. The model
renderer (`Dark3+$1D50`, entered via jump-table entry 291) includes skeleton animation,
vertex transformation, edge/span filling and an O(n²) primitive depth sort. Its port
calls include RGBForeColor, PenMode, MoveTo and LineTo for each model line. Outermost
PenMode and MoveTo now cost 36.9 and 36.8 µs respectively, including Line-A entry and
return. The direct entries retain the full register image and service pending callbacks
and completed frames. CopyBits checks exact mask bytes against previously validated regions. Mask validation
costs 0.70 ms per frame; total port work below `(Dark, $30A8)` costs 4.24 ms.

The book uses 8 bitplanes at FMODE=3. Its coordinate-bounded C2P costs 24.4 ms per
step and is the largest remaining port cost. Solid fills and lines use row/span loops;
back-buffer synchronization uses bounded blitter copies. The presentation bucket
includes the complete blitter wait, not just CPU setup. CPU Chip-bus accesses average
about 10.3 cycles, including polling while the blitter and display share Chip RAM.
These captures use the Kickstart CACR of $2001, with the 68030 data cache off.
Earlier profiles and before/after measurements are in Git history.

## Steady gameplay

Load the ordinary first-floor checkpoint with `FIRSTFLOORLOAD=1 INTROSKIP=1`, settle for
200 PAL fields, and count completed scenes over 3,000 fields. Compare like-for-like
instrumentation. The retained fixed-020 diagnostic baseline rose from 7.12 to 9.62 FPS
through dirty-only publication, palette seed caching, constant-time handle validation,
common-trap fast paths, CopyBits span/stride work and constant-time scene completion.
These are diagnostic-build rates.

The older statistical sampler remains for the first-floor checkpoint; prefer the cycle
profiler for cost attribution. `sample_gameplay.py` interrupts the debugger at
randomized host intervals. Use
`gameplay_sample.gdb` after connecting at MacLoader::run with the matching ELF/save.
Pass `--gdb`, `--elf`, `--connect`, `--setup`, `--out` and `--samples 2000`, from
`amiga/`. `summarize_gameplay_profile.py` verifies the room and assigns each PC exactly
once, prioritizing original segment ranges over native backtraces. Sampling can be
biased by emulator throughput; zero sampled PCs is not proof of zero cost. Do not add
overlapping scope timers.

Two instrumented fixed-020 samples total 99.67/99.65 ms per frame; original code
accounts for 59.30/60.83 ms and other native/trap services for 27.96/28.00 ms. The
fixed-030 sample totals 86.67 ms, with 51.66 ms in original code. These used different
emulator builds and do not establish a cycle-accurate hardware ratio. Rare IRQs need
direct E-clock accounting rather than PC sampling.

## Item menu and enemy room

The record item's original preview calls PtInRect for individual nontransparent pixels
at (Dan2, $1966), within $1934–$199E. That accounted for 46.3% of the baseline samples.
The shared fast dispatcher removes this overhead while preserving signed half-open
bounds, Pascal ABI, patched-trap fallback and frame/ callback service rules. Original
game instructions are unchanged.

| Fixed 68030 preview | Updates per second |
| --- | ---: |
| Native before fast PtInRect | 2.741 |
| Native with fast PtInRect | 4.001 |
| Original Mac IIx | 2.094 |

These measure steady preview redraws at the original angle decrement (Dan1, $0F7A), not
menu-opening or key-response latency. Compare completed draws at Dan1+$10EA with the
same item, angle, focus and inventory. A past 186-byte screen mismatch was exactly the
selection-label colour change; matching angle alone was not matching UI state. The
preview pane and palettes match in the controlled comparison. Remaining work is spread
across copying, original per-pixel processing and common services.

The pirate room's native sample is 45.0% original code, 52.5% native runtime and 2.1%
Kickstart; C2P is 9.1% and CopyBits 5.4%. Two dynamic native windows produce 2.68 and
2.53 FPS. Mac context is about 3.51 FPS, but positions, poses and attack phases differ,
so this is not a matched-state ratio. Health was raised only for the bounded profiling
fixture. No single enemy-specific service dominates as PtInRect did in the item menu.

## Loading and interrupts

Cold scene masks, synchronous song-resource preparation and steady rendering are
separate workloads. Heap/allocator changes removed large preparation penalties, but a
resource switch can still contain seconds of synchronous work. Measure the complete
old-to-new scene boundary and identify its constituent operations before optimizing a
helper. Keep sprite/VBI and CIA music progress independent of that main-thread latency.

Use `M5AUDIT=1` with the matching observers for memory and IRQ accounting; see
[amiga-arch.md](amiga-arch.md#interrupt-checks). C2P may only convert changed areas
after a completed frame. Do not reintroduce chunky shadow comparisons.

## Book turns and frame pacing

The book uses 56 authored steps per forward page turn. The original wait at
(Dan1, $4978) holds each page for 300 Mac ticks (five seconds). On the unlimited
68040/JIT PAL configuration, the opening's 15 turns run at 50 FPS; the 14 intervening
holds account for 70 seconds of the 86.5-second interval from the first animated
publication to the last. Rendering optimizations do not shorten these reading holds.

On the default cycle-exact 15.6672 MHz 68030/PAL setup, a lightweight
`FRAMEAUDIT=1` run measures **11.74 displayed steps/s** within the moving folds
(825 intervals, 2–8 fields each, mean 4.259). The first-to-last book publication
spans 145.74 seconds: 70.28 seconds within folds and 75.46 seconds in the 14
page-transition gaps, including the 70 seconds of deliberate reading holds.
These are emulated-field measurements, independent of host warp speed.

The [cycle profile](#reference-68030-baseline) of a fold attributes 40.6% of each step
to C2P, half of it Chip-bus waiting. Six PaintRects take 11.7% and one fold LineTo
6.5%; the back-buffer copy in `presentMacFrame` takes 11.0%. Original code is 0.6%.
Completed-frame pacing adds no extra wait per drawing call.

Book dirty bounds are accumulated from the min/max coordinates of actual clipped
fills, lines and copies. At frame completion, combine those bounds **before** C2P
alignment. This avoids overlapping conversions caused by separately aligned page
strips. No shadow framebuffer or pixel comparison computes the dirty rectangle.
All 840 opening steps use one converted rectangle, ranging from 6,400 to 38,400 pixels
(mean 22,057), rather than the full 64,000-pixel viewport. Alignment is 16 pixels at
the left edge and a width divisible by 32, as required by the Kalms converter.

Solid spans align their longword stores and handle unmasked rectangles with a
fixed row stride, without region-edge work on each row. Back-buffer synchronization
copies only prior dirty spans not fully replaced by the current conversion. With the
pointer disabled, these copies
need no cursor-inversion interrupt guard: VBI cannot alter the buffers until the
completed frame is queued. The explicit cursor fixture retains its guarded path.

`frame_pacing.gdb` checks the original 106 armadillo loop steps and all 840 book steps:
one wait and one publication per step, no waits inside drawing batches, and C2P bounds
exactly matching coordinate bounds plus alignment. The ordinary build contains no
profiling timers. `FRAMEAUDIT=1` adds a bounded report for WHDLoad/emulators without GDB;
its timing field is written at the actual VBI buffer swap. Neither diagnostic needs
shadow comparisons. The separate `C2PVERIFY=1` correctness build decodes every pixel,
including pixels outside dirty areas; never use its expensive verifier for FPS claims.

The action-menu observer also requires exactly one wait/publication per completed
preview rotation, rather than one per drawing trap. Gameplay scene batching retains
its unchanged-frame simulation pacing and complete-frame publication checks.

## Save-related WHDLoad switches

A fresh save measured seven OS returns on the maximum-speed 68030 with 8 MB
Fast RAM plus 32 MB Zorro III RAM, PRELOAD enabled and FILELOG disabled.
The individual resload calls account for all seven:

| Operation | OS returns |
| --- | ---: |
| Create empty data fork | 1 |
| Create 32-byte Finder metadata | 1 |
| Write 36,254-byte game state | 1 |
| Create empty resource fork | 1 |
| Publish initial 286-byte resource map | 1 |
| Publish resource payload and subsequent map update | 2 |

Later metadata writes were cached by WHDLoad. Updating an existing save in a
fresh launch measured four returns: two initial fork reads, one metadata write,
and one resource-fork write. These counts depend on cache contents and resource
sizes; they are observations, not fixed guarantees. FILELOG inflated the measured
fresh-save count to nine and the existing-save count to seven, so disable it
when measuring normal-play disk switches.

The File Manager already buffers individual writes and publishes a whole dirty
fork at flush/close. Resource Manager creation, WriteResource and UpdateResFile
publish distinct resource states. The remaining fresh-save writes are not
identical redundant writes. Combining them would defer successful creation or
publication across original service boundaries, changing failure reporting and
persistence behavior. The resload API accepts one file per save call; it has no
multi-file transaction API. No additional runtime buffering is applied.

WHDLoad's default write cache can itself defer writes until exit. Preserve its
policy; do not interpret a cached success as a physical disk flush. Normal Quit
and a fresh uncached load are the persistence checks. One or two OS returns
are therefore not a safe general target for this save implementation.
