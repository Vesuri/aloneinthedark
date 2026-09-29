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

`AitdScreen` retains the bootstrap four-plane crop with a single cursor sprite
buffer; the alternate display mode and field-parity probes are removed. It
currently draws 16 colors from a packed
4-bit 512×320 Macintosh surface, with a double-buffered chip-RAM bitmap, copper
lists published in VBI, an explicit dirty-rectangle list and a hardware-sprite
mouse pointer. Alone in the Dark draws 8-bit pixels through a 256-entry `clut`,
so the surface, C2P kernel and palette path must move to eight planes (AGA). The
dirty-rectangle and VBI publication rules stay. Per-window crops are keyed by the
original WIND ID; none are mapped for this game yet.

## Timing and input

The VBI advances `g_vbiCount` per PAL field and Macintosh Ticks at 60 Hz. CIA
input updates the live KeyMap and event queue; Amiga raw keys are translated to
Macintosh virtual keys, so held arrow keys are visible to original code that
polls GetKeys/KeyMap. Original VBL tasks run at safe user-mode trap-return
boundaries, never from the ISR. `FramePacer` remains available for
maximum-rate pacing of identified animation loops.

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
