# Open work

This is the work queue. Work it from the top, one item per commit; split an item
only if it has independent parts. Delete an item in the commit that finishes it,
because the Git log records finished work. The design and its rationale are in
[design.md](design.md), cited below by § number; owner decisions D1–D8 are in
design.md §5.

**Current state:**
- The executable builds and loads the original resource fork.
- It builds the A5 world with pre-resolved jump entries, then stops at
  `SEGMENT LOADER / CREL RELOCATION` on CODE 3 "Core".
- The original runs in MAME on the System 7.5.5 reference volume.

Each item gives the **goal**, then the scope, then *done when*: the evidence
required.

## M0 Groundwork

- **M0.1 Trap census tool.**
  - Promote `tmp/plan/census.py` to `tools/trap_census.py`. It is a CREL-aware
    recursive descent that starts from main, CODE 1, the DATA function pointers,
    and jump-table and PC-relative code references, and it decodes selectors.
  - Generate trap names from the cxmon list, as Vette's `tools/gen_trap_names.py`
    does.
  - `make trap-census` writes `tmp/trap-census.md`.
  - Add `--selftest` fixtures for branch following, CREL JSR and the switch idiom.
  - Fix `tools/m68k_lowmem.py` to skip CREL-relocated and `PEA #imm.w` operands.

  *Done when* the census reports 1,115 live sites and 242 distinct traps, the
  self-test passes, and `make lowmem-scan` lists only true Page-0 references.
- **M0.2 MAME runtime trap log.**
  - Write `tools/mac_traps.lua`, modelled on Vette's `mac_traps.lua`. It taps the
    ROM Line-A dispatch on the 7.5.5 volume and logs:
    - the trap word and selector;
    - key arguments and results;
    - the caller (segment, offset), resolved from the live jump table and segment
      handles.
  - Log only while `CurApName` is the game.
  - Script a session: launch, 320×200, intro, new game, first room, Save Game,
    Open Game, Quit.

  *Done when* the log's distinct trap set is a subset of the census live set (the
  commit lists any differences), and the log answers three questions:
  - Is `Pack3` reached?
  - Which MDRV selectors and arguments does the game use?
  - Do `LISTSAMP` effects go through MDRV?
- **M0.3 68020 build.**
  - Build C/C++ and gas with `-m68020 -mtune=68030`.
  - Retire the mul/div audit and `m68k_math.h`, add a no-soft-float audit, and
    keep the probe audit.
  - Update CLAUDE.md, development.md and static-map.md "CPU requirements".

  *Done when* a clean build links with both audits passing and the boot run still
  reaches the same loud stop.
- **M0.4 Remove HIRES and Vette display residue.**
  - Drop `HIRES`, `StartupConfig.s`/`aitd_hires_value`, and the interlace and LOF
    code and probes.
  - Remove references to the non-existent `docs/mac-hardware.md`.
  - Fix run.sh's model/memory contradiction.

  *Done when* the clean build and boot run are unchanged apart from the removed
  code, and `git grep -i hires` is empty outside the framework.
- **M0.5 8-bit reference framebuffer probe.**
  - Make `tools/mac_probe_fb.lua` and `tools/fb_to_png.py` handle the mdc48 8-bit
    mode and its 256-entry CLUT.
  - Capture the game window after the palette is active.

  *Done when* a PNG of the Infogrames logo from MAME matches a snapshot by eye,
  and the CLUT dump shows clut 128's colours at the expected indices.
- **M0.6 Pinned emulator configurations.**
  - Add `AMIGA_CONFIG=a1200-020|a1200-030|a4000-040|a1200-060` to
    `amiga/run.sh`, `diag_run.sh` and `debug.sh`.
  - Each config sets the CPU, AGA chipset and chip/fast sizes explicitly (design
    §6). The default is `a1200-030`.

  *Done when* each config boots to the current loud stop in a bounded run, and
  `runtime_status.gdb` prints the CPU type it saw.
- **M0.7 Regression harness skeleton.**
  - Add `amiga/regression.sh` and `make regression`, with the `boot` case: a PASS
    regex, and any loud stop counts as failure.
  - Add a `make host-tests` target.

  *Done when* `make regression` passes `boot` on `a1200-030`.

## M1 Boot to main

- **M1.1 Line-A correctness.**
  - Install the vector through VBR, saving and restoring the old one.
  - On OS-trap return (trap bit 11 clear), set the CCR from D0.W.
  - Dispatch `$AB1D` on D0's low word.
  - Give the Mac code a 64 KB stack.
  - Set `CurStackBase` and `CurrentA5` as in design §4.2.

  *Done when* a gdb check shows the handler at VBR+$28 and the old vector restored
  on exit, and a unit-style probe confirms the CCR after an OS trap.
- **M1.2 A5 world host model.**
  - Write `tools/a5world_check.py`, a port of `tmp/plan/a5world.py`. It expands
    DATA/ZERO and applies DREL exactly as CODE 1+$0118 does.
  - It compares the result with a gdb dump of the Amiga A5 world at `main` entry.

  *Done when* the tool's self-check passes on the resource bytes. M1.3 uses it as
  its acceptance check.
- **M1.3 Original startup path.**
  - Load CODE 1 only. Jump-table entries 0–9 get the loaded form; the rest stay
    unloaded.
  - Zero the A5 world, copy in the jump table, and enter at CODE 1+$14.
  - Make trap patching real: `GetTrapAddress` returns stubs that run the
    built-ins, and `SetTrapAddress` routes with the Mac register conventions.
  - Implement `GetOSTrapAddress`, `StripAddress` (identity), `_vCacheFlush`,
    `HWPriv` 1/3, `SysError` (as a loud stop) and `LoadTrap` = 0.
  - Remove the resident pre-resolution and the CREL stop.

  *Done when*:
  - `a5world_check.py` matches;
  - CODE 1's `_LoadSeg` handler loads and relocates CODE 3 (gdb: header bit 15
    clear, and a known CREL long equals the original + A5);
  - the next loud stop is inside `main`'s initialisation.
- **M1.4 Low-memory shadows.**
  - Patch the live set's `abs.w` references to `d16(A5)` in the shadow area,
    after byte checks (design §4.3). Apply the patches when a CODE handle is
    created.
  - Fail before takeover if any site count differs.
  - The VBI updates the Ticks shadow.

  *Done when* `make lowmem-scan` and the patch table agree exactly, and no
  unpatched Page-0 reference remains on reachable paths.
- **M1.5 Application zone.**
  - Write a Mac-compatible zone allocator (design §4.4), with host tests in
    `tools/test_mac_heap.cpp`, plus a system zone.
  - Complete the Memory Manager call set.
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

## M2 Startup to intro

- **M2.1 In-memory volume and File Manager.**
  - Preload `Alone Data`, prefs and saves (design §4.5).
  - Implement the census File Manager set and path handling. Unknown paths are
    loud stops.

  *Done when* the game opens and reads `ITD_RESS.PAK` and `PRESENT.PAK`, and the
  bytes it reads match the host file (gdb checksum).
- **M2.2 Resource Manager completion.**
  - Implement the design §4.6 call set and resource files in the volume.
  - The `MDRV` load/decrypt/unpack path runs; the driver does not produce sound
    yet.

  *Done when* the game's MDRV entry pointer at A5−$6AC points at a block whose
  bytes equal `tmp/plan/MDRV_11.bin`.
- **M2.3 8-bit QuickDraw core.**
  - Generalise the screen, GWorld, PixMap, CTable, ITable, CopyBits and PICT code
    to 8 bpp.
  - Remove the Vette palette maps and caps.
  - Implement the full QDOffscreen set reached so far.

  *Done when* host checks of 8-bit CopyBits (srcCopy and colour mapping) pass, and
  the run proceeds past GWorld creation.
- **M2.4 Mac screen model.**
  - A 640×480×8 main screen with a GDevice list, and windows over it.
  - The viewport follows the front window.
  - Handle DLOG 1000 as in D4.

  *Done when* the game creates WIND 128 and the viewport rectangle equals its
  content rectangle.
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
  activates clut 128.
- **M2.8 Regions and polygons.** Implement real QuickDraw regions and polygons,
  with host fixtures.

  *Done when* the host tests pass and region-clipped draws in the screens reached
  so far match MAME.
- **M2.9 Fonts.** A generator tool for bitmap font families (D6), plus the Font
  Manager and text calls.

  *Done when* the About box and the "paused" message render with glyph metrics
  matching MAME's within the documented tolerance.
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
- **M3.2 Menus.** Implement MenuSelect, MenuKey and the census menu set, with the
  D7 presentation.

  *Done when* ⌘O, ⌘S, ⌘Q and the Options items work from both the Right-Amiga keys
  and the RMB menu.
- **M3.3 Dialogs.**
  - ModalDialog, alerts, and item handling for DLOG 128/131/200/201/212 and ALRT
    128.
  - D5 panning.

  *Done when* the new-game, save-warning, save and load dialogs work and match
  MAME frames.
- **M3.4 Apple Events and misc Toolbox.**
  - Pack8 handler installation.
  - The SANE ops at Engine $47C2–$4852; identify each one.
  - SysBeep as a Paula click.
  - The remaining Window Manager calls.

  *Done when* no loud stop occurs in a 10-minute manual session covering the first
  floor.
- **M3.5 `newgame` and `saveload` regressions.**
  - Scripted key input in the Amiga runner.
  - PASS records keyed on game state: the room, and actor positions read from the
    A5 world.

  *Done when* both cases pass on `a1200-030`.
- **M3.6 Durable writes.**
  - Write-through of closed written files (saves, prefs), through a controlled
    OS-return window.
  - A ledger of pending writes.

  *Done when* a save survives an emulator reset made immediately after the game
  reports it saved.

## M4 Audio

- **M4.1 Sound Manager 3 surface.**
  - SndSoundManagerVersion, SndNewChannel, SndDoCommand/SndDoImmediate and
    SndDisposeChannel.
  - MIDI Manager answers "not installed".
  - SdVolume and GetSoundVol.

  *Done when* MDRV takes the Sound Manager 3 path (gdb: `SndPlayDoubleBuffer` is
  reached, the legacy VInstall path is not).
- **M4.2 Double buffer on Paula.**
  - A ring of driver buffers, refilled at safe points.
  - The Paula interrupt only advances pointers.
  - Record the sample-rate decision.

  *Done when* the intro music plays and the underrun counter stays at 0 over the
  `audio` case.
- **M4.3 Audio fidelity and cost.**
  - Compare the event log with MAME: song, instrument, note order.
  - Measure the driver's CPU cost per second on `a1200-030` and `a1200-020`.

  *Done when* the logs match and the cost is recorded in amiga-arch.md. If the cost
  threatens the frame budget, raise D8 with the numbers.

## M5 Performance

- **M5.1 Full-accounting profile.**
  - A PROBES build and a gameplay scene, on `a1200-030`, run twice.
  - Report ms/frame by phase: game code, drawing traps, CopyBits, C2P, palette,
    audio refill.

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

  *Done when* gameplay meets the D3 cap in the first rooms, or the owner accepts
  the measured rate.
- **M5.3 Safe-point gap audit.**
  - Measure the worst interval between trap boundaries during gameplay.
  - Add a hook only if the gap exceeds the ring length.

  *Done when* the gap is recorded and underruns stay at 0.

## M6 Completion

- **M6.1 Full manual play-through,** in MAME and on `a1200-030`, with the runtime
  trap log. Implement every new trap and path it finds.

  *Done when* the game can be finished on the Amiga with no loud stop.
- **M6.2 State-keyed fidelity set.** Frame compares for representative rooms,
  inventory, book/reading views, fights, death and the ending.

  *Done when* all of them pass.
- **M6.3 Stairs and pacing.**
  - Measure the frame-rate threshold of the attic-stairs bug, on MAME at different
    speeds and on the Amiga configs.
  - Set D3 from that measurement.
  - Add the `stairs` regression on `a1200-060`.

  *Done when* the descent completes on every config.
- **M6.4 Quit and cleanup.** A `quit` regression: all ledgers empty, the OS
  restored, and both Workbench and Shell starts work.

  *Done when* it passes on all configs.

## M7 Release

- **M7.1 Installer:** Vette's `install-data` extractor, an Installer script and
  icons, run against `AloneInTheDark.img_.sit` with the known hashes checked.
- **M7.2 WHDLoad slave,** from `VetteSlave.s`: EmulLineA, a 64 KB stack, preload,
  and saves through resload, with the WHDLoad test modes.
- **M7.3 Packaging and 1.0:**
  - a deterministic LHA;
  - `make release-check`;
  - README requirements from measured numbers;
  - VERSION 1.0.
