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

M2 functional acceptance does not establish acceptable animation or transition
latency. P1 remains open before M3. The selected `a4000-030-reference` uses a
68030 at 15.6672 MHz, matching the MAME Mac IIx CPU clock, with 8 MB fast RAM,
AGA and no JIT. FS-UAE's approximate 68030 cycle timing and the different memory
systems limit exact hardware equivalence. A controlled data-cache toggle did
not remove the cold-mask stall; the default configuration remains unchanged.
Performance claims below use unprofiled game ticks (60 Hz), not host time.

| Checkpoint span | Amiga ticks | Mac ticks |
| --- | ---: | ---: |
| Matched near-car renderer call, VBI-music build | 15 | 12 |
| Same near-car draw → next original loop, VBI-music build | 18 | 12 |
| Natural first frog mask construction | 35 | 11 |
| Natural first frog loop → next loop | 59 | 27 |
| First two hallway loop entries, room 2/camera 5 | 105 | 55 |
| Last hallway loop → first stair-view loop, camera 5 → 3 | 141 | 97 |

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
initialization/quality, raw effects and their status/stop, the song control word,
SONG 135 start/playback, track status and the full-width driver clock query. Other selectors and unmeasured song forms stop.
Song resources are detached, locked and retained until release; original MDRV
and SMOD code never executes. Due music work defers the current trap through
the existing user-mode bridge before allocating or programming Paula. The VBI
supplies ticks; no original callbacks run in an interrupt. Four physical voices
use free channels then the oldest music voice, with effects taking priority.
See [sound-driver.md](sound-driver.md) for the measured seam, state/event checks
and waveform adaptations; broader songs and toggles remain M4.

## Lifecycle

Shell and Workbench startup, the protected Workbench reply, allocation ledgers
and complete OS restoration are inherited. Deferred disk writes (save games)
belong after OS restoration, as Vette's score file established.

Framework modifications and upstream provenance are documented in
[`framework/UPSTREAM.md`](../src/platform/amiga/framework/UPSTREAM.md).
