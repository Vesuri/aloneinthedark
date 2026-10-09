# Amiga architecture

The compatibility runtime follows Vette. Original-byte and service contracts are
documented by subsystem; [design.md](design.md) records the owner decisions.

## Original game and compatibility layer

PlatformAmiga opens the application resource fork under `PROGDIR:data/` or `PROGDIR:`,
retaining its map and streaming bodies into owned handles. MacLoader validates CODE
bytes and leaves original CODE 1 responsible for DATA/ZERO/DREL, segment loading and
CREL relocation. Original code runs in user mode through the Line-A service bridge.
Named loader/trap stops retain VBI display so their reports remain visible. See
[static-map.md](static-map.md).

Mac low-memory operands use an A5-relative private shadow; they never overwrite Amiga
Page 0. The VBI maintains Ticks and input shadows. MacHeap provides the
application/system zones and movable handle semantics. The game has a separate 64 KB Mac
stack, while the Amiga process needs the normal 4 KB stack.

## Display

AitdScreen owns bitplanes, copper, sprites and registers. The logical Mac screen is
640×480×8; the live WIND 128 client selects the 320×200 AGA viewport. Physical output
uses double-buffered eight-plane Chip RAM. VBI publishes complete display and sprite
pointers before input/audio work.

QuickDraw retains exact indexed-colour and region semantics. The native presentation
gate accumulates dirty rectangles until the original has published a complete scene.
Only changed spans are converted with Kalms C2P; palette work runs on table-seed
changes. There is no chunky shadow compare. Scene completion checks the original
caller's stack/frame identity, with `SCENEFRAMEVERIFY=1` available as an independent
diagnostic. Unexpected batching states stop loudly.

### Book-step presentation

The original Dan1 decreasing/increasing book loops build one page-fold position through
several immediate-mode QuickDraw calls. `bookFrameEdge` identifies their existing
Toolbox boundaries, checks the live original instructions and caller frames, and holds
presentation while dirty rectangles accumulate. No original instructions are patched.
This follows Vette's completed-frame presentation gate.

For decreasing folds, Dan2+$B46 (RGBForeColor), called from Dan1+$3FB4, starts the
batch; Dark+$1DBC (CopyBits), called from Dan1+$402C or +$405A, finishes it. Increasing
folds start with the leading copy at Dan1+$410A, or the line helper at +$4162 when there
is no leading copy. Their final strip is Dan2+$D52 (PaintRect), reached through
Dan2+$C8A from Dan1+$4182. The final standalone copy after that loop retains normal
presentation. Each completed step passes its accumulated dirty rectangles to Kalms once;
VBI retains ownership of publishing the bitmap and copper list. Mouse, event, audio and
original VBL callbacks continue at their existing safe points. Unexpected nesting,
stack/caller bytes or a publication inside a batch stop loudly. This boundary is
specific to the proven book loops, not a generic QuickDraw end-of-frame signal.

## Timing and input

The game clock is 60 Hz: PAL VBI adds six ticks per five fields; NTSC adds one per
field. Complete frames are paced by real VBI fields (50 Hz PAL, approximately
60 Hz NTSC), independently of the logical 60 Hz game clock. The display owner
waits only if the preceding frame used the same field or still awaits publication.
Scene/book batching supplies complete-frame boundaries, including scenes with no
dirty pixels; unbatched screen updates use the same gate. Slower rendering adds no
fixed delay. Interrupts continue servicing display, input and music while waiting.
Original Core/Dark VBL tasks run at safe user-mode
boundaries and preserve the original callback ABI. They never run inside the native VBI
or music interrupt.

Keyboard transitions and held states survive bounded OS windows. VBI also updates the
hardware mouse pointer independently of game frame rate. Its two sprite banks preserve
all game colours, and cursor inversion follows the original masks. See
[events.md](events.md) and [cursor.md](cursor.md).

TickCount writes its long result at entry SP without consuming it, clears D1, returns
the result-slot address in A1 and preserves the other registers. `tickcount.gdb`,
`mac_tickcount.lua` and `check_tickcount.py` verify this contract.

## Audio

The overlay's Jnth 11 entry (`$A0F8; RTS`) enters the native SoundMusicSys bridge.
Original MDRV and SMOD code never execute. Song loading owns and prepares all resources
and immutable PCM variants before enabling playback. The CIA-A timer runs the sequencer
at 60 Hz on a private 8 KB stack; no allocation, conversion or original callback occurs
there. Ownership changes defer an IRQ update until the outer guard releases it. Effects
have priority over music on four Paula voices. See [sound-driver.md](sound-driver.md)
and [music coverage](music-resource-coverage.md).

## Embedded port resources

The generated `resources/overlay.rsrc` is linked verbatim into `AloneInTheDark`.
Its bounded memory-source callback preserves resource-map lookup and lazy handle
loading without DOS or resload reads. The original game resources still stream
from disk. Overlay counters describe memory-source reads and its logical lifetime,
not OS file handles or system windows. The installer needs no separate overlay.

## Files and lifecycle

Native reads/writes use bounded user-mode system windows. WHDLoad reads use
`resload_LoadFileOffset` and saves use `resload_SaveFile`, through the same file
interface. Original game and resource bodies remain on-demand; PRELOAD is a WHDLoad
cache choice. Saves and preference writes are durable at their measured
close/publication points rather than waiting for process termination.

Normal Quit follows the original exit patches, drains pending work, stops DMA and
timers, restores OS vectors/display/input state, releases owned resources and replies to
Workbench when required. The slave's immediate F10 exit is separate from this path.
Framework modifications are documented in
[UPSTREAM.md](../src/platform/amiga/framework/UPSTREAM.md).

## CPU acceptance and memory requirement

The verified minimum is AGA with 2 MB Chip and 8 MB Fast RAM. Fixed-clock 68020/68030
pass intro and first-floor tests. Stairs and quit additionally cover all eight named CPU
configurations in PAL/NTSC; this is not complete hardware acceptance for every
accelerator. Four MB Fast fails startup even in production; intermediate configurations
such as 6 MB were not measured.

| Allocation measured during intro/first-floor tests | Peak bytes |
| --- | ---: |
| Application-zone occupied space including metadata | 2,373,856 |
| System-zone occupied space | 304 |
| Port dynamic Chip allocations | 591,696 |
| Port dynamic Fast allocations | 3,596,256 |

Zone occupancy is already inside the Fast total. These totals exclude the executable and
unrelated OS allocations, and are not exhaustive endgame peaks. The game-process stack
uses about 2.1 KB of its 4 KB allocation on measured Shell/Workbench/WHDLoad gameplay,
Save/Load and exit paths. Private Mac and music stacks are separate. Keep large
temporary buffers off the exception stack.

## Interrupt checks

The first-floor endurance audit completes more than ten minutes with zero input drops or
late logical note deadlines. Its worst measured music interrupt is 6.337 ms including
probe overhead; maximum CIA entry lateness is 0.715 ms. Private music/deferred stacks
retain 7,848/8,096 bytes of their 8,192-byte budgets. A same-song interval of 97 music
ticks without a trap safe point demonstrates independent IRQ progress. Song
replacement/preparation gaps must not be counted as continuous playback of one song. Use
`m5_circuit.gdb` and `check_m5_audit.py` when modifying interrupt ownership, memory or
safe points.
