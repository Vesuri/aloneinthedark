# Open work

This is the work queue. Work it from the top, one item per commit; split an item
only if it has independent parts. Delete an item in the commit that finishes it,
because the Git log records finished work. The design and its rationale are in
[design.md](design.md), cited below by § number; owner decisions D1–D8 are in
design.md §5.

**Current state:**
- The executable builds and loads the original resource fork.
- Original CODE 1 expands the A5 world, relocates Core and enters `main`, then
  stops at `MEMORY MANAGER / NEWHANDLECLEAR`, Engine+$004A.
- The original runs in MAME on the System 7.5.5 reference volume.

Each item gives the **goal**, then the scope, then *done when*: the evidence
required.

## M1 Boot to main

- **M1.5 Application zone.**
  - Write a Mac-compatible zone allocator (design §4.4), with host tests in
    `tools/test_mac_heap.cpp`, plus a system zone.
  - Complete the Memory Manager call set; publish its MemErr ($0220) and
    ApplLimit ($0130) state into the M1.4 shadows.
  - Resources become handles in the zone, with aligned copies where needed.

  *Done when* the host tests pass, `FreeMem` after startup is within a documented
  margin of the MAME value at the same point (read via the trap log), and the boot
  run proceeds.
- **M1.6 System identity.**
  - `Gestalt` answers as the reference machine: 'sysv' $0755, 'proc' 68030,
    'qd  ' 32-bit QD, 'qtim' absent, and 'help', 'fold', 'evnt' and 'a/ux' as on
    the reference.
  - `SysEnvirons` reports System 7.5.5 on a Mac IIx, and SysVersion $15A = $0755.
  - Take the values from MAME, not from memory.

  *Done when* the startup checks pass without "requires" alerts, and the commit
  cites the values from a MAME capture.
- **M1.7 System windows and user-mode services.**
  - The Line-A handler can divert a trap to a user-mode service trampoline.
  - A system window (design §4.1) hands the machine back to the OS for a bounded
    operation, and takes it back afterwards.
  - The display (our copper) and Paula keep running through the window; Ticks are
    corrected; the keyboard state is flushed.
  - A file-interface abstraction with a DOS backend (in a window) and a WHDLoad
    backend (resload).

  *Done when* a probe case reads a 1 MB file in 64 KB chunks through windows on
  `a1200-020` and `a1200-030` with the picture stable (snapshot) and the bytes
  correct (checksum), and the entry/exit cost per window is recorded.

## M2 Startup to intro

- **M2.1 Catalog and File Manager.**
  - Build the startup catalog of `Alone Data`, saves and prefs (no data read).
  - Implement the census File Manager set with per-fork chunked read buffers
    through system windows (design §4.5). Unknown paths are loud stops.

  *Done when* the game opens and reads `ITD_RESS.PAK` and `PRESENT.PAK`, the bytes
  it reads match the host file (gdb checksum), and the window count for startup is
  recorded.
- **M2.2 Resource Manager on demand.**
  - Keep only the resource maps in memory; load data into zone handles on
    `GetResource` through system windows.
  - Implement the design §4.6 call set, the writable prefs/save forks, and the
    port overlay fork (empty at first) first in the search order.

  *Done when* the application no longer loads its whole fork at startup, and the
  run reaches the same point as before with the same resource bytes (gdb checksum
  of a sample).
- **M2.3 8-bit QuickDraw core.**
  - Generalise the screen, GWorld, PixMap, CTable, ITable, CopyBits and PICT code
    to 8 bpp.
  - Remove the Vette palette maps and caps.
  - Implement the full QDOffscreen set reached so far.

  *Done when* host checks of 8-bit CopyBits (srcCopy and colour mapping) pass, and
  the run proceeds past GWorld creation.
- **M2.4 Mac screen model and 320×200 only.**
  - A 640×480×8 main screen with a GDevice list, and windows over it.
  - A fixed viewport on WIND 128's live content rectangle; M0.5 measures
    (160,150)–(480,350) after positioning, not the initial resource bounds.
  - No screen-size dialog (D4): pick the seam by byte check (a port-supplied
    `PREF`, or `ModalDialog` for DLOG 1000) and document it.

  *Done when* a fresh start (no prefs) never shows DLOG 1000, the game creates
  WIND 128, and the viewport equals its content rectangle.
- **M2.5 AGA 8-plane display.**
  - Lores 320×200×8 in `AitdScreen`.
  - A 256-colour copper palette through BPLCON3 banks, plus the sprite bank.
  - Publication in the VBI.

  *Done when* a test pattern and a 256-colour ramp display correctly (by eye, plus
  a gdb register dump) on `a1200-030` and `a1200-020`.
- **M2.6 8-bit C2P with dirty rectangles.**
  - An asm kernel based on Kalms' `c2p1x1_8_c5_030`, with a C oracle under
    `VERIFY=1`.
  - Rectangles aligned to 32 pixels.

  *Done when* the verifier reports zero mismatches over the intro, and the
  full-screen cost is measured on `a1200-030`.
- **M2.7 Palette Manager realisation.** Implement NewPalette, SetPalette,
  ActivatePalette, GetCTable and PaletteDispatch as on the 8-bit reference.

  *Done when* the device CLUT equals the MAME capture (M0.5) after the game
  activates clut 128, including the three duplicate endpoint slots observed
  in M0.5 (1, 15, 191).
- **M2.7a Reference video colour transfer.**
  - Reproduce the measured mapping from logical RGB16 to mdc48 output colours
    in the AGA palette, using a verified integer lookup/transfer (no guessed gamma).
  - Preserve the distinct logical CLUT for original QuickDraw/Palette calls.

  *Done when* host fixtures cover the measured channel mapping, and the
  Infogrames palette and a 256-level reference ramp match the MAME video palette.
- **M2.8 Regions and polygons.** Implement real QuickDraw regions and polygons,
  with host fixtures.

  *Done when* the host tests pass and region-clipped draws in the screens reached
  so far match MAME.
- **M2.9 Placeholder fonts.**
  - Placeholder bitmap fonts in the overlay for the Mac-font uses found in M0.2
    (D6).
  - The Font Manager and text calls.

  *Done when* every Mac-font text reached so far renders legibly and in the right
  place (compared with MAME frames), and no font loud stop remains.
- **M2.10 Frame compare.**
  - Write `tools/compare_frames.py`.
  - Add the fixed-seed hook on both sides and the state keys for the intro.

  *Done when* the Infogrames logo and three intro states match MAME
  pixel-for-pixel, or with documented and explained differences, and the `intro`
  regression case passes.

## M3 Playable

- **M3.1 Events and keyboard.**
  - Implement WaitNextEvent, GetNextEvent, GetKeys, Button, StillDown,
    FlushEvents, SystemClick and ObscureCursor.
  - Map Amiga keys to the game's keys; confirm them against `tmp/manual.pdf`.

  *Done when* a new game can be started, and Carnby walks, runs (Shift) and acts
  in the first room.
- **M3.2 Menus without a menu bar.**
  - Keep menus as data and never draw the menu bar (D7).
  - `MenuKey` maps Right-Amiga to the game's Command-key items. Rely on the game's
    keys for everything M0.2 showed they cover.

  *Done when* load, save, quit, sound and music are reachable from the keyboard,
  and nothing draws outside the viewport.
- **M3.3 Dialogs within 320×200.**
  - ModalDialog, alerts, and item handling for the dialogs the game reaches.
  - Overlay `DLOG`/`DITL` layouts inside WIND 128's content for those that do not
    fit (D5; 200, 201 and 212 so far), generated by a committed tool.

  *Done when* the new-game, save-warning, save and load dialogs work entirely
  inside the viewport, and their behaviour matches MAME.
- **M3.4 Apple Events and misc Toolbox.**
  - Pack8 handler installation.
  - The SANE ops at Engine $47C2–$4852; identify each one.
  - The remaining Window Manager calls.

  *Done when* no loud stop occurs in a 10-minute manual session covering the first
  floor.
- **M3.5 `newgame` and `saveload` regressions.**
  - Scripted key input in the Amiga runner.
  - PASS records keyed on game state: the room, and actor positions read from the
    A5 world.

  *Done when* both cases pass on `a1200-030`.
- **M3.6 Durable writes.**
  - Write-through of closed written files (saves, prefs) in a system window.
  - A ledger of pending writes.

  *Done when* a save survives an emulator reset made immediately after the game
  reports it saved.

## M4 Audio

- **M4.1 Driver interface.**
  - Decode every SoundMusicSys selector the game uses (M0.2 log,
    `tmp/plan/MDRV_11.bin`, `SoundMusicSystem.h`).
  - Choose the install point by byte check (`Jnth` resource or the Core+$1CC6
    store) and install a native driver stub. Unimplemented selectors are loud
    stops. The original MDRV never runs.

  *Done when* the game runs through the intro with the native driver answering
  every selector it calls, with no loud stop and no sound yet.
- **M4.2 Music on Paula voices.**
  - A native SONG/MIDI sequencer and INST→`snd ` mapping on the four channels.
  - Tempo from the VBI tick counter, run at safe points.
  - Measure the songs' maximum simultaneous notes; record the voice-allocation
    policy.

  *Done when* all 8 songs play recognisably, and their event logs (note, instrument
  and order) match the MAME reference within the documented voice-stealing
  differences.
- **M4.3 Sound effects and toggles.**
  - Effects through the driver's selectors take priority on the channels.
  - The S/M keys and the game's toggles work.
  - `SysBeep` becomes a short Paula click.

  *Done when* the `audio` regression passes and effects in the first rooms match
  MAME by event.

## M5 Performance

- **M5.0 Deferred CPU compatibility configurations.**
  - Revisit 68030/68040/68060 only after the functional milestones on 68020.
    Add explicit configurations and verify ROM compatibility, actual CPU and
    OS-visible RAM before using them for later profiling/stairs checks.
  - The exploratory 68040 run failed before the loader, with Z3 fast RAM not
    configured by the selected ROM; it is not a supported configuration.

  *Done when* each added configuration reports its intended CPU and available
  memory, and passes all regression cases implemented so far in bounded runs.
- **M5.1 Full-accounting profile.**
  - A PROBES build and a gameplay scene, on `a1200-020` and `a1200-030`, run
    twice.
  - Report ms/frame by phase: game code, drawing traps, CopyBits, C2P, palette,
    audio sequencer, system windows.

  *Done when* the table is in amiga-arch.md.
- **M5.2 Optimise by the profile.**
  - One measured optimisation per commit, with before and after numbers. Record
    rejected attempts in their commit message.
  - Candidates:
    - dirty-box C2P tuning;
    - FMODE;
    - a fast srcCopy;
    - a fast path for the SetGWorld/GetGWorld traps (138 sites);
    - a TickCount fast path.

  *Done when* the profile shows no remaining optimisation worth its risk, and the
  frame rates on both configs are recorded in README.
- **M5.3 Safe-point gap audit.**
  - Measure the worst interval between trap boundaries during gameplay; the
    sequencer and VBL tasks only run at those points.
  - Add a verified hook only if audible timing suffers.

  *Done when* the gap is recorded, and music timing is steady by event log.
- **M5.4 Memory minimum.**
  - Measure the peak zone use and the port's fast/chip use through a full session.
  - Find the smallest fast RAM that plays.

  *Done when* README states the measured requirement.

## M6 Completion

- **M6.1 Full manual play-through,** in MAME and on `a1200-030`, with the runtime
  trap log. Implement every new trap and path it finds.

  *Done when* the game can be finished on the Amiga with no loud stop.
- **M6.2 State-keyed fidelity set.** Frame compares for representative rooms,
  inventory, book/reading views, fights, death and the ending.

  *Done when* all of them pass.
- **M6.3 Stairs check.**
  - Add the `stairs` regression (attic → storeroom descent) on every config,
    including `a1200-060`.
  - No frame cap (D3). If the descent fails anywhere, file a separate item for
    the owner, with the measured frame rate.

  *Done when* the case runs on all configs and its result is recorded.
- **M6.4 Quit and cleanup.** A `quit` regression: all ledgers empty, the OS
  restored, and both Workbench and Shell starts work.

  *Done when* it passes on all configs.
- **M6.5 Engine font for Mac-font text** (D6, eventually). Replace the
  placeholder fonts with the game's own font, from `ITD_RESS.PAK` or the PC
  version, for the texts M2.9 covers.

  *Done when* the texts render in the game's font and match the layout of MAME
  frames.

## M7 Release

- **M7.1 Installer:** Vette's `install-data` extractor, an Installer script and
  icons, run against `AloneInTheDark.img_.sit` with the known hashes checked.
- **M7.2 WHDLoad slave,** from `VetteSlave.s`: EmulLineA, a 64 KB stack, the
  resload file backend (chunked reads, saves), with the WHDLoad test modes.
- **M7.3 Packaging and 1.0:**
  - a deterministic LHA;
  - `make release-check`;
  - README requirements from measured numbers;
  - VERSION 1.0.
