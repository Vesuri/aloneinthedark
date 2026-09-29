# Amiga architecture

The runtime is Vette!'s, with its game-specific hooks removed. This page records
what is inherited unchanged, what was generalised, and what must change for this
game. Vette's `docs/amiga-arch.md` has the complete rationale for the inherited
parts.

## Original game and compatibility layer

`PlatformAmiga` reads the application's raw resource fork from `PROGDIR:data/`
or `PROGDIR:` before hardware takeover, then takes the machine over in the order
established by the earlier ports (LoadView(NULL), display DMA down, VERTB vector
taken over, screen built, published to the ISR, DMA up, Forbid, run, restore in
reverse). The Workbench startup message is handled as in Vette.

`MacLoader` copies every CODE resource into aligned resident storage, allocates
the A5 world from CODE 0's sizes, resolves the jump table to absolute jumps and
enters the first entry in user mode with the Line-A handler on vector $28. Loader
failures and unimplemented traps are named loud stops painted by `AitdScreen`;
the VBI keeps running so the report stays visible. See [static-map.md](static-map.md).

Page-0 globals the original touches are redirected, after byte checks, to the
private `s_portLowMemory` block (Ticks, RndSeed, WMgrPort, GrayRgn, KeyMap,
CurrentA5, mouse and button state). The VBI keeps Ticks at 60 Hz and the mouse
shadows current. No redirections are installed yet for this game.

The Memory, Resource, QuickDraw (PICT, CopyBits, GWorlds), Palette, Window,
Menu, Dialog, Event, Vertical Retrace and Trap Manager services are Vette's
implementations. They cover what Vette called and nothing more; each new call
Alone in the Dark makes arrives as a loud stop.

## Display

`AitdScreen` owns one 320×200 eight-plane display, using the live WIND 128
content rectangle within the 640×480×8 logical Mac screen. Each chip bitmap
contains 200 interleaved rows of eight 40-byte planes (64,000 bytes). Explicit
dirty rectangles align to 32 destination pixels. The back bitmap inherits the
previous frame's changed spans before receiving the new changes.

Main-thread conversion prepares the inactive bitmap and complete copper list.
VBI swaps both together before input/audio work. The list includes all 256
RGB24 colours, using BPLCON3 banks and high/low nibble writes. An integer lookup
reproduces the measured Mac video transfer while preserving the logical RGB16
CLUT. The current mode is PAL, with one-times fetch; NTSC and visible-pointer
palette ownership remain M2.5 requirements. The pointer stays hidden for this
startup path. See [aga-display.md](aga-display.md) for evidence and limitations.

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
Broader region operations and clipped drawing remain M2.8 work.

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
before the original caller executes it. The native state implements only the
measured initialization and quality selectors; all others stop explicitly.
MDRV loading remains forbidden. See [sound-driver.md](sound-driver.md) for the
byte-verified seam and paired startup contracts; playback remains M4.

## Lifecycle

Shell and Workbench startup, the protected Workbench reply, allocation ledgers
and complete OS restoration are inherited. Deferred disk writes (save games)
belong after OS restoration, as Vette's score file established.

Framework modifications and upstream provenance are documented in
[`framework/UPSTREAM.md`](../src/platform/amiga/framework/UPSTREAM.md).
