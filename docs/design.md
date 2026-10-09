# Port design

The port runs the Macintosh Alone in the Dark 1.0 game on Amiga hardware. This document
records the architecture, owner decisions and overall plan. [Open work](open-work.md)
contains only unresolved tasks; completed work and superseded experiments belong in Git
history.

Evidence is measured from original bytes/runs unless explicitly described as inference.
Addresses use (segment, offset), including the four-byte CODE header.

## 1. Goal and target

Preserve original game decisions while implementing the Macintosh services they call,
AGA display, Paula audio and Amiga input. The executable targets 68020 without an FPU.
The verified minimum configuration is 2 MB Chip and 8 MB Fast RAM with AGA; 68030 or
better is recommended. Native development uses Kickstart 3.1, and the release uses a
WHDLoad Kickstart slave.

The display is 320×200, eight bitplanes and 256 colours. Only the low-resolution game
viewport is exposed. The reference is a Mac IIx/68030 with System 7.5.5, 8 MB RAM and an
eight-bit mdc48 display in MAME. The fixed-clock Amiga comparison uses 15.6672 MHz;
emulation and memory timing still differ between machines.

## 2. Original program

The THINK C far-model application has a 468-entry CODE 0 jump table, with 75,616 bytes
below A5 and 3,776 above. CODE 1 expands DATA/ZERO, applies DREL, installs
LoadSeg/UnloadSeg/ExitToShell patches and relocates later CODE through CREL. The port
leaves those original decisions in charge.

The renderer writes eight-bit offscreen GWorld pixels and publishes them through
CopyBits. World data comes from PAK/ITD files; the original decompresses it. GetKeys
drives movement, WaitNextEvent drives events, and the game's engine provides the reached
inventory/new-game/save/load interfaces. SANE positioning operations use integer
implementations. See [static-map.md](static-map.md) and
[source-inventory.md](source-inventory.md) for exact sizes and resource layout.

## 3. Development principles

- Implement measured contracts; unknown services remain named loud stops.
- Guard every binary hook with original-byte checks and preserve registers/CCR.
- Compare matching game states, not frame numbers or host elapsed time.
- Require positive completion; a timeout or unreached probe is never a pass.
- Profile the whole frame before optimizing. Record rejected experiments in Git.
- Keep reusable fixtures and concise technical docs; keep captures in ignored
  local storage. Vette is the reference for inherited runtime conventions.

## 4. Runtime architecture

### 4.1 CPU and machine ownership

The Mac program runs in user mode on a private 64 KB stack. The Amiga process uses its
normal 4 KB stack. Line-A services that call the OS return through a user-mode bridge;
recursive service entry or unsupported exception frames stop explicitly. OS traps set
CCR from D0.W as the original dispatcher does; Toolbox traps preserve their specified
condition-code behavior. Original callbacks run at safe user-mode boundaries, never
directly from an Amiga interrupt.

Native file operations open bounded system windows: restore OS scheduling and vectors
while retaining display/audio/input continuity, perform the operation, and retake the
machine. WHDLoad uses resload and needs no OS window for reads. All resources, vectors
and devices are restored on normal Quit.

### 4.2 Loader and memory

CODE 1 starts in its original unloaded/loaded jump-table layout and owns CREL
relocation. The port validates all original CODE sizes/fingerprints and patch bytes
before takeover and rechecks copied CODE before patching.

All 58 live low-memory operands are redirected to an A5-relative private shadow; Mac
Page 0 is never mapped over Amiga vectors. The preferred 3,145,728-byte application zone
has movable handles, nonrelocatable pointers, lock/purge/resource flags, compaction and
real allocation errors. A separate system zone owns the runtime stubs. Port
display/audio buffers do not consume the Mac application zone.

### 4.3 Files and resources

Data is read on demand. Catalog metadata and resource maps are retained; resource bodies
load lazily into owned handles. Mac forks, Finder metadata, permissions, current
resource file and search order retain their measured semantics. The port-owned overlay
supplies native driver/font resources without modifying original data. Save writes are
durable through the native or resload backend. See [file-manager.md](file-manager.md)
and [installation](install-original-data.md). WHDLoad's optional PRELOAD caching is
external to the port's on-demand file API.

### 4.4 Display and geometry

The logical Mac screen is 640×480 at eight bits; AGA presents its live 320×200 game
client rectangle. AitdScreen owns the display registers, double buffers and copper
lists. It publishes display and sprite pointers first in VBI.

Convert only dirty rectangles after the original publishes a complete frame. Book and
scene batching identify measured Toolbox boundaries and caller frames; they do not
change the original engine's movement or drawing decisions. There are no chunky
shadow-framebuffer comparisons. Palette conversion follows table seed changes. Region
rows and masks preserve original parity, signed bounds, clipping and aliasing. See
[amiga-arch.md](amiga-arch.md), [CopyBits](copybits.md) and [regions](rectangles.md).

### 4.5 Input, interfaces and fonts

VBI samples keyboard/mouse transitions. The game viewport has no visible pointer:
its retained interfaces use the keyboard. Logical Mac hide/show/obscure state and
mouse-button semantics remain implemented, independently of display visibility.
Events and Command-key items use measured contracts; Right-Amiga maps Command.
The menu bar and screen-size chooser are suppressed. The verified Escape-menu
handback waits for physical Escape release so one held press cannot immediately
reopen the menu; event flushing leaves live KeyMap state intact.

Reached Save/Load, inventory and reading use the engine interfaces. Additional Mac
dialogs require a measured in-game replacement; do not invent success to skip a missing
service. Times/plain/14 and Times/plain/36 raw glyphs provide visible Mac-font text;
keep the engine font where the engine uses it.

### 4.6 Audio and clocks

The game selects the overlay's native Jnth 11 SoundMusicSys entry; original MDRV/SMOD
code does not execute. Songs and PCM variants are prepared in user mode before playback.
A resource-owned CIA-A timer drives the native sequencer at 60 Hz on a private 8 KB
stack. It performs no resource access, conversion, allocation or original-code
callbacks. VBI still supplies input, display and the 60 Hz game clock (6/5 ticks per PAL
field, one per NTSC field).

Four Paula voices allocate music around priority effects. The reached eight song graphs
and effect variants have explicit contract tests. Voice limits are intentional under D8.
See [sound-driver.md](sound-driver.md), [music coverage](music-resource-coverage.md) and
[audio regression](audio-regression.md).

### 4.7 Lifecycle and packaging

Original Quit reaches the patched ExitToShell path, drains durable writes, restores the
OS and returns through Shell or Workbench startup. WHDLoad F10 is an immediate exit that
bypasses that game path.

The Installer extracts/verifies original data from the user's StuffIt archive. The slave
runs the port under Kickstart 3.1; packaging includes only port-owned release files,
icons and the helper license. The installer and ReadMe follow the WHDLoad 20.0 Install
Template and Vette's Installer V43 flow.

## 5. Owner decisions

Changes to these decisions or original game behavior require the owner.

| ID | Decision |
| --- | --- |
| D1 | No port-side preloading: read in bounded chunks and allow the OS to run when needed. |
| D2 | 68020/no-FPU executable minimum; use fixed-clock 68030 for comparable-Mac intro measurements. Maximum-speed configurations are for functional diagnostics. |
| D3 | Global VBlank pacing, explicitly authorized by the owner after reproducing the high-speed stair reversal: at most one complete frame per PAL/NTSC field, including gameplay, publisher animation and book turns. Preserve original game logic and do not wait per polygon or drawing trap. |
| D4 | No screen-size dialog; only 320×200. |
| D5 | Replace reached Mac dialogs with measured in-game interfaces inside the viewport, preserving their choices and actions. |
| D6 | Retain engine fonts; bundle raw bitmaps of the original Mac fonts for Mac-font text. |
| D7 | No Mac menu bar or visible mouse pointer; keyboard controls and Right-Amiga Command shortcuts. Preserve original mouse-button/event semantics. |
| D8 | Native SoundMusicSys driver on Paula channels, rather than software mixing. |
| D9 | Omit the standalone MACPLAY splash and its delay. First visible game picture is Infogrames; retain the book credits. |

## 6. Verification

| Change | Required evidence |
| --- | --- |
| Pure helper | Host checks, including rejection/boundary cases |
| Loader or binary hook | Original-byte guards, register/CCR preservation and bounded native completion |
| New service | Original arguments/results and native call-site acceptance |
| Display | Matching game state, full indexed viewport/CLUT and actual AGA publication |
| Audio | Original selector/event/voice contracts, native DMA/interrupt ownership and release |
| Performance | Matched scenario in guest ticks/fields, pinned CPU settings and explicit profiling overhead |
| Installer/release | Extraction hashes, real Installer test, WHDLoad execution and independent archive checks |

Reproduction commands, CPU/video configurations and acceptance limits are in
[testing.md](testing.md). Functional 040/060 stairs/quit coverage is not a claim of
complete hardware acceptance on every accelerator.

## 7. Overall plan

The milestone structure remains the project's scope map, not its work queue.

| Phase | Scope |
| --- | --- |
| M0 | Analysis tools, original reference loop and reproducible builds |
| M1 | Original startup, loader, low memory and system services |
| M2 | Files/resources, startup, intro and AGA presentation |
| M3 | Play, input, interfaces and save/load |
| M4 | Music, effects and native audio contracts |
| M5 | Measured performance, CPU configurations and memory requirements |
| M6 | Full-route, rendering, ending, stairs and quit acceptance |
| M7 | Original-data installer, WHDLoad slave and release archive |

Use [open-work.md](open-work.md) for the actual remaining tasks and Git history for
completion records.

## 8. Workflow

Work the open queue in order unless the owner directs otherwise. Read the relevant
contracts and original bytes, implement one coherent change, and validate
proportionally. After two failed hypotheses, instrument before guessing again. Update
affected docs and remove completed work from the queue. Commit directly on main with the
existing repository identity, no signing, hooks or co-author trailers, and no global Git
configuration changes.

## 9. Continuing risks

Original timing-dependent movement, unreached service variants and hardware
memory/timing differences need bounded reproduction, not guessed fixes. Preserve saves
during tests, keep IRQ stack/latency checks when changing audio, and verify
system-window continuity when changing native I/O. Performance work must account for the
original renderer and synchronous resource preparation, not just one trap.

## 10. Static invariants

CODE 0 has 468 entries; DATA/ZERO/DREL sizes are 11,418/560/678 bytes with 276 DREL
entries. CREL has 7,329 entries (7,210 A5 and 119 STRS). The live census contains 1,129
sites and 244 distinct trap words. The original application resource fork is 1,424,934
bytes. Checksums and installed file metadata belong in the maintained extraction
manifest and source inventory.

## 11. Trap census

`make trap-census` generates `tmp/trap-census.md` from original data.
`tools/trap_census.py`, curated entrypoints and original-byte checks are the source of
truth; do not keep a second handwritten live-site table here.
