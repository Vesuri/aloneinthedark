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

### Intro performance investigation (2026-10-02)

M2 functional/rendered acceptance does not establish acceptable frame rate or
transition latency. The owner recording contains a nearly unchanged interval
at 334.2–348.9 seconds (14.7 seconds), immediately before the entrance-hall
camera changes to the stair view. Frames at 337 and 345 seconds show the same
character position; at 350 seconds the next view has appeared. This is separate
from the 7.95-second menu-to-landscape black interval. Video analysis and
extracted frames are local under `tmp/m2-owner-video/`. The white cache-window
interruption is not used as performance evidence.

The original investigation used a cycle-exact PAL A1200 at
14,187,580 Hz with 8 MB fast RAM; host CPU speed does not remove that limit.
Diagnostics before the region expansion change (`INTROSKIP=1 PROFILEFRAME=250 PROBEFIELDS=300`)
identify room 0/camera 1, then measure publications 250–253 over 300 PAL fields.
`tmp/m2-performance-car-native-full.log` exits 0; the trap arrays are archived
under `tmp/m2-performance-car/`. C2P accounts for 445,662 of 24,036,231 beam
units (1.85%). There are also 94 Read dispatches and substantial memory,
drawing and sound-driver dispatch activity. These are inclusive instrumented
service counts, not disk-read counts or a shipping FPS benchmark. They show
that this sample includes preparation work; they do not isolate steady 3D
rasterization from scene loading. Nested categories must not be added together.

The earlier `m2-mask-spans-profile-full.log` sample attributed 14,256,985 of
24,022,099 units (59.35%) to four InsetRgn calls. The relevant implementation
called `RegionRows::row` up to three times for every output row, and each
call traversed the full region stream. That repeated decoding was a concrete
CPU bottleneck, not an intentional scene delay. It is not proof that every
recorded pause has the same cause. Attribution
of complete transitions and a separate steady-rendering profile remain open
under M5.1.

The selected comparison machine is now `a4000-030-reference`, a 68030 at
15.6672 MHz matching MAME's Mac IIx clock. FS-UAE's `~cycle-exact` timing and
different memory systems remain limits on exact hardware equivalence.
Region expansion now uses three validated forward cursors: each neighbour
consumes the region transitions once, rather than rescanning them on every row.
The first pond expansion falls from 17 game ticks to 1 on this configuration
(`tmp/intro-030-inset-{before,after}-full.log`, both exit 0). The same original
Mac call begins and ends in tick 20913 (`tmp/intro-030-inset-mac.log`, exit 0).
These are coarse 60 Hz tick measurements of one operation, not whole-scene
speedups. All 244 result bytes match the original, with unchanged ownership,
register contract, port and pixels. Host checks include a tall region with
many transitions and empty gaps, plus atomic rejection of an invalid tail.
The helper reserves 4,436 bytes instead of 4,296; the dispatcher reserves 328.
A read-only interrupt observation in the complete demo run records a minimum
928 bytes above the system-stack lower bound at mouse-VBI entry. That run
(`tmp/intro-030-route-after-full.log`, exit 0) completes all nine room changes
without further input after the normal book skip. The full host suite passes
in `tmp/intro-030-region-host-tests.log`. A remaining 753-tick (12.55-second)
gap between room 2/camera 5 and room 2/camera 3 requires separate attribution;
the region fix does not close the overall intro performance goal.

The corresponding Mac IIx run (`tmp/intro-030-route-mac-retry.log`, exit 0)
completes the original demo as well. At the original Dark+$5658 loop entry,
the room 2/camera 5 → camera 3 checkpoint gap is 97 ticks (1.617 seconds),
versus 753 ticks (12.55 seconds) on Amiga. The first two camera-5 loop entries
are 55 ticks apart on Mac and 504 on Amiga (0.917 versus 8.4 seconds).
These identify substantial port-side scene costs. Both runs use natural game
entropy: actor trajectories and loop counts differ, so total demo duration
and room/camera median loop times are not exact state-paired FPS comparisons.
The initial Mac observer stopped before measurement because Dark was not yet
loaded; only the successful retry is accepted evidence.

A scene-triggered profile (`INTROSKIP=1 PROFILEROOM=2 PROFILECAMERA=5
PROBEFIELDS=1500`) avoids selecting the wrong scene when natural car trajectories
change the publication count. `tmp/intro-hall-detail-full.log` exits 0 after
1,500 PAL fields: 120,173,863 beam units, 34 publications, ending in camera 3.
Nested region decoding accounts for 2,930,467 units (2.44%); resizing the region
handle accounts for 39,603,949 (32.96%). These scopes separate the geometry from
the Memory Manager work inside InsetRgn; they must not be added to its inclusive
trap cost. CopyBits accounts for a further 13,192,684 units (10.98%).

Unlocked handle growth now uses an already-available replacement block before
trying MoveHHi and heap compaction. Only the small source payload needs copying
in that case. Locked handles retain their in-place rules, and fragmented heaps
retain the compaction fallback. Sanitizer checks cover small growth beside a
large live allocation, preserved state/data, locked neighbours and failed
growth. The full host suite (`tmp/intro-heap-grow-host-tests.log`) and native
Memory Manager fixture (`tmp/intro-heap-grow-native.log`, all three stages)
pass. The unprofiled repeat (`tmp/intro-heap-grow-route-full.log`, exit 0)
completes all nine room transitions with a minimum observed mouse-VBI stack
margin of 928 bytes. Camera-5 initial setup falls from 504 to 180 ticks
(8.4 → 3.0 seconds), and camera 5 → 3 falls from 753 to 240 ticks
(12.55 → 4.0 seconds). Both remain slower than the Mac measurements above;
the overall performance goal remains open.

The subsequent six-second setup profile (`tmp/intro-hall-after-full.log`,
exit 0) attributes only 209,968 of 24,034,708 beam units to 18 region resizes
(0.87%), but 4,315,494 to 586 heap publications (17.96%). The free-master list
was being rebuilt even when no slot had been allocated or disposed. A private
dirty flag now limits rebuilding to those membership changes, including failed
handle allocations and newly allocated master blocks. Master blocks are pinned,
so moving data or changing lock/purge flags cannot invalidate their links.
Tests verify the actual published chain and allocation order, not just payloads.
Host and native heap checks pass. The unprofiled full demo
(`tmp/intro-master-list-route-full.log`, exit 0) again completes all nine room
changes; initial hallway setup is 146 ticks (2.433 seconds), and camera 5 → 3
is 199 ticks (3.317 seconds). Matching Mac values remain 55 and 97 ticks.

Matched-input frame checks after these changes pass all 64,000 viewport pixels,
256 colours and actual AGA publication for both car and frog
(`tmp/intro-demo-publish-full.log`, `tmp/intro-{car,frog}-timing-mac.log`, all
exit 0; `tools/check_demo_model_replay.py`). The final car sample takes 20 native
ticks versus 11 on Mac from Dark+$3ED4 to the next +$5658. The first close-up
frog sample takes 88 versus 10. These spans include work after the actor draw;
the replay pairs model geometry and transform, not every actor or scene-cache
state. In particular, do not interpret the frog ratio as steady renderer FPS.
The natural-route first camera-3 loop gap is 99 native ticks versus 27 on Mac.

The scene-triggered frog profile (`tmp/intro-frog-profile-full.log`, exit 0)
covers 150 PAL fields and one publication. Of 12,015,539 beam units, nested
region geometry is 642,701 (5.35%), region resizing 64,517 (0.54%), heap
publication 1,214,578 (10.11%), and CopyBits 435,966 (3.63%). These overlapping,
instrumented scopes identify remaining costs; they are not shipping timings.
The overall performance and owner-visible playback acceptance remain open.
The retained changes also pass the full song regression
(`tmp/intro-final-song-full.log`, exit 0): 3,736 exact timed events, 25 retained
PCM variants totalling 458,974 bytes, effect priority, natural completion and
resource/voice cleanup. This verifies sequencing and bytes, not listening quality.

An earlier native frame observer stopped with pending logical pixels at
Dark+$5658 (`tmp/intro-perf-frames-native-full.log`, exit 1). Presentation runs
at safe trap boundaries and can defer while a bitmap awaits VBI. The successful
repeat above reached every selected frame with no pending logical pixels and
proved unchanged pixels through publication; it did not reproduce that failure.
Do not count the failed run as a pass or infer a display bug solely from that
checkpoint. Any reproduced deferral still needs its delay and image checked.

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
