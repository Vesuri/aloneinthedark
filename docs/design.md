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

| | Minimum | Recommended | Also tested |
| --- | --- | --- | --- |
| CPU | 68020 | 68030/50 | 68040, 68060 |
| Chipset | AGA | AGA | AGA |
| Fast RAM | see D1 | 16 MB | 8 MB |
| OS | Kickstart 3.1 | 3.1+ | WHDLoad |

- **68020 is the floor** because the game uses 68020 instructions [M: 319 on
  reachable paths]. Expect it to be slow there. The original Mac recommended a
  68040 [external: Inside Mac Games listing]. A 68030/50 is the performance
  target every phase is measured on.
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
- **Music: Halestorm SoundMusicSys.**
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

The complete trap census is in section 11. The analysis scripts behind it are
in local `tmp/plan/`; promoting them to maintained tools is task M0.1.

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

- **Build flags.** Build the port with `-m68020 -mtune=68030` (task M0.3).
  - Retire the 68000 mul/div audit and `m68k_math.h` for new code.
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
- **No OS during takeover.** DOS is unavailable while the machine is taken over,
  as in Vette. See D1 and 4.5 for file access.

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

### 4.5 Files: a preloaded, read-mostly volume

- **Preload (task M2.1).** Before takeover, read `Alone Data/` (5.2 MB) and the
  prefs/saves folders into fast RAM as an in-memory volume: an HFS-like catalog
  with directory IDs, names, both forks and Finder info.
  - The application's resource fork is already loaded.
  - This follows Vette's rule that all DOS I/O happens outside takeover, and
    keeps the File Manager deterministic.
- **File Manager calls.** Implement the ones the census lists over this volume:
  `_Open`, `_Read`, `_Write`, `_Close`, `_GetEOF`, `_SetEOF`, `_SetFPos`,
  `_GetFPos`, `_Create`, `_Delete`, `_Get`/`_SetFileInfo`, `_GetVol`, `_SetVol`,
  `HGetVol`, `HSetVol`, the H- and async-flag variants, `FSDispatch`/`HFSDispatch`
  (`GetFCBInfo`, `OpenWD`, `GetWDInfo`, `CloseWD`, `HGetVolParms`) and `HGetVInfo`.
  - Paths are Mac partial paths (`:Alone Data:CAMERA06.PAK`), resolved against
    the default directory.
  - Error codes follow Inside Macintosh.
- **Writes (save games, "Alone Prefs").** Changes go to the in-memory volume at
  once and are persisted to AmigaDOS:
  - standalone: in a short, controlled OS-return window when the game closes a
    written file;
  - WHDLoad: with `resload_SaveFile`.
  - A crash must not lose a save that the game reported as written (task M3.6).
- **Where files live.** "Alone Prefs" is in the System Folder's Preferences
  (`FindFolder`). Map that to `PROGDIR:prefs/`. `:Alone Saved Games:` maps to
  `PROGDIR:Saved Games/`.
- **Resource files.** `HOpenResFile`, `CreateResFile`, `OpenRFPerm`,
  `UseResFile`, `CloseResFile`, `AddResource`, `RmveResource`, `WriteResource`
  and `ChangedResource` work on resource forks in that volume (prefs and saves).
  - This extends `ResourceForks.cpp` from a read-only parser to a writable fork
    model, with full rewrite on `UpdateResFile`/close.

### 4.6 Resource Manager

- **Resource data.**
  - Return aligned copies for any resource the game may write or relocate (CODE,
    `MDRV`, `SMOD`, `snd `, `DATA`).
  - Treat the image in place as read-only for the rest.
  - `DetachResource` hands the block to the zone. `ReleaseResource` frees it.
- **Calls to add.** `Get1Resource`, `Get1NamedResource`, `DetachResource`,
  `ResError`, `SetResLoad`, `GetResInfo`, `CountResources`/`Count1Resources`,
  `Get1IndResource` (if reached), and the writable-file calls in 4.5.
- **Search order.** Open resource files first, then the application. There is no
  system file. Resources the game expects from the System file (fonts, `snd `
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
- **Viewport.** A 320×200 viewport of the Mac screen is shown. It follows the
  front window's content rectangle. WIND 128's content is at (82,168)–(402,368) in
  global coordinates [M].
  - Dialogs larger than 320×200 are handled by D5.
  - Menus are handled by D7.
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
- **Menus.**
  - `MenuSelect` is real: it tracks the pointer in the menu bar and returns
    (menu, item).
  - `MenuKey` maps Command-keys. Right-Amiga acts as Command. File menu: Open
    Game ⌘O, Save Game ⌘S, Quit ⌘Q. Options: Sound Effects, Music, Hide Background.
  - Presentation is D7.
- **Dialogs.** `GetNewDialog`, `ModalDialog` with the standard filter behaviour,
  `DialogSelect`, `GetDialogItem`/`SetDialogItemText`, `ParamText`, `Alert`,
  `StopAlert`, `UpdateDialog`, `HiliteControl`, and simple buttons, radio buttons
  and static and edit text as the DITLs need.
  - Load and save (DLOG 200/201/212, 348×218 and 493×272) are the largest; see D5.
  - The screen-size dialog (DLOG 1000) is D4.
  - StandardFile (`Pack3`) appears only in unreached code [M]. Confirm with the
    runtime trap log (M0.2) before implementing it.
- **Events.**
  - `WaitNextEvent` (sleep ignored) and `GetNextEvent` deliver key, mouse,
    update and activate events.
  - `GetKeys` returns the live KeyMap. Shift is run, arrows move, Space is action,
    as on the Mac [external: VOGONS; confirm in the manual `tmp/manual.pdf`].
  - `Button`, `StillDown`, `GetMouse`, `FlushEvents`, `SystemTask`, `SystemClick`
    (no desk accessories: return) and `ObscureCursor`.
  - Apple Events (`Pack8`): install handlers and succeed; `AEProcessAppleEvent`
    is never reached without high-level events. `OpenDeskAcc` and the scrap calls
    are loud stops until reached.
- **Keyboard mapping.** Amiga raw keys map to Mac virtual keys through the
  existing table, extended for the keys the game reads.

### 4.10 Audio: SoundMusicSys on Paula

The music driver is original 68k code and stays so (the fidelity rule). The port
implements the Sound Manager 3 surface it uses (tasks M4.1–M4.3):

- **Version and channel.** `SndSoundManagerVersion` returns 3.x, which avoids the
  legacy hardware path. `SndNewChannel(sampledSynth, initMono…)` creates a channel.
  `SndDoImmediate`, `SndDoCommand` and `SndDisposeChannel` cover the commands the
  census finds.
- **`SndPlayDoubleBuffer`.**
  - Keep a ring of N driver-sized buffers (N≈6, 370 bytes each, about 100 ms).
  - At every safe user-mode point (trap boundary, as for VBL tasks), refill empty
    ring slots by calling the driver's doubleBack procedure. It runs the sequencer
    and the mixer.
  - The Paula audio interrupt only advances pointers through the ring. No Mac code
    runs at interrupt time (CLAUDE.md).
  - Play mono on two channels at period 161, which is 22,030 Hz on PAL and 22,222
    Hz on NTSC. Either correct the rate or accept a measured sub-1% pitch shift,
    and record which (M4.2).
- **Underruns.** If safe points are ever more than about 100 ms apart, the ring
  runs dry. Log it (probe counter) and repeat silence rather than stall. M5
  measures the worst gap. Add a safe point in the renderer only through a verified
  hook, and only if measurement demands it.
- **Sound Manager volume.** SdVolume/`GetSoundVol` feeds the driver's volume
  scaling. Options > Sound Effects and Music toggle through the driver's own
  selectors.
- **MIDI Manager.** `MIDISignIn` and the related calls answer "not installed", so
  there is no external MIDI.
- **Sample effects.** Check the runtime trap log to see whether the game plays
  `LISTSAMP.PAK` samples through the driver's sound-effect selectors (the census
  shows no other Snd traps [M]). If so, they mix in the same stream.
- **CPU cost.** A 22 kHz software synth is the largest CPU unknown on a 68030
  (risk R2). Measure it in M4.3. SoundMusicSys picks a lower quality or rate on
  slow machines (`jxAnalyzeQuality`) [external: SoundMusicSystem.h]. Find out
  which selector and argument the game passes before considering any change;
  changing the rate is a game decision and needs the owner (D8).

### 4.11 Text and fonts

The Mac layer draws text in dialogs, menus and the in-game messages ("You're
ready to fight!", "The game is paused!"). It uses the System font (Chicago 12),
Geneva, and Times, which the startup check requires [M: STRS]. The port may not
ship Apple fonts.
- Supply bitmap fonts as port resources (`FONT`/`NFNT` family records) generated
  from freely licensed outlines that match the metrics (for example Liberation
  Serif for Times), by a committed generator tool (task M2.9, see D6).
- `GetFNum`, `TextFont`, `TextSize`, `TextFace` (bold and italic synthesized
  where no strike exists) and `DrawText` use them.
- The engine's own in-game font (ITD_RESS.PAK) is drawn by the original code and
  needs nothing.

### 4.12 Time, VBL, pacing

- **Clock.** `TickCount` and the `Ticks` shadow run at 60 Hz from the 50 Hz VBI,
  inheriting Vette's one extra tick every fifth field.
- **VBL tasks.** Keep them at safe points. Core's task runs through the generated
  system-heap stub, and the dispatcher calls the stub, not a guessed target, so
  the game's own A5 handling applies. Dark's re-arming task runs the same way.
- **Pacing.** Present at most once per field. The engine is tick-driven, but its
  track and animation steps advance once per frame [external: speedrun KB]. Too
  high a frame rate breaks the attic-stairs descent on the PC and the Mac alike,
  so D3 decides the cap. Regression R-stairs (M6.3) guards it either way.

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
  - preloaded data;
  - saves through resload.

  No original data, ROM, System software or WHDLoad binary is distributed.

## 5. Owner decisions

These change scope or behaviour. Each has a recommended default. The
implementing agent works to the default until the owner changes it, and records
the answer in the relevant section.

| ID | Decision | Default | Why |
| --- | --- | --- | --- |
| D1 | Memory strategy | **Preload all data; 16 MB fast recommended, about 12 MB minimum** | 3 MB zone + 5.2 MB data + 1.4 MB app fork + screens ≈ 10.5 MB. On-demand streaming would mean keeping DOS alive during play (a new takeover model) to get down to about 8 MB. 4 MB is not reachable without also streaming resources. |
| D2 | Performance target | **68030/50 is where performance is judged; 68020 must boot and play, however slowly** | The Mac recommended a 68040. A 386DX-20 already ran the DOS version choppily [external]. |
| D3 | Frame-rate cap | **Cap presentation at 25 Hz (every second PAL field) during gameplay** until M6.3 measures the stairs threshold, then set the cap from that measurement | The stairs bug is a frame-rate bug. A cap preserves fidelity on 040/060 without affecting a 030, which runs below it. |
| D4 | Screen-size dialog | **Answer "320 X 200" (item 2) in `ModalDialog` for DLOG 1000 without showing it**, as a documented fixed configuration | 640×400 is unsupported. Showing an option that cannot work would mislead. The choice is saved in PREF as on the Mac. |
| D5 | Dialogs wider than 320 | **Pan: while a dialog wider or taller than the viewport is frontmost, the viewport follows the pointer** | Keeps lores only and shows the Mac dialog unmodified. The alternative, a hires or overscan dialog mode, conflicts with the lores-only decision. |
| D6 | Fonts | **Generated bitmap fonts from freely licensed outlines (Liberation Serif/Sans, SIL OFL: ship the licence, and rename the derivative because "Liberation" is a Reserved Font Name), shipped with the port** | Apple fonts cannot be shipped. Metric-compatible fonts keep dialog layout. |
| D7 | Menus | **Right-Amiga shortcuts always, plus the Mac menu bar shown while the right mouse button is held** (the viewport scrolls to include it) | Load and save exist only in the File menu. The RMB menu is the Amiga idiom. |
| D8 | Music quality | **Run MDRV exactly as the game configures it**; revisit only with M4.3 numbers | Fidelity first. |

## 6. Verification

| Change | Required evidence |
| --- | --- |
| Pure helper (heap, regions, fonts, PAK tools) | Host unit test in `tools/`, run by `make host-tests` |
| Loader / low-memory patch | Original-byte checks. `a5world_check.py`. Bounded diag run reaching the next loud stop, reported by `runtime_status.gdb` |
| New trap | Bounded run past the old loud stop. Where the result is observable, compare with the MAME trap log (M0.2) for the same call's arguments and results |
| Display / QuickDraw | State-pair frame compare with MAME: same game state, same RNG seed, 8-bit framebuffer + CLUT from both sides (`tools/compare_frames.py`, M2.10) |
| Audio | Event log (selector, song, note, instrument) against MAME. Paula ring underrun counter = 0 over the regression |
| Performance | `PROBES=1` full-accounting profile on the 68030/50 config, run twice, ms per frame by phase |
| Release | `make release-check` and WHDLoad smoke/boot/load/quit tests |

**Emulator configurations** (FS-UAE via `amiga/diag_run.sh`, `AMIGA_CONFIG=`,
task M0.6). Pin them explicitly: today the scripts leave the CPU to the model
default, and run.sh contradicts its own comment.

| Name | Model | CPU | Chip / fast | Use |
| --- | --- | --- | --- | --- |
| `a1200-020` | A1200 | 68EC020 14 MHz | 2 MB / 8 MB | Minimum. Boot and play regression |
| `a1200-030` | A1200 + 68030/50 | 68030 50 MHz, MMU off | 2 MB / 16 MB | **Default for development and profiling** |
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
- `audio`: music plays, 0 underruns.
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
| **M4 Audio** | Sound Manager 3 on Paula; MDRV runs | Music and effects in intro and play; event log matches MAME; 0 underruns in `audio` |
| **M5 Performance** | Profile and optimise on 68030/50 | Documented ms/frame by phase; gameplay frame rate at or above the D3 cap in the first rooms |
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
| R1 | Game too slow on a 68030 (3D engine + CopyBits + C2P) | Profile from the first playable frame (M3). Dirty-box C2P; fast srcCopy; FMODE; asm hot traps. Keep the original rasteriser |
| R2 | SoundMusicSys mixing cost | Measure in M4.3. The ring hides jitter, not cost. D8 escalates |
| R3 | Audio underruns from long trap-free stretches | Measure the worst safe-point gap. Add a verified hook only if needed |
| R4 | Stairs bug on fast CPUs | D3 cap + `stairs` regression |
| R5 | Memory (D1) | Zone sized by SIZE; preload measured; 12 MB minimum documented |
| R6 | Font metrics change dialog layouts | Metric-compatible generation; state-pair compare of dialogs |
| R7 | Save-game loss (deferred writes) | Write-through at close (4.5), WHDLoad resload |
| R8 | Hidden reliance on 24-bit master-pointer flags or on handle movement | Census found none. Zone allocator tests; M1.5 checks for `StripAddress`-free flag reads |
| R9 | Unreached-code surprises (StandardFile, desk accessories) | Runtime trap log across a full manual session in MAME (M0.2, repeated in M6) |

## 10. Numbers to keep current

| Item | Value |
| --- | --- |
| Jump table | 468 entries; A5 below 75,616 / above 3,776 |
| DATA / ZERO / DREL | 11,418 / 560 / 678 bytes; 276 DREL entries (255 A5, 21 STRS) |
| CREL | 7,329 entries; 7,210 even (A5), 119 odd (STRS) |
| Live trap sites / distinct | 1,115 / 242 (census, M0.1) |
| `SIZE` | 3,145,728 preferred and minimum |
| Data files | `Alone Data` 5.2 MB; app resource fork 1.4 MB |
| MDRV | 12,630 packed → 29,256 bytes; 22,254.5 Hz, 2×370-byte buffers |

## 11. Trap census (live walk)

Live sites / distinct traps: 1,115 / 242, from main, CODE 1, the DATA function
pointers and code references [M]. The grouped table with sites is generated by
`make trap-census` (M0.1). Until then it is in local `tmp/plan/traps.md`. The
current runtime handles about 87 of the 242; the rest arrive as loud stops. By
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
