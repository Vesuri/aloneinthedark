# Port design

This is the plan for taking the port from "stops at CREL" to a released game.
It fixes the architecture, the target, the verification method and the phase
order. The concrete work queue is [open-work.md](open-work.md). Finished work
lives in the Git log, not here: when a decision below is implemented, the
section stays only as long as it describes current behaviour.

Evidence tags: **[M]** measured from bytes or runs, **[D]** derived from
measured facts, **[I]** inference to be confirmed. Addresses are
(segment, offset) with the four-byte CODE header included.

## 1. Goal and target

A complete, faithful Amiga version of Alone In The Dark 1.0 for the Macintosh.
The original 68k instructions run unchanged; the port supplies the Macintosh
services they call, AGA display, Paula audio, and Amiga input.

| | Minimum | Also tested |
| --- | --- | --- |
| CPU | 68020 | 68030, 68040, 68060 |
| Chipset | AGA | AGA |
| Fast RAM | about 4–6 MB, measured in M5 | 8 MB, 16 MB |
| OS | Kickstart 3.1 | WHDLoad |

- **68020 is the floor and must boot and play** (D2). The game uses 68020
  instructions [M: 319 on reachable paths], and the original Mac recommended
  a 68040 [external: Inside Mac Games listing]. Make it run as well as
  possible everywhere: every performance change is measured on the A1200
  68020 configuration as well as on the 68030.
- **No preloading** (D1). Data and resources are read on demand, in chunks,
  with the operating system allowed to run for the read (4.5), so fast RAM
  holds only the 3 MB application zone, the port and the display.
- **Display: 320×200, lores, 8 bitplanes, 256 colours.** Only the game's
  320×200 mode is supported (WIND 128); the 640×400 mode (WIND 132) is not.
- **Reference machine.** The emulated Mac IIx (68030), System 7.5.5, 8-bit
  mdc48 card, 8 MB RAM, in MAME ([mac-reference-loop.md](mac-reference-loop.md)).
  Every Gestalt, SysEnvirons and version answer the port gives is the answer
  that machine gives, so the original takes the same paths.

## 2. What the original is

Measured facts the design depends on. Details are in
[static-map.md](static-map.md) and [source-inventory.md](source-inventory.md).

- **THINK C far model.**
  - CODE 0 is a 468-entry jump table, with 75,616 bytes below A5 and 3,776 above.
  - CODE 1 is the runtime. It expands `DATA`/`ZERO` into the A5 world, applies
    `DREL`, and patches `_LoadSeg`, `_UnloadSeg` and `_ExitToShell` with its own
    handlers. Its `_LoadSeg` handler applies `CREL` and fills the jump table.
  - The system `_LoadSeg` is never called once CODE 1 has run [M].
- **Graphics.**
  - The 3D engine renders into GWorlds (QDOffscreen `$AB1D`) and writes their
    pixels directly through `GetPixBaseAddr`.
  - Frames are presented with `CopyBits` srcCopy from a GWorld to the window.
    There are 7 such sites, with 4-pixel-aligned x [M].
  - The palette is `clut` 128, set through `NewPalette(256, pmTolerant+pmExplicit)`,
    `SetPalette(-1)` and `ActivatePalette`. There is no `AnimatePalette` or
    `SetEntries` [M].
- **Data.**
  - The world data is Infogrames `.PAK`/`.ITD` files in `:Alone Data:`, 5.2 MB.
  - They are read through THINK C's unix layer (Misc3 JT95–99) on top of
    `_Open`, `_Read`, `_GetEOF`, `_SetFPos` and `_Close`.
  - `.PAK` is the PC container (little-endian offset table; stored, implode or
    deflate entries); the game decompresses it itself [external: FITD].
- **Music: Halestorm SoundMusicSys** (replaced by a native driver, 4.10).
  - The driver is `MDRV` 11 "MIDI Synth 3.32". It is encrypted and
    LZSS-compressed, and the game unpacks it at Core+$10CC.
  - It mixes 8-bit mono audio at 22,254.5 Hz into two 370-byte buffers through
    `SndPlayDoubleBuffer`, but only if `SndSoundManagerVersion` is at least 3.0.
    Otherwise it touches the Mac sound hardware directly [M].
- **Input.**
  - `GetKeys` is called once per frame (Dan1 JT166) to read directions and actions.
  - `WaitNextEvent` drives the main loop, with menus, `MenuKey`, Apple Events and
    `SystemClick`.
  - Load and save go through File-menu dialogs (DLOG 200/201/212).
- **Timing.**
  - `TickCount` is called at 27 sites, and `Ticks` is read directly for the game
    clock.
  - Two VBL tasks: Core's task runs through a 12-byte stub the game *generates*
    in a system-heap block, and Dark's task only re-arms itself.
  - There is no Time Manager. The engine logic runs in 60 Hz ticks [external: FITD].
- **Floating point.** SANE (`FP68K`) is used at 10 sites, all in Engine
  $47C2–$4852.
- **68020 code.** Dark2 (179 sites), Misc2 (93) and Dark (55) use 68020 addressing
  modes, bitfields and `MULU.L`. The hot rasteriser in Dark3 uses 16-bit
  arithmetic [M].

The complete trap census is in section 11. The maintained
`tools/trap_census.py` generates its site table with `make trap-census`; generated
reports and trap names stay in `tmp/`.

## 3. Principles carried over from Vette!

Vette! went from scaffold to 0.91 in ten days and 377 commits. What made that
fast, and what cost time, is written into these rules. CLAUDE.md is the binding
short form.

1. **Keep the original code; implement the services it calls.** Hook game code
   only where no Toolbox edge exists. Every hook must:
   - check the original bytes first;
   - name its (segment, offset) and the displaced instruction;
   - emulate what it displaces;
   - be documented in [amiga-arch.md](amiga-arch.md).
2. **Loud stops, never guesses.** An unknown trap, selector, resource or file is a
   named stop showing the trap word, manager and routine, the selector, and the
   caller's (segment, offset). A silent no-op is the most expensive bug there is.
   Do not implement a dialog to get past an allocator failure: Vette lost a day to
   a false memFullErr that way.
3. **The Mac is the oracle.** Compare against the Mac:
   - Frames at the same game state, not the same frame number, with the same
     fixed RNG seed on both sides.
   - Audio by event identity, order and pitch, not elapsed time.
4. **A timeout is never a pass.** Every automated run ends with an explicit
   `PASS <case> key=value…` record, and the regression greps for it. Every probe
   needs a positive control: code that was never reached must not read as "zero".
5. **Measure before optimising, and keep the rejections.**
   - Profile the whole frame. Vette's first profile showed presentation at 80%
     and game code at 14%.
   - Keep rejected optimisations in the commit log with their numbers, so nobody
     tries them again.
6. **One coherent change per commit.** Its message says what changed, why, and
   the evidence. Clean-build before any change to build flags.
7. **Short current docs.** `open-work.md` is the queue. Diagnostics and captures
   go in `tmp/`. Historical stage logs are not kept.

## 4. Runtime architecture

The Vette! runtime is kept; these parts change. Each numbered item is a
subsystem with its design decision and the queue tasks that implement it.

### 4.1 CPU, build and machine takeover

- **Build flags.** Build the port with `-m68020 -mtune=68030`.
  - The 68000 mul/div audit and `m68k_math.h` are retired; use native integer arithmetic.
  - Keep the probe audit, and a no-float audit so libgcc soft-float never links.
- **Line-A vector.** Install the handler through VBR (`getVBR()` already exists),
  not at absolute $28. Save and restore the old vector.
- **Trap return (CCR).** The Mac OS dispatcher returns from OS traps with the CCR
  set from D0.W, and original code tests it with a bare `BNE`/`BMI`. Line-A returns
  must set the CCR the same way for OS traps (bit 11 of the trap word clear),
  and leave it untouched for Toolbox traps.
- **Mac stack.** Run the Mac code on its own 64 KB stack, set up with StackSwap
  or the entry trampoline, not the Shell stack. `CurStackBase` ($908) =
  A5 − 75,616, the lowest global, as on the Mac.
- **Caches.** Implement `$A0BD _vCacheFlush` and `HWPriv` selectors 1 and 3 as
  `CacheClearU()`. CODE 1 then never reaches its privileged `MOVEC CACR`/`CPUSHA`
  fallback [M: code1 analysis]. Never run privileged 68k code in user mode.
- **System windows (task M1.7).** The machine stays taken over, as in Vette,
  but the port can hand it back to the OS for a bounded operation (a file
  read, a save) and take it again. That is how files are read without
  preloading (D1).
  - **Enter a window:**
    - restore the OS interrupt vectors and INTENA, keeping the port's audio
      interrupt and a VERTB server that keeps the port's copper list, so the
      picture and Paula keep going;
    - `Permit()`;
    - run the operation from the Mac-code task in **user mode**.
  - **Leave a window:** `Forbid()`, re-take the vectors, flush the keyboard
    state the OS consumed, and correct Ticks for the elapsed fields.
  - **Line-A dispatch in user mode.** Line-A services that call the OS (File
    Manager, Resource Manager misses, durable writes) cannot run in the
    supervisor-mode exception handler. The handler redirects the RTE to a
    user-mode service trampoline, the same mechanism the VBL trampoline
    uses.
  - **Measure it.** The window's entry/exit cost and the display and audio
    continuity across a window must be measured (probe counters and a
    snapshot), not assumed.
  - **WHDLoad.** The same file interface is backed by `resload_LoadFileOffset`
    and `resload_SaveFile`, which work without the OS, so no window is
    needed there.

### 4.2 Loader: let CODE 1 do its job

Replace the resident pre-resolution with the original startup path (tasks
M1.1–M1.3):

1. **Load CODE 1.** Copy it into an aligned block and fill jump-table entries
   0–9 in the loaded form `seg:w, JMP abs.l`, as the Segment Loader does at launch.
   CODE 1 saves a pointer at A5+$68, inside entry 9, which expects that form.
2. **Leave entries 10–467 unloaded.** Keep CODE 0's `offset, MOVE.W #seg,-(SP),
   _LoadSeg` form.
3. **Build the A5 world the way the Mac does.**
   - Allocate below + above + a port-private **shadow area** after the jump
     table (A5+3,776 and up, within `d16(A5)` reach). Section 4.3 uses it.
   - Zero the whole block. Copy CODE 0's jump table to A5+32.
   - Set low memory: CurrentA5 = A5, CurStackBase = A5 − below, CPUFlag = 3
     (68030, the reference machine), and ApplLimit and friends to match the heap
     (4.4). Do not expand DATA; CODE 1 does it.
4. **Enter at CODE 1+$14 in user mode.** CODE 1 then:
   - runs `GetResource('STRS'/'DATA'/'ZERO'/'DREL')`;
   - installs its patches with the old-style `GetTrapAddress`/`SetTrapAddress`
     ($A9F0/$A9F1/$A9F4);
   - calls `main` (JT69, Core+$03E4).
   Every later jump-table call raises `_LoadSeg`. The dispatcher routes it to CODE
   1's handler, which relocates the segment and fills the jump table.
5. **CODE resources are real handles** (4.4). `GetResource('CODE',n)` returns an
   aligned copy with header bit 15 intact, so CODE 1 applies CREL once:
   - even offsets add A5;
   - odd offsets add the STRS base.
   Because the port never relocates, CREL is no longer a port concern. The
   `SEGMENT LOADER / CREL RELOCATION` stop is removed.
6. **Trap patching must be real.** `GetTrapAddress` returns, per trap, the address
   of a small stub `dc.w $AFxx, <trap>` that runs the built-in implementation and
   bypasses any patch. CODE 1's `JSR handler; JMP original` then works, and so
   does the THINK C `exit` patch at Misc3+$084C. A patched trap word (installed
   through `SetTrapAddress`) redirects the PC to the installed address with the
   Mac's register conventions: OS traps get A0/D0/D1/D2/A1 as on the Mac.
   Toolbox traps get the stack untouched.

**Done when** the host check `tools/a5world_check.py` (M1.2) passes: it runs
CODE 1's expansion algorithm on the resource bytes and compares, byte for byte,
with the A5 world the Amiga dumps (via gdb) when it enters `main`. The first new
loud stop must be inside `main`'s initialisation.

### 4.3 Low memory

- **Never map Mac Page 0.** Absolute-word references to Mac globals are patched,
  after byte checks, to the same-length `d16(A5)` form pointing into the shadow
  area (task M1.4).
  - This is Vette's method. The far model does not stop it, because the shadow
    area sits above the jump table.
  - The patch runs when a CODE handle is created, so CODE 1 and every segment
    are covered before they run.
- **Live references [M]:**
  - Runtime: $12D, $12F, $130, $31A, $904, $908, $A4A, $A5E, $A60.
  - System checks: $15A, $220, $A58, $BAA.
  - Time: $16A, $16C. Sound: $27E. TextEdit scrap: $AB0, $AB4.
  - The SysEnvirons fallback glue is dead if `SysEnvirons` is implemented, which
    it is.
- **Tooling.** `tools/m68k_lowmem.py` must skip CREL-relocated operands and
  `PEA #imm.w`. `make lowmem-scan` must then list exactly the patched sites.
- **The patcher fails before takeover** if any expected site count differs. A
  build-time table names each site.
- **Decrypted code.** MDRV is decrypted at runtime into a heap block. Census its
  low-memory references from `tmp/plan/MDRV_11.bin`:
  - $260 SdVolume on the Sound Manager 3 path;
  - $160/$266/$1D4 only on the legacy path, which the port never enables.

  Patch MDRV at a verified hook where the game stores its entry pointer at
  A5−$6AC (Core+$1CC6), or supply the values some other way the census
  justifies.
- **VBI.** The VBI updates the Ticks shadow at A5+shadow. Mouse and button state
  stay in the private prefix, as in Vette.

### 4.4 Memory Manager: a real application zone

Vette gave every Ptr and Handle its own Exec `AllocMem`, with non-moving master
pointers and 128 handle slots. That is too loose for this game:
- it checks `FreeMem`, `MaxApplZone` and `CompactMem`, and prints "There isn't
  enough memory to do that!";
- it uses `HGetState`/`HSetState`, `MoveHHi`, purgeable handles and detached
  resources;
- its heap behaviour must match the 3 MB `SIZE` partition, and blocks must not
  land in chip RAM.

Design (task M1.5):
- **One fast-RAM block of `SIZE` preferred** (3,145,728 bytes) as the
  application zone. The A5 world and the Mac stack are allocated separately,
  and the port's own buffers never live in the zone.
- **A Mac-compatible allocator in that block.** Pointers are non-relocatable
  blocks. Handles have master pointers in master blocks (`MoreMasters`).
  - Lock, purge and resource flags are kept on the side; master pointers hold
    clean 32-bit addresses. The reference runs 24-bit, but the original masks
    through `StripAddress` and never depends on flag bytes [I; the census found no
    direct flag-byte use]. Verify this in M1.5.
  - Compaction moves unlocked relocatable blocks and fixes master pointers.
  - Purging empties purgeable handles when space runs out.
  - `FreeMem`, `MaxMem`, `CompactMem` and `MaxApplZone` return real numbers for
    this zone.
  - A system zone (`NewPtrSys`) is a small separate zone, for the VBL stub and
    the THINK C exit patch.
- **Complete the call set.** Add DisposeHandle, NewHandleClear, HGetState,
  HSetState, EmptyHandle, ReallocateHandle, SetPtrSize, GetPtrSize, SetZone,
  GetZone, SetApplLimit, PtrToHand, MemError and ResError.
- **Host unit tests.** The zone allocator is pure C++ and gets host tests
  (`tools/test_mac_heap.cpp`): allocate, lock, purge, compact, and fragmentation
  patterns.

### 4.5 Files: on-demand reads through system windows

- **Nothing is preloaded (D1).** At startup, read only the catalog: the names,
  sizes, types and directory structure of `Alone Data/`, `Alone Saved Games/`
  and the prefs file. This gives an HFS-like view with directory IDs, names,
  both forks (`.rsrc` companions or the port's fork storage) and Finder info.
- **File Manager calls (task M2.1).** Implement the ones the census lists over
  that catalog:
  - open, read and write: `_Open`, `_Read`, `_Write`, `_Close`;
  - position and length: `_GetEOF`, `_SetEOF`, `_SetFPos`, `_GetFPos`;
  - create, delete and file info: `_Create`, `_Delete`, `_Get`/`_SetFileInfo`;
  - volume and default directory: `_GetVol`, `_SetVol`, `HGetVol`, `HSetVol`;
  - the H- and async-flag variants;
  - `FSDispatch`/`HFSDispatch` (`GetFCBInfo`, `OpenWD`, `GetWDInfo`, `CloseWD`,
    `HGetVolParms`) and `HGetVInfo`.

  Paths are Mac partial paths (`:Alone Data:CAMERA06.PAK`), resolved against the
  default directory. Error codes follow Inside Macintosh.
- **Reads come in chunks.** An open fork keeps an AmigaDOS handle, opened in a
  system window. A `_Read` of up to the chunk size (start at 64 KB, tuned by
  measurement) is served from a per-fork read buffer. A miss fills the buffer in
  one system window. Reads larger than the buffer go straight into the caller's
  buffer, in chunk-sized pieces, in one window.
  - The game reads whole `.PAK` entries (Dark JT182), so a room change costs a
    few windows, not one per call.
  - Count windows per room change and record the number (M5).
- **Writes (save games, "Alone Prefs").** Writes are buffered per fork and
  written through in a system window at `_Close`/`FlushVol`, so a save the game
  reports as written is on disk (task M3.6). WHDLoad uses `resload_SaveFile`.
- **Where files live.** "Alone Prefs" is in the System Folder's Preferences
  (`FindFolder`). Map that to `PROGDIR:prefs/`. `:Alone Saved Games:` maps to
  `PROGDIR:Saved Games/`.
- **Resource files.** `HOpenResFile`, `CreateResFile`, `OpenRFPerm`,
  `UseResFile`, `CloseResFile`, `AddResource`, `RmveResource`, `WriteResource`
  and `ChangedResource` work on the prefs and save-game resource forks.
  - This extends `ResourceForks.cpp` from a read-only parser to a writable fork
    model, rewritten at `UpdateResFile`/close.

### 4.6 Resource Manager

- **Resource data is read on demand (D1).** Keep only each fork's resource
  map in memory; the application's map is about 7 KB. `GetResource` reads the
  data into a zone handle, through a system window, when the handle is empty,
  exactly as the Mac's Resource Manager does. Purgeable resources may be
  purged and reloaded (`LoadResource`).
  - `DetachResource` hands the block over to the caller. `ReleaseResource`
    frees it.
  - This replaces today's whole-fork load (`PlatformAmiga.cpp`, capped at 4 MB).
- **Port overlay resources.** A small resource fork of the port's own resources
  comes first in the search order: the 320×200 dialog layouts (D5) and the
  placeholder fonts (D6).
- **Calls to add.** `Get1Resource`, `Get1NamedResource`, `DetachResource`,
  `ResError`, `SetResLoad`, `GetResInfo`, `CountResources`/`Count1Resources`,
  `Get1IndResource` (if reached), and the writable-file calls in 4.5.
- **Search order.** Open resource files first, then the application, then the
  port overlay, which stands in for the System file. The one exception is the
  dialog layouts, which the overlay supplies ahead of the application. Resources the game expects from the System file (fonts, `snd `
  beeps, `CURS`) are listed and supplied by the port (4.11). A missing one is a
  loud stop.

### 4.7 Display: 8-bit Mac screen, AGA presentation

- **Mac screen model (task M2.4).**
  - The logical main screen is 640×480 at 8 bits (the reference's mdc48 mode), in
    fast RAM, with one GDevice and a 256-entry CLUT.
  - Windows, dialogs and menus are drawn into this screen by the port's QuickDraw.
  - `GetMainDevice`, `GetDeviceList`, `GetNextDevice`, `TestDeviceAttribute` and
    `HasDepth` (8 bits: yes) describe it. A single device means the monitor picker
    (DLOG 2000) never appears.
- **Viewport.** The Amiga shows a fixed 320×200 viewport of the Mac screen: the
  content rectangle of the game window, WIND 128, at (82,168)–(402,368) in global
  coordinates [M]. Nothing outside it is ever shown:
  - there is no screen-size dialog (D4);
  - dialogs are laid out inside the viewport (D5);
  - the menu bar is never drawn (D7).
- **AGA output (task M2.5).**
  - Lores, 8 planes, 320×200 centred in the PAL or NTSC field, with double-buffered
    chip bitmaps.
  - FMODE: start at 1×, and measure whether 2× or 4× fetch frees chip bandwidth for
    the CPU once C2P is on the budget (M5).
  - `AitdScreen` stays the only owner of display registers. Copper lists and
    bitplane/sprite pointers are published first in the VBI.
  - The sprite pointer uses a sprite palette bank (BPLCON4) that the game's colours
    do not need, and gets its own colours.
- **Remove HIRES.** Remove the HIRES build option, StartupConfig's HIRE word, and
  the interlace code (task M0.4).
- **C2P (task M2.6).**
  - Convert the Mac screen's dirty rectangles inside the viewport: 8-bit chunky to
    8 planes, x aligned to 32 pixels. Start from Kalms' public-domain `c2p1x1_8_c5_030`
    ([external](https://github.com/Kalmalyzer/kalms-c2p)). A C reference keeps the
    `VERIFY=1` oracle, as in Vette.
  - Budget: a full 320×200 conversion is about one PAL frame on a 68030/50
    [external estimate]. The engine redraws only boxes, so typical frames should be
    far cheaper.
- **Dirty rectangles.** Keep the explicit list. They come from every QuickDraw
  write to the screen port, plus the presentation `CopyBits` dest rectangle. The
  back buffer inherits the previous update's rectangles.
- **Palette (task M2.7).**
  - `ActivatePalette` realises the palette the way the Mac's Palette Manager does
    on an 8-bit device: pmExplicit plus pmTolerant with tolerance 0, and indices
    0/255 reserved white/black. The result is loaded into AGA's 256 24-bit colour
    registers through BPLCON3 banks, published in the VBI.
  - Verify the device CLUT against a MAME capture taken after the game activates
    its palette (8-bit `mac_probe_fb.lua`, M0.5).
- **Fonts.** See 4.11 and D6.

### 4.8 QuickDraw and offscreen worlds

- **Depth.** Generalise the 4-bit Vette paths to 8 bits per pixel. The screen,
  GWorld, PixMap, CTable (256 entries), ITable (resolution 4 and 5), `CopyBits`
  and the PICT decoders must all handle 8-bit data (task M2.3). Remove the
  Vette-specific palette maps and caps: `paletteToColorTable`'s pltt IDs, the
  16-entry limits, and the `s_indexedPictureScratch` size.
- **`$AB1D` QDOffscreen.**
  - Dispatch on the **low word** of D0; the high word is the parameter byte count
    [M: the glue uses `MOVE.L #$0008_0006,D0`, not 6].
  - Implement NewGWorld (0), LockPixels (1), UnlockPixels (2), UpdateGWorld (3),
    DisposeGWorld (4), GetGWorld (5), SetGWorld (6), GetPixBaseAddr (15),
    GetGWorldPixMap (23), and the rest as they are reached.
  - Pixels live in the zone as handles, locked by `LockPixels`.
  - `GetPixBaseAddr` returns a clean 32-bit pointer. No `SwapMMUMode` is needed.
- **CopyBits.** Implement srcCopy (the presentation path), ditherCopy (Dan1/Dan2),
  and the colour-mapping modes the game reaches. Fore and back colours
  (`RGBForeColor`, `RGBBackColor`) affect `CopyBits` colourising exactly as on
  the Mac. Keep a fast path for the unscaled 8-bit→8-bit srcCopy with identical
  colour tables and 4-aligned rectangles, verified against the general path
  (`VERIFY=1`).
- **Regions.** Replace the rectangle-only regions with real QuickDraw regions
  (task M2.8): `NewRgn`, `OpenRgn`/`CloseRgn`, `RectRgn`, `CopyRgn`, `SetEmptyRgn`,
  `InsetRgn`, `DiffRgn`, `XorRgn`, `MapRgn`, `EmptyRgn`, `PaintRgn`, and clipping by
  region in `CopyBits` and fills. Dark uses them for the "Hide Background" option
  and the inventory/book views [I]. Implement the scan-line region format, and
  test it on the host against hand-built fixtures.
- **Polygons.** Dark uses `OpenPoly`, `ClosePoly`, `FramePoly` and `KillPoly`.
- **Other calls.** Add the rectangle utilities (`OffsetRect`, `InsetRect`,
  `SectRect`, `UnionRect`), `LineTo`, `Line`, pen state, `FrameOval`,
  `FrameRoundRect`, `Open`/`Close`/`KillPicture`, text measurement (`TextWidth`,
  `CharWidth`, `GetFontInfo`) and `GetFNum`.

### 4.9 Windows, menus, dialogs, events

- **Windows.** Implement the Window Manager calls in the census, over the Mac
  screen: `SetWTitle`, `SizeWindow`, `BringToFront`, `SendBehind`, `TrackGoAway`,
  and the rest. The "Background Hider" (WIND 131) is a full-screen black window.
  It stays; the viewport shows the game window over it.
- **Screen size (D4).** Only 320×200 is supported, and the screen-size dialog
  (DLOG 1000) is never shown.
  - Find the cleanest seam before implementing (task M2.4). Candidates: a
    port-supplied "Alone Prefs" `PREF` that already holds the 320×200 choice, so
    the game never asks; or `ModalDialog` returning item 2 for DLOG 1000.
  - Either way the game's own code picks WIND 128 (Misc1+$107E).
- **Menus (D7): no menu bar.** The DOS version had none, and the menus hold
  nothing the keyboard lacks:
  - Apple: About (credits);
  - File: Open Game ⌘O, Save Game ⌘S, Quit ⌘Q;
  - Edit: desk-accessory editing, always disabled;
  - Options: Sound Effects, Music, Hide Background.

  The manual lists game keys for sound (S), music (M), pause (P), inventory (I),
  and ESC for "the save, load, quit and parameter screen". Whether the Mac build
  still has that ESC screen, or routes it to the File-menu dialogs, is task M0.2's
  question.
  - Menus stay as data (`InitMenus`, `InsertMenu`, `GetRMenu`, and so on) so the
    game's setup runs, but `DrawMenuBar` draws nothing.
  - `MenuSelect` is never reached, because no click lands in a menu bar.
  - `MenuKey` maps Right-Amiga+key to the game's own Command-key items, so ⌘O,
    ⌘S and ⌘Q work if the ESC screen does not cover them.
  - Hide Background and About get a key only if the owner asks.
- **Dialogs (D5): reimplemented inside 320×200.**
  - The Dialog Manager (`GetNewDialog`, `ModalDialog` with standard filter
    behaviour, `DialogSelect`, `GetDialogItem`/`SetDialogItemText`, `ParamText`,
    `Alert`, `StopAlert`, `UpdateDialog`, `HiliteControl`) runs the game's
    dialogs unchanged.
  - Any `DLOG`/`ALRT` whose rectangle does not fit the viewport gets a port
    overlay `DLOG`/`DITL` with the same item numbers, kinds and meaning, laid out
    inside WIND 128's content rectangle. The game's dialog code is unaffected.
    Candidates: DLOG 200/201 (348×218) and 212 (493×272); 128 and 131 fit.
  - The overlay is a committed, generated resource file, built by a tool that
    records each layout.
  - StandardFile (`Pack3`) appears only in unreached code [M]. M0.2 observed
    zero direct calls through new game, ESC save, Command-S/Command-O and quit.
    Those paths use the engine UI; this does not prove error paths cannot call it.
- **Events.**
  - `WaitNextEvent` (sleep ignored) and `GetNextEvent` deliver key, mouse,
    update and activate events.
  - `GetKeys` returns the live KeyMap. The manual's keys: arrows, Shift (run),
    Space (action), Return (inventory), ESC, F, J, O, Z, U, T, S, M, P, I.
  - `Button`, `StillDown`, `GetMouse`, `FlushEvents`, `SystemTask`, `SystemClick`
    (no desk accessories: return) and `ObscureCursor`.
  - Apple Events (`Pack8`): install handlers and succeed; `AEProcessAppleEvent`
    is never reached without high-level events. `OpenDeskAcc` and the scrap calls
    are loud stops until reached.
- **Keyboard mapping.** Amiga raw keys map to Mac virtual keys through the
  existing table, extended for the keys the game reads.

### 4.10 Audio: Paula voices instead of software mixing

D8: play sound on Paula's four hardware channels instead of SoundMusicSys's
22 kHz software mixer. The mixer is also the largest CPU cost the original has
on a 68020/030.

- **The seam is the driver interface, not the game.** The game talks to the
  driver only through `D0 = entry(long selector, long arg)`, with the entry
  pointer stored at A5−$6AC. It uses selectors 1, 2, 4–9 and 12–25 [M].
  - The port provides a native SoundMusicSys-compatible driver behind that
    entry. The entry is a 68k stub of a private Line-A trap in a zone block.
  - Install the stub at one verified point, chosen in task M4.1 by byte check:
    either a port-supplied `Jnth` resource (the game looks for `Jnth` before
    `MDRV`; check what it does with it), or a hook where Core+$1CC6 stores the
    entry pointer.
  - The game code stays unchanged. The original `MDRV` is never run.
- **The API (task M4.1).** Decode every selector the game uses from the unpacked
  driver (`tmp/plan/MDRV_11.bin`, its 27-way dispatch table) and from Halestorm's
  public `SoundMusicSystem.h`. Selectors cover opening the driver, starting and
  stopping songs, and sound effects, volume, pause and resume. Each selector is
  implemented to the driver's semantics, or is a named loud stop.
- **Music (task M4.2).**
  - A native sequencer plays the `SONG`/`MIDI` (Standard MIDI File) data with
    the `INST` instrument mapping onto `snd ` samples.
  - Notes become Paula voices: period from the MIDI note, the instrument's base
    note and the sample rate; volume from velocity and channel volume; loops from
    the `snd ` loop points.
  - Tempo is driven by the VBI's tick counter, but the sequencer runs at safe
    user-mode points, never in the interrupt. It schedules ahead, so a late safe
    point shifts events, not pitch.
- **Voices and effects.** Four channels, allocated by priority: sound effects
  (the `snd `/`LISTSAMP` samples the game requests through the driver) take a
  channel, and music takes the rest. Voice stealing drops the oldest or quietest
  music note first. Record the policy and measure its effect on the songs, which
  have up to N simultaneous notes (count it in M4.2).
  - "Where available": if a song regularly needs more than the free channels,
    the owner may allow mixing two voices on one channel. That is a later,
    measured option, not the default.
- **Sound Manager.** Only what remains once the driver is native: `SysBeep`,
  and any direct `snd ` playback the trap log shows. `SndSoundManagerVersion`
  still reports 3.x. The MIDI Manager calls answer "not installed".
- **Fidelity.** Compare against the MAME reference by events: song, note on and
  off, instrument, order. Audio will not match sample for sample, and does not
  need to.
- **Options.** The S and M keys and the game's own sound and music toggles go
  through the driver selectors, so they work unchanged.

### 4.11 Text and fonts

D6 keeps the game's font where the engine draws it, with placeholder Mac fonts
first for QuickDraw text and the engine-font replacement later. The M0.2 trace
shows broader Mac-font use than the initial static estimate: Times (font ID 20)
at 14 points draws credits, menus, character narrative, save/load labels,
inventory actions and S/M feedback. Pause uses Times 36. Chooser controls use
system font ID 0 at 12; some system/default draws report size 0. `GetFNum` requests
"Times". These are observed paths, not proof that other sizes are unused.

The port may not ship Apple fonts.

1. **Confirm remaining uses (task M2.9).** Use the MAME trap log (`TextFont`/`GetFNum`/
   `DrawText` with the strings) to see exactly which text uses which Mac font and
   size.
2. **Placeholder fonts.** Supply them for those uses as port overlay `FONT`/`NFNT`
   resources: one simple committed bitmap font per required family and size,
   drawn for the port. `GetFNum`, `TextFont`, `TextSize`, `TextFace` (synthesized
   bold and italic) and `DrawText` use them.
3. **Eventually (a later queue item):** render those texts with the game engine's
   own font instead. It exists in the Mac `ITD_RESS.PAK` and in the PC version,
   so the Amiga looks like the DOS game. Check the PC data's font entry against
   the Mac one first.

### 4.12 Time, VBL, pacing

- **Clock.** `TickCount` and the `Ticks` shadow run at 60 Hz from the 50 Hz VBI,
  inheriting Vette's one extra tick every fifth field.
- **VBL tasks.** Keep them at safe points. Core's task runs through the generated
  system-heap stub, and the dispatcher calls the stub, not a guessed target, so
  the game's own A5 handling applies. Dark's re-arming task runs the same way.
- **Pacing (D3).** No frame cap. Present at most once per field, as fast as the
  machine allows.
  - A frame-rate bug is known on the PC and the Mac: too high a frame rate makes
    the attic-stairs descent turn back, because track and animation steps
    advance once per frame [external: speedrun KB].
  - Whether the Amiga reaches that rate is tested by the `stairs` regression on
    the 68060 configuration (M6.3). If the bug occurs, it becomes its own queue
    item with its own fix, owner-approved, and not a global cap.

### 4.13 Lifecycle and release

- **Quit.** File > Quit and ExitToShell go through the game's own patches (CODE
  1, then Misc3), then the port's exit trampoline.
- **Cleanup.** Restore the OS completely and release everything in the ledgers.
- **Startup.** Workbench and Shell startup as in Vette.
- **Release (M7).** An Installer script that runs `install-data` (Vette's C
  StuffIt extractor) against the user's `AloneInTheDark.img_.sit`, a deterministic
  LHA, and a WHDLoad slave adapted from `VetteSlave.s`. The slave needs:
  - `WHDLF_EmulLineA`;
  - a 64 KB stack;
  - chunked reads with `resload_LoadFileOffset`;
  - saves through `resload_SaveFile`.

  No original data, ROM, System software or WHDLoad binary is distributed.

## 5. Owner decisions

Decided by the owner on 2026-09-28. Anything that changes these goes back to
the owner.

| ID | Decision |
| --- | --- |
| D1 | **No preloading.** Load in reasonable chunks, letting the OS run (multitasking, DOS) when needed: 4.1 system windows, 4.5 files, 4.6 resources. |
| D2 | **Run as well as possible.** A 68020 must boot and play. Measure on the 68020 and 68030 configurations. |
| D3 | **No frame cap** unless bug-free gameplay requires one. Such a bug, for example the stairs, is addressed separately. |
| D4 | **No screen-size dialog;** only 320×200. |
| D5 | **Dialogs reimplemented within 320×200:** port overlay layouts, with the game's dialog code unchanged. |
| D6 | **Fonts:** most are game-provided (the engine font). For Mac-font text, placeholder fonts first; eventually the game's own font, from the PC version if needed. |
| D7 | **No menus** (the DOS version had none). Keys only: the game's keys, plus Right-Amiga for its Command-key items. |
| D8 | **Paula channels instead of software mixing:** a native driver behind the SoundMusicSys interface. |

## 6. Verification

| Change | Required evidence |
| --- | --- |
| Pure helper (heap, regions, fonts, PAK tools) | Host unit test in `tools/`, run by `make host-tests` |
| Loader / low-memory patch | Original-byte checks. `a5world_check.py`. Bounded diag run reaching the next loud stop, reported by `runtime_status.gdb` |
| New trap | Bounded run past the old loud stop. Where the result is observable, compare with the MAME trap log (M0.2) for the same call's arguments and results |
| Display / QuickDraw | State-pair frame compare with MAME: same game state, same RNG seed, 8-bit framebuffer + CLUT from both sides (`tools/compare_frames.py`, M2.10) |
| Audio | Driver event log (selector, song, note, instrument) against MAME |
| Performance | `PROBES=1` full-accounting profile on `a1200-020` and `a1200-030`, run twice, ms per frame by phase |
| Release | `make release-check` and WHDLoad smoke/boot/load/quit tests |

**Emulator configurations** (FS-UAE via `amiga/diag_run.sh`, `AMIGA_CONFIG=`,
task M0.6). Pin them explicitly: today the scripts leave the CPU to the model
default, and run.sh contradicts its own comment.

| Name | Model | CPU | Chip / fast | Use |
| --- | --- | --- | --- | --- |
| `a1200-020` | A1200 | 68EC020 14 MHz | 2 MB / 8 MB | Minimum: boot and play regression, profiling |
| `a1200-030` | A1200 + 68030/50 | 68030 50 MHz, MMU off | 2 MB / 16 MB | **Default for development**; profiling together with `a1200-020` |
| `a4000-040` | A4000 | 68040 25 MHz | 2 MB / 16 MB | Cache and CPUSHA behaviour, pacing |
| `a1200-060` | A1200 + 68060/50 | 68060 | 2 MB / 16 MB | Pacing and stairs, fast-machine bugs |

**MAME reference loop.**
- `tools/mac_launch.lua` launches the game on the 7.5.5 volume.
- `tools/mac_traps.lua` (M0.2) logs every Line-A trap the game executes, with
  arguments, caller (segment, offset) and results, keyed by live segment
  addresses read from the jump table.
- `tools/mac_probe_fb.lua` dumps the 8-bit framebuffer and CLUT (M0.5).
- A fixed-seed hook writes the same `RndSeed`/`Random` seed on both sides.

**Regression** (`amiga/regression.sh <case>`, `make regression`). Each case is a
clean build with its flags, a warp-mode bounded run, a required PASS regex, and
no loud stop. The cases are added as their milestone lands:
- `boot`: reaches main.
- `intro`: logo and intro complete.
- `newgame`: first room playable.
- `saveload`: save, reload, same state.
- `attic`: scripted route through the attic.
- `stairs`: the descent completes.
- `audio`: music and effects play; driver event log as expected.
- `quit`: clean exit, all ledgers empty.

## 7. Phases

Every phase ends with a tagged checkpoint commit that updates README "Current
state". Task-level detail and acceptance checks are in
[open-work.md](open-work.md).

| Phase | Goal | Exit criterion |
| --- | --- | --- |
| **M0 Groundwork** | Tools, emulator configs, build flags, reference probes | Trap census and runtime trap log committed; 030 config default; `-m68020` build clean with audits |
| **M1 Boot to main** | Original startup path | CODE 1 runs unmodified; A5 world byte-identical to the host model; loud stop inside `main` init |
| **M2 Startup to intro** | Files, resources, Mac screen, AGA 8-bit, palette, fonts, dialogs | Infogrames logo and intro play, state-pair frames match MAME |
| **M3 Playable** | Input, menus, save/load, gameplay loop | New game → first room → walk, fight, pick up, save, load, quit, on the 030 config |
| **M4 Audio** | Native SoundMusicSys driver on Paula voices | Music and effects in intro and play; event log matches MAME |
| **M5 Performance** | Profile and optimise on 68020 and 68030 | Documented ms/frame by phase; no remaining optimisation the profile justifies; minimum fast RAM measured |
| **M6 Completion** | Whole-game fidelity | Scripted and manual play-through of all floors and the ending; stairs regression; no loud stop anywhere |
| **M7 Release** | Installer, WHDLoad, packaging | 1.0 LHA; installer and WHDLoad tests pass on the test matrix |

## 8. Workflow (strict, quick)

1. **Take the top item** in [open-work.md](open-work.md). Do not start a second
   item while one is open.
2. **Read only what the item needs**: the listed files, the original bytes, the
   census row. Check original bytes before any patch.
3. **Implement the smallest complete version.** No stubs that pretend success.
   Anything still missing is a loud stop.
4. **Validate** with the evidence the verification table (section 6) requires. Two
   failed hypotheses in a row means instrument (probe, trap log, MAME compare)
   before guessing a third time.
5. **Update the docs** the change affects, in the same commit. Delete the item from
   `open-work.md`. Add any newly found work at its correct position, with an ID
   and an acceptance check.
6. **Commit** directly on `main`: an imperative subject, and a body giving why,
   what, and the evidence (numbers, PASS records). Use the repository identity. No
   signing, hooks or co-author lines.
7. **After each milestone**, run `make regression` for the cases so far on
   `a1200-030`, plus `boot` on `a1200-020`. Record the checkpoint in README.
8. **Escalate to the owner** only for decisions in section 5, or for anything that
   would change game behaviour. Otherwise proceed.

## 9. Risks

| ID | Risk | Mitigation |
| --- | --- | --- |
| R1 | Game too slow on 68020/030 (3D engine + CopyBits + C2P) | Profile from the first playable frame (M3), on both configs. Dirty-box C2P; fast srcCopy; FMODE; asm hot traps. Keep the original rasteriser |
| R2 | System windows disturb display, audio or timing, or are too slow | Measure entry/exit cost and continuity (M1.7); chunk size and read buffer tuned by counts per room change |
| R3 | Native driver mis-reads the SoundMusicSys API or songs need more than 4 voices | Selector-by-selector decoding with loud stops; MAME event compare; measured voice counts (M4.2) |
| R4 | Stairs bug on fast CPUs | `stairs` regression on 060; separate fix only if it occurs (D3) |
| R5 | Memory | Zone sized by SIZE; on-demand files and resources; measure the minimum fast RAM (M5) |
| R6 | Placeholder fonts or 320×200 dialog layouts look wrong | Overlay layouts reviewed against MAME frames; engine-font follow-up |
| R7 | Save-game loss | Write-through at close in a system window (4.5), WHDLoad resload |
| R8 | Hidden reliance on 24-bit master-pointer flags or on handle movement | Census found none. Zone allocator tests; M1.5 checks for `StripAddress`-free flag reads |
| R9 | Unreached-code surprises (StandardFile, desk accessories) | Runtime trap log across a full manual session in MAME (M0.2, repeated in M6) |

## 10. Numbers to keep current

| Item | Value |
| --- | --- |
| Jump table | 468 entries; A5 below 75,616 / above 3,776 |
| DATA / ZERO / DREL | 11,418 / 560 / 678 bytes; 276 DREL entries (255 A5, 21 STRS) |
| CREL | 7,329 entries; 7,210 even (A5), 119 odd (STRS) |
| Live trap sites / distinct | 1,118 / 243 (census + M0.2 runtime roots) |
| `SIZE` | 3,145,728 preferred and minimum |
| Data files | `Alone Data` 5.2 MB; app resource fork 1.4 MB |
| MDRV (not run, D8) | 12,630 packed → 29,256 bytes; 22,254.5 Hz, 2×370-byte buffers |

## 11. Trap census (live walk)

Live sites / distinct traps: 1,118 / 243, from main, CODE 1, the DATA function
pointers, code references and the runtime-confirmed CODE 1 cache helper [M]. The grouped table with sites is generated by
`make trap-census` in `tmp/trap-census.md`. The
current runtime handles about 87 of the 243; the rest arrive as loud stops. By
manager:

- **Segment/Trap/System:**
  - SetTrapAddress, GetTrapAddress, GetOSTrapAddress, GetToolTrapAddress
  - StripAddress, SysEnvirons
  - Gestalt: 'sysv', 'proc', 'qd  ', 'qtim', 'help', 'fold', 'evnt', 'a/ux'
  - HWPriv 1/3, FindFolder, SysBeep, FP68K (5 SANE ops), ExitToShell
  - Debugger/DebugStr (assert paths: loud stops)
- **Memory:**
  - Pointers: NewPtr[Clear/Sys], DisposePtr, Set/GetPtrSize
  - Handles: NewHandle[Clear], DisposeHandle, Set/GetHandleSize, HLock/HUnlock,
    HPurge/HNoPurge, HGet/HSetState, MoveHHi
  - Zone: CompactMem, MaxApplZone, SetApplLimit, MoreMasters, Set/GetZone, FreeMem
  - BlockMove, PtrToHand
- **File:** Open, Close, Read, Write, Create, Delete, Get/SetFileInfo,
  Get/SetEOF, FlushVol, Get/SetVol, SetFPos, the H- variants, HFSDispatch
  (GetFCBInfo, OpenWD, GetWDInfo, CloseWD, HGetVolParms), FSDispatch
  (PBHOpenDF).
- **Resource:**
  - Open and create: HOpenResFile, HCreateResFile, OpenResFile, OpenRFPerm,
    CreateResFile
  - Current file: UseResFile, CurResFile, CloseResFile
  - Lookup: GetResource, GetNamedResource, Get1Resource, Get1NamedResource, GetResInfo
  - Release: DetachResource, ReleaseResource
  - Modify: AddResource, RmveResource, ChangedResource, WriteResource
  - State: SetResLoad, ResError
- **Sound:** SoundDispatch (MIDI Manager sign-in and ports, SndSoundManagerVersion).
  MDRV also uses SndNewChannel, SndPlayDoubleBuffer, SndDoImmediate and
  SndDisposeChannel.
- **Events:** WaitNextEvent, GetNextEvent, GetKeys, GetMouse, Button, StillDown,
  FlushEvents, TickCount, SystemTask, SystemClick, Pack8 (4 Apple Event calls).
- **VBL:** VInstall, VRemove.
- **QDOffscreen:** SetGWorld ×96, GetGWorld ×42, GetGWorldPixMap ×9,
  Lock/UnlockPixels, NewGWorld, UpdateGWorld, GetPixBaseAddr, DisposeGWorld.
- **Colour:** RGBFore/BackColor, GetFore/BackColor, GetCTable,
  GetDeviceList, GetMainDevice, GetNextDevice, TestDeviceAttribute.
- **Palette:** NewPalette, SetPalette, ActivatePalette, PaletteDispatch
  (HasDepth, SetDepth, SaveFore, RestoreFore).
- **Window:** InitWindows, GetNewCWindow, Show/Dispose/Move/SizeWindow,
  SetWTitle, TrackGoAway, BringToFront, SendBehind, Begin/EndUpdate,
  FrontWindow, DragWindow, FindWindow.
- **Menu:** InitMenus, ClearMenuBar, InsertMenu, DrawMenuBar, HiliteMenu,
  Enable/DisableItem, MenuSelect, MenuKey, SetItemMark, Get/SetMenuItemText,
  GetMenuHandle, AppendResMenu, CountMItems, GetRMenu.
- **Dialog:**
  - Creating: InitDialogs, GetNewDialog, NewDialog, DisposeDialog
  - Running: ModalDialog, DialogSelect, UpdateDialog
  - Items: GetDialogItem, SetDialogItemText, SelectDialogItemText, ParamText,
    HiliteControl
  - Alerts: Alert, StopAlert
- **Desk/Scrap/TE:** OpenDeskAcc, SysEdit, TEInit, TECopy, TECut, TEPaste,
  ZeroScrap, GetScrap, PutScrap. These are Edit-menu paths; loud stops until
  reached.
- **QuickDraw:**
  - Ports and clipping: InitGraf, ports, clip, LocalToGlobal/GlobalToLocal,
    SetPt, HiWord, ShowHide, Random
  - Text: DrawText, TextWidth, CharWidth, GetFontInfo, TextFont, TextFace,
    TextSize, TextMode, InitFonts, GetFNum
  - Pens and lines: pen state, lines
  - Shapes: rectangles, ovals, round rectangles, polygons, regions (14 calls)
  - Pictures and pixels: CopyBits, pictures
  - Cursor: InitCursor, SetCursor, GetCursor, ObscureCursor, TrackBox
