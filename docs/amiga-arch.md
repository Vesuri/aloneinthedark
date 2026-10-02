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

The baseline launcher deliberately emulates a cycle-exact PAL A1200 at
14,187,580 Hz with 8 MB fast RAM; host CPU speed does not remove that limit.
Current-build diagnostics (`INTROSKIP=1 PROFILEFRAME=250 PROBEFIELDS=300`)
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
still calls `RegionRows::row` up to three times for every output row, and each
call traverses the full region stream. That repeated decoding is a concrete
CPU bottleneck, not an intentional scene delay. It is evidence for the existing
M5.2a work, not proof that every recorded pause has the same cause. Attribution
of complete transitions and a separate steady-rendering profile remain open
under M5.1. No production optimization was made during this investigation.

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
