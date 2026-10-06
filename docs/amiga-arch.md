# Amiga architecture

The runtime is Vette!'s, with its game-specific hooks removed. This page records
what is inherited unchanged, what was generalised, and what must change for this
game. Vette's `docs/amiga-arch.md` has the complete rationale for the inherited
parts.

## Original game and compatibility layer

`PlatformAmiga` opens the application resource fork under `PROGDIR:data/`
or `PROGDIR:`, retaining its map rather than preloading every body. It takes
the machine over in the order
established by the earlier ports (LoadView(NULL), display DMA down, VERTB vector
taken over, screen built, published to the ISR, DMA up, Forbid, run, restore in
reverse). The Workbench startup message is handled as in Vette.

`MacLoader` validates CODE resources before takeover and retains CODE 0/1 for
startup. The original CODE 1 expands the A5 world, handles later segment loads
and relocates the jump table. Resource bodies stream into owned zone handles
on demand; the original executes in user mode through the Line-A service bridge. Loader
failures and unimplemented traps are named loud stops painted by `AitdScreen`;
the VBI keeps running so the report stays visible. See [static-map.md](static-map.md).

Page-0 globals the original touches are redirected, after byte checks, to the
private `s_portLowMemory` block (Ticks, RndSeed, WMgrPort, GrayRgn, KeyMap,
CurrentA5, mouse and button state). The VBI keeps Ticks at 60 Hz and the mouse
shadows current. All 58 census low-memory accesses are redirected to private
shadows; the original A5 state and startup path pass M2 acceptance.

The Memory, Resource, QuickDraw (PICT, CopyBits, GWorlds), Palette, Window,
Menu, Dialog, Event, Vertical Retrace and Trap Manager services began with
Vette and now implement the measured Alone in the Dark startup/intro contracts.
Unimplemented calls or forms still produce named loud stops.

## Display

### Intro performance comparison (2026-10-03)

The [complete same-character 68030 comparison](intro-comparison.md) closes
intro performance before M3. Current Amiga/Mac frame-time ratios are mostly
1.1–1.9×, with one 2.12× late-corridor visit whose cold preparation cost is
measured. The car runs at 2.86 versus 4.36 FPS; near/far frog rates are
3.36/3.35 versus 4.73/3.80 FPS. Mansion entry takes 8.82 versus 8.05 seconds,
and no current camera transition reproduces the reported 15-second gap.

The selected `a4000-030-reference` uses a 68030 at 15.6672 MHz, matching the
MAME Mac IIx clock, with 8 MB fast RAM, AGA and no JIT. Music uses CIA timing;
complete note, sample and ownership checks pass. Recorded output gaps originate
in FS-UAE's host audio queue and remain an emulator limitation. Different
memory systems and approximate emulator timings limit hardware equivalence.

The chronological checkpoints below retain intermediate measurements and
then-open gates; the current comparison and acceptance audit supersede their
status conclusions. Performance uses emulated ticks, not host elapsed time.

| Checkpoint span | Amiga ticks | Mac ticks |
| --- | ---: | ---: |
| Matched near-car renderer call, VBI-music build | 15 | 12 |
| Same near-car draw → next original loop, VBI-music build | 18 | 12 |
| Natural first frog mask construction | 32 | 11 |
| Natural first frog loop → next loop | 54 | 27 |
| Room-2 transition → first hallway loop | 275 | 274 |
| First two hallway loop entries, room 2/camera 5 | 104 | 55 |
| Last hallway loop → first stair-view loop, camera 5 → 3 | 140 | 97 |

The model replay pairs geometry, transforms and mask inputs, not every other
actor or timing state. It now explicitly captures the first cold frog loop;
the older 10-tick Mac replay had a warmed mask and is not a valid cold-frame
comparison. Neither draw-to-loop span is an isolated renderer benchmark.
Natural-route timings can differ with actor trajectories and animation phase.
In the phase observation, the frog model itself takes 3–4 native ticks versus
2–3 on Mac; its first mask is much more expensive than subsequent masks.

Those hallway measurements exclude room entry before the first camera-5 loop.
The complete entry also includes loading room 2 and passing through camera 0.
The retained native route takes 379 ticks from its room-2 transition checkpoint
to the first camera-5 loop, versus 274 on Mac. Including the first camera-5 loop
gives 484 versus 329 ticks (8.07 versus 5.48 seconds). The Mac evidence is
`tmp/intro-030-route-mac-retry.log`, with all nine transitions, explicit PASS and
normal debugger exit. These are common original checkpoints, not a claim of
identical actor/cache state or the exact moment the host picture changes.

The subsequent native VBI-music run (`tmp/music-vbi-busy-route-full.log`, exit 0)
takes 373 + 104 = 477 ticks (7.95 seconds) across that complete entry, and
32 ticks for its first frog mask. Its nine transitions, natural completion,
3,736 music events and 920-byte minimum original stack margin pass. Music's
maximum delivery delay is one logical tick in this run; an earlier two-tick
outlier remains documented in [sound-driver.md](sound-driver.md).

The room-entry attribution run (`tmp/intro-room-entry-profile-full.log`, exit 0)
starts at the first profiled trap in room 2/camera 4 and stops at the first
camera-5 loop, including the intervening camera-0 loop. It records 152 Open,
152 Close and 460 Read calls. Their inclusive totals are respectively
3,498,103, 2,684,489 and 5,685,388 beam units, about 36% combined of the
408-field interval. Drawing-service time is only 306,781 units. This identifies
file traffic as a substantial transition cost; profiler overhead means its
490 elapsed ticks are not a replacement for the unprofiled timing above.
The retained per-open cache fetches up to 64 KiB on a tiny header miss and
discards those bytes on close. A 4 KiB read-ahead/direct-payload trial did not
improve room entry: 437 ticks to the first camera-5 loop versus 373 retained.
The trial was deliberately stopped after that measurement, not accepted as a
complete route (`tmp/intro-read-ahead-route-full.log`, exit 1). Its two cache
changes are reverted. The then-current OS-window return path translated all 128 raw key
codes to release them on every operation. The bulk-release trial computed the
translated-key mask once, then applies it to the 16-byte Mac map, preserving
unmapped bits. Its 256-pattern native comparison matches individual releases.
`tmp/intro-key-release-window-full.log` (exit 0) passes the original 21-window
fixture, exact 1 MiB data, save/error cases, held-key/alias checks, Paula progress
and bitplane snapshots. Total entry/exit costs are 11,475/25,140 beam units,
about 2.1/4.7 scanlines per window. The historical fixture's approximately
3/110 lines used an older build/setup, so it is not a matched speedup ratio.
The unprofiled run (`tmp/intro-key-release-route-full.log`) reduces room entry
from 373 to 275 ticks, versus 274 on Mac. Including the first hallway loop is
379 versus 329 ticks (6.32 versus 5.48 seconds). The table above uses this run
for frog/hallway/stair observations. All nine transitions, natural completion,
3,736 music events and the 920-byte minimum original stack margin are present.
The observer exits 1 because the known music timing outlier recurs: two ticks,
with a busy channel-ownership field at tick 9550 and late delivery at 9552.
This establishes the deferred field's source; it is not a complete audio pass.
M3.1 subsequently removed automatic key resets entirely: they interrupted
held movement keys during animation loading. Keyboard ownership now spans DOS
windows; the measurements above describe the earlier intro-performance build.

The longword sample-conversion build repeats the complete route in
`tmp/intro-longword-route-full.log`: nine transitions, natural completion at
tick 19,906, 1,008 presented frames, all 3,736 music events and zero late
publications. Hallway entry is 274 ticks, followed by a 104-tick first frame
(378 combined versus 329 on Mac). The frog mask/first loop is 33/55 ticks;
hallway-to-stairs is 139. These confirm that the remaining hallway gap is in
the first frame, rather than room entry. The observer exits 1 on the known
audio gate: maximum lateness two ticks, after ownership exclusion at 8764
and delivery at 8766. This is route completion evidence, not audio acceptance.

An isolated first-hallway-frame profile (`tmp/intro-hall-first-full.log`, exit 0)
subtracts counters at consecutive original Dark+$5658 entries in room 2/camera
5. It spans exactly one publication, 113 fields / 136 diagnostic ticks; these
instrumented times are not a shipping-build benchmark. The largest inclusive
trap totals are InsetRgn 1,417,244 beam units (15 calls), LineTo 1,250,890 (214),
CopyBits 1,033,557 (34), the sound-driver trap 564,614 (280), and FramePoly
551,963 (15). Expansion geometry accounts for 1,278,996 units; shared trap
services 919,215, heap lookup 682,399 and original VBL callbacks 1,342,449.
These categories overlap and must not be added. Resource/audio preparation
categories are zero; the driver still handles its ordinary callback traffic.
This directs the remaining first-frame investigation toward geometry, drawing
and copying rather than file read-ahead. Before/after arrays are retained as
`tmp/hall-first-{phase,trap,calls}-{before,after}.bin`.

An eight-entry cache of validated heap-block locations was tested and rejected
(`tmp/intro-pointer-cache-route-full.log`). It passes sanitized heap tests but
changes the frog mask only from 33 to 31 ticks and the first hallway loop from
104 to 100. The complete route still fails the two-tick music gate (exit 1).
The small gain does not justify the extra cache/invalidation state; the normal
heap lookup remains unchanged. The trace is not a matched-frame pixel check.

A local free-tail merge in `resizeInPlace`, replacing its whole-heap coalescing
scan, was also tested and discarded. Sanitized heap tests pass, and
`tmp/intro-local-coalesce-route-full.log` completes the route and music timing
gate (exit 0). The frog mask changes from 33 to 30 ticks and first hallway loop
from 104 to 99. These small gains do not justify continued heap-level tuning
for P1. A single passing music run does not resolve the previously reproduced
effect-boundary deferral; that remains a separate correctness/timing issue.

The subsequent deferred-music fix services excluded VBI updates when outer
audio ownership is released. Its normal route (`tmp/music-deferred-route-full.log`,
exit 0) completes nine transitions, 3,736 events and 1,046 frames with maximum
music lateness one tick despite seven excluded fields. No late publications
occur; minimum observed game-stack margin remains 920 bytes. The first hallway
loop is 105 ticks, effectively unchanged from 104. See
[sound-driver.md](sound-driver.md) for the forced nested-ownership fixture and
remaining listening/sub-field timing acceptance.

The measured hallway-to-stairs span is 2.35 seconds versus 1.62 on Mac; initial
camera-5 loop preparation is 1.75 versus 0.92 seconds. The owner's earlier recording
showed a nearly unchanged 14.7-second interval at 334.2–348.9 seconds before
this stair view. That recording used the earlier A1200 setup and implementation,
so it is not a same-machine before/after benchmark. Its white cache-window
interruption is excluded from evidence.

The retained service changes address repeated work:

- Geometry services reuse 9.25 KiB of private recording and scratch storage
  instead of allocating temporary application-heap handles for each polygon.
  The algorithms and caller-owned results are unchanged; original callbacks
  run after these synchronous services finish.

- Region expansion streams three neighbouring rows through validated forward
  cursors instead of rescanning the whole encoded region for every row. Its
  first pond call takes one tick and matches all 244 original result bytes.
- Unlocked handle growth uses an existing free block before shuffling the
  surrounding heap. Locked handles and fragmented-heap recovery retain their
  original contracts.
- Heap mutations maintain the free-byte total and descending free-master chain
  incrementally. Publishing the zone no longer rescans all blocks or rebuilds
  every free link. Lowest-address slot allocation and the published chain order
  are preserved, including new master blocks allocated into lower holes.

The complete cold-mask profile before the last change attributes 1,216,280 of
5,777,665 beam units (21.1%) to 374 heap publications
(`tmp/intro-mask-complete-ccr-full.log`, exit 0). This brackets the actual mask
call rather than diluting it with subsequent frames in a fixed-duration sample.
The unprofiled first-mask measurement falls from 67 to 47 ticks, and the first
whole frog loop from 90 to 70. Hallway preparation falls from 146 to 120 ticks,
and the stair transition from 199 to 162. These useful gains do not close P1.
Nested diagnostic categories overlap and must not be added or quoted as FPS.
The repeated complete-call profile (`tmp/intro-incremental-profile-full.log`,
exit 0) records the same 374 publications at 75,688 beam units, down 93.8%.
The whole instrumented interval is 3,935,487 units over 49 fields; publication
is now 1.9% of that interval. Region geometry is 647,352 units, pointer lookup
336,498 and original VBL callbacks 588,453. Remaining costs need separate
attribution; the profile does not justify another geometry micro-optimization.

After private workspace reuse, the complete-mask profile is 2,956,031 beam
units over 37 fields (`tmp/intro-current-mask-profile-full.log`, exit 0).
The largest inclusive trap totals are InsetRgn 739,937 units (12 calls),
recording LineTo 656,765 (112), and FramePoly 303,118 (12). Shared services
take 256,067 units and original VBL callbacks 431,724; these overlap trap
totals. Expansion geometry itself remains 647,375 units. This is attribution,
not a shipping-build timing measurement.

Two further trials each reduce the identical twelve-polygon unprofiled mask
only from 35 to 34 ticks: jumping between region-row transitions instead of
visiting every row, and dispatching common pen operations before unrelated
manager checks (`tmp/intro-region-events-frog-full.log` and
`tmp/intro-mask-fast-dispatch-frog-full.log`, both exit 0). All twelve input
records match the retained baseline. The region trial also passes independent
pixel/atomic-rejection tests and the original Mac region bytes. Neither trial
is retained: their measured benefit does not address the remaining experience
enough to justify further tuning before current owner-visible playback.

A separate cold-workload replay rules out different polygon inputs as the
remaining mask explanation. Both runs construct the same 12 polygons in the
same order, with every record byte equal, and produce identical viewport pixels
and all 256 colours. That allocator-build baseline takes 46 ticks versus 10 on Mac
(`tmp/intro-workload-native-full.log`, `tmp/intro-workload-mac.log`, both exit 0).
This comparison injects the captured native frog model/transform before the
first Mac frog draw and observes original FramePoly at Dark+$33EC; it does not
alter original instructions or precompute regions.

A matched near-car pose (previous projected width at least 100 pixels) also
matches every viewport pixel and colour. On the VBI-music build, the original
renderer call at Dark+$3ED4 → +$3EDA takes 15 native ticks versus 12 Mac ticks.
Within Dark3, model setup through sorted surfaces (+$1DA0 → +$1EFE) takes 4 versus 7 ticks;
drawing the sorted list (+$1EFE → +$1F2E) takes 11 versus 5. Geometry preparation
does not explain this sample's renderer gap. The complete draw-to-next-loop
span is 18 versus 12 ticks, including masking, overlay and presentation
(`tmp/intro-vbi-car-work-full.log`, `tmp/intro-vbi-car-work-mac.log`, both exit 0).
Attribute the work after drawing separately before treating the whole-frame
ratio as a model-renderer slowdown. Other actor/cache/timer state is not fully
paired by the model fixture. Accepted inputs and exact outputs are archived
under `tmp/intro-vbi-car-work-captures/`. The earlier 16/23-tick native result
used transform (6029, 0, 379, 0, 512, 0), whereas this pair uses
(6022, 0, 367, 0, 512, 0). Both pairs match their Mac pixels, but the different
poses and surrounding timing state prevent attributing the entire apparent
improvement to interrupt music.

The whole-route compiler experiment with `-O3` gives no useful overall gain:
the first frog mask takes 41 rather than 35 ticks, hallway preparation 103
rather than 105, and the stair transition remains 141. It completes naturally
(`tmp/intro-o3-route-full.log`, exit 0), but the normal `-O2` build is retained.
Temporary native model injection is not a clean timing baseline: although its
output matches, surrounding callback/timer state remains unpaired. It is not
used for the timing table or for attributing a compiler improvement.

The valid steady-car sample (`tmp/intro-car-scene-profile-detail-full.log`,
exit 0) stays in room 0/camera 0 for 45 fields, spans one publication and
records 1,117 trap entries. C2P is 7,695 of 3,602,660 beam units (0.21%) and
bitmap synchronization 3,371 (0.09%), so neither explains the remaining car
slowdown. Shared trap services take 571,938 units (15.9%); original VBL
callbacks take 531,615 (14.8%). Inclusive LineTo, RGBForeColor, MoveTo and
PenMode dispatches together account for 48.8%, overlapping the shared work.
Their total is not an isolated rasterization cost. The earlier short sample
failed its acceptance guard and is not evidence; the accepted repeat reports
all counters before checking scene, publication and converter activity.

The compiler's bytewise big-endian field reads are not an established cause of
this gap. A discarded experiment replaced MacLoader's word/long accessors with
native moves: the identical 12 cold-mask polygon records took 54 ticks rather
than 46, and the near-car sample still took 17 renderer / 23 whole-frame ticks
with a slightly different pose (`tmp/intro-native-access-cc-{frog,car}-full.log`,
both exit 0). Fewer generated instructions alone do not justify that rewrite;
the bytewise accessors remain in use.

Current evidence:

- Private region workspace reduces the identical 12-polygon mask from 42 to
  35 ticks. `tmp/intro-region-private-frog-full.log` and
  `tmp/intro-region-private-mac.log` both exit 0, with exact viewport pixels,
  256 colours and polygon records. The final normal build also takes 35 ticks
  (`tmp/intro-region-private-route-full.log`, exit 0), completes all nine
  transitions naturally and gives the 59/105/141-tick spans above. Minimum
  observed VBI stack margin is 920 bytes. The native region ABI/ownership
  checker passes `tmp/intro-region-private-record-retry-full.log`, including
  unchanged heap allocation during FramePoly and 5,392-byte encoder headroom.
  Original region/expansion host fixtures and atomic rejection checks pass.
- Resource ownership searches are not a dominant cold-mask cost: the temporary
  attribution in `tmp/intro-resource-cost-full.log` measures 7,197 of 3,728,711
  beam units (0.2%), with no forgetHandle calls. No resource-index rewrite is
  justified by that sample; its extra profiling scopes were removed.
- Removing two debugger-only largest-free-block scans from memory-result
  processing reduces the identical 12-polygon cold mask from 46 to 42 ticks
  (`tmp/intro-heap-stat-frog-full.log`, exit 0; every polygon still matches the
  Mac record). The full natural route (`tmp/intro-heap-stat-route-full.log`,
  exit 0) completes all nine transitions with a 928-byte minimum observed
  stack margin. Its hallway/stair spans were 115/156 ticks, versus
  120/162 before removing the scans. Allocator searches and original services
  are unchanged; diagnostic heap counters retain only constant-time totals.
- `tmp/intro-incremental-route-full.log` exits 0 after all nine original room
  transitions and natural completion. Minimum observed mouse-VBI stack margin
  remains 928 bytes above the 6 KiB supervisor-stack lower bound.
- `tmp/intro-incremental-frog-full.log` and `tmp/intro-frog-phases-mac.log` give
  the cold/warm phase observations. Both exit 0 at explicit completion checks.
- `tmp/intro-incremental-frames-full.log` and
  `tmp/intro-incremental-{car,frog}-mac.log` all exit 0. The matched-model checker
  passes every one of the 64,000 viewport pixels, all 256 colours and actual
  AGA publication for both actors. The frog replay asserts the first cold loop.
- The full host suite (`tmp/intro-incremental-heap-host.log`), allocator
  sanitizer checks and three-stage native heap fixture
  (`tmp/intro-incremental-heap-native-full.log`) pass. Structural checks
  independently recompute free space and verify every free-master link.
- `tmp/intro-retained-song-full.log` rechecks the retained runtime after private
  workspace reuse. It exits 0 and passes the original-song checker: 3,736 exact
  timed events, 25 retained PCM variants (458,974 bytes), effect priority,
  natural completion and resource/voice cleanup.

Normal owner-visible playback and the remaining car/cold-mask performance gap
still require acceptance. A successful frame publication does not by itself
establish smooth playback or audio quality.

`AitdScreen` owns one 320×200 eight-plane display, using the live WIND 128
content rectangle within the 640×480×8 logical Mac screen. Each chip bitmap
contains 200 interleaved rows of eight 40-byte planes (64,000 bytes). Explicit
dirty rectangles align to 32 destination pixels. The back bitmap inherits the
previous frame's changed spans before receiving the new changes.

Main-thread conversion prepares the inactive bitmap and complete copper list.
VBI swaps both together before input/audio work. The list includes all 256
RGB24 colours, using BPLCON3 banks and high/low nibble writes. An integer lookup
reproduces the measured Mac video transfer while preserving the logical RGB16
CLUT. PAL and NTSC use one-times fetch and have passed native and owner-rendered
acceptance. The pointer preserves all game colours through sprite-bank
ownership and reversible index inversion; see [cursor.md](cursor.md).
See [aga-display.md](aga-display.md) for display evidence.

### Book-step presentation

The original Dan1 decreasing/increasing book loops build one page-fold position
through several immediate-mode QuickDraw calls. `bookFrameEdge` identifies their
existing Toolbox boundaries, checks the live original instructions and caller
frames, and holds presentation while dirty rectangles accumulate. No original
instructions are patched. This follows Vette's completed-frame presentation gate.

For decreasing folds, Dan2+$B46 (RGBForeColor), called from Dan1+$3FB4,
starts the batch; Dark+$1DBC (CopyBits), called from Dan1+$402C or +$405A,
finishes it. Increasing folds start with the leading copy at Dan1+$410A,
or the line helper at +$4162 when there is no leading copy. Their final strip
is Dan2+$D52 (PaintRect), reached through Dan2+$C8A from Dan1+$4182.
The final standalone copy after that loop retains normal presentation.
Each completed step passes its accumulated dirty rectangles to Kalms once;
VBI retains ownership of publishing the bitmap and copper list. Mouse, event,
audio and original VBL callbacks continue at their existing safe points.
Unexpected nesting, stack/caller bytes or a publication inside a batch stop
loudly. This boundary is specific to the proven book loops, not a generic
QuickDraw end-of-frame signal.

### Point setup

`SetPt` writes the two signed 16-bit coordinates in Macintosh vertical/horizontal
memory order and pops eight argument bytes. The original Dark+$4F88 call writes
only its four-byte point, preserves surrounding stack storage and all registers
except scratch A0, which returns the following instruction address. Null output
pointers retain a named stop. No original instruction changes or floating-point
operations are involved. `mac_setpt.lua`, `setpt.gdb` and `check_setpt.py` pair
that original call; Dark+$4F7A–$4F89 has SHA-256
`6e383555df80d58e37af9cd2bfa00fa3592060e1864a5782a2b4fde84d5bd102`.

### Empty regions

`NewRgn` allocates a real ten-byte handle in the current zone through the shared
heap allocator. Its bytes are `000a0000000000000000`: a ten-byte region with
an empty bounding rectangle. The handle is movable, unlocked and non-purgeable;
it participates in normal heap ownership and zone cleanup. Allocation failure
remains a named stop. The measured Misc2+$1DA6 call leaves the stack pointer
unchanged, writes its result handle into the reserved stack slot, returns the
body end in A0 and preserves the other registers.

`mac_newrgn.lua` queries the original result with CPU-executed GetHandleSize,
HGetState and HandleZone. `newrgn.gdb` verifies the native master slot, owning
block, logical length and flags; `check_newrgn.py` pairs the contracts. Original
Misc2+$1D9C–$1DA9 has SHA-256
`fb490c8d89ec18e2450bab69eff1861a43f579444050b9850a75e26b8c3390b7`.
`EmptyRgn` at Dark+$4182 queries an owned canonical empty ten-byte region.
It preserves its bytes and Boolean padding, writes true, and reproduces the
measured D1/A0/A1 results. Later M2 fixtures cover the nonempty forms reached
by the intro; unmeasured complex forms remain named stops.
`mac_emptyrgn.lua`, `emptyrgn_call.gdb` and `check_emptyrgn.py` retain the
original/native calling contract.
M2.8 acceptance is complete for reached screens. Broader region expansion is
tracked in M5; see [open-work.md](open-work.md).

See [offscreen worlds](gworld.md) for the real eight-bit allocation, private
device, owned auxiliary handles and measured inverse-colour lookup.

## Timing and input

The VBI advances `g_vbiCount` per PAL field and Macintosh Ticks at 60 Hz. CIA
input updates the live KeyMap and event queue; Amiga raw keys are translated to
Macintosh virtual keys, so held arrow keys are visible to original code that
polls GetKeys/KeyMap. Original VBL tasks run at safe user-mode trap-return
boundaries, never from the ISR. `FramePacer` remains available for
maximum-rate pacing of identified animation loops.

Keyboard ownership remains with the port during DOS windows, as it does for
music. Held keys and their event queue survive resource loading; a release
during a window is recorded normally. The window regression checks a key held
across eight reads, release inside the eighth window, and continued released
state through the remaining reads, alongside the existing guarded KeyMap tests.

`TickCount` reads the same private, unsigned 32-bit Ticks shadow as the original
redirected low-memory accesses. It preserves the existing counter and its wrap
behavior. The measured Dark+$41F4 call writes its stack result without popping
bytes, clears D1, returns the result-slot address in A1, and preserves the other
registers. A Mac scratch fixture confirms a full `$FEDCBA98` result and clears
all of a `$DEADBEEF` D1 input. No floating-point arithmetic is involved.
`mac_tickcount.lua`, `tickcount.gdb` and `check_tickcount.py` check the original
bytes, ABI, clock source and native field accounting. Original Dark+$41EC–$41F7
has SHA-256 `5e243de4915947497349652df6eab9bad8c9017ada06ca40f852a143ac6e82d1`.
The existing `window-core` regression also verifies clock continuity across
OS handbacks: the current run measured 407 PAL fields and 489 Mac ticks while
reading the exact 1 MiB fixture. This does not claim rendered-window acceptance.

## Audio

The Paula restart/quiesce primitives and `PaulaSample` (sampled-sound layout
preparation) are inherited. Vette's Bogas engine bridge is removed. This game
uses `snd ` resources and a MIDI synth driver (`MDRV`, `SONG`, `INST`), plus
.PAK sample and music lists; its Sound Manager usage is not mapped yet.

The original driver loader now selects port-owned Jnth 11 from the overlay.
Its four-byte `$A0F8; RTS` stub enters the user-mode service bridge, with the
original C argument/return convention. MoveHHi flushes the instruction cache
before the original caller executes it. The native driver implements measured
initialization/quality, raw effects and their status/stop, song control and gain,
SONG 131, 132, 135, 136 and 137 playback, track status and the full-width driver
clock query. Other selectors and unmeasured songs retain named loud stops.
Song resources are detached, locked and retained until release; original MDRV
and SMOD code never executes. Song loading prepares the pitch, DMA layout and
immutable PCM variants before playback. The default sequencer runs from a
resource-owned CIA-A timer at 60 Hz on a private 8 KiB stack; its interrupt
performs no allocation, sample conversion or original-code callback. The VBI
continues to drive the game clock and display, and original Mac VBL callbacks
remain in user mode. Main-thread audio ownership changes defer an interrupt
update until the outer ownership guard releases it. Four physical voices
use free channels then the oldest music voice, with effects taking priority.
See [sound-driver.md](sound-driver.md) for measured contracts and waveform
adaptations, and [music-resource-coverage.md](music-resource-coverage.md) for
all eight resource graphs. The remaining song/event and effect-variant
acceptance is tracked in [open work](open-work.md).

## Lifecycle

Shell and Workbench startup, the protected Workbench reply, allocation ledgers
and complete OS restoration are inherited. Deferred disk writes (save games)
belong after OS restoration, as Vette's score file established.

Framework modifications and upstream provenance are documented in
[`framework/UPSTREAM.md`](../src/platform/amiga/framework/UPSTREAM.md).
