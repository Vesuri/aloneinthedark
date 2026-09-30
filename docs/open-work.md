# Open work

This is the work queue. Work it from the top, one item per commit; split an item
only if it has independent parts. Delete an item in the commit that finishes it,
because the Git log records finished work. The design and its rationale are in
[design.md](design.md), cited below by § number; owner decisions D1–D8 are in
design.md §5.

**Current state:**
- Original CODE 1 loads, expands the exact A5 world, relocates Core and enters
  startup on the 68020 without an FPU. Resources and hidden compatibility state
  support the measured initialization path; original MDRV code is never loaded.
- MacPlay and the Infogrames logo have exact paired client pixels/colours. Nine
  AGA publications pass memory/copper checks. Full intro acceptance remains open.
- The next stop is QuickDraw PaintRect, Dan2+$0D52 ($A8A2).
  Intro LineTo matches the Mac; the first raw effect plays on Paula and its
  real polling loop observes completion with sample/DMA cleanup verified.
  Detailed completed service contracts and regression evidence are in
  [development.md](development.md). No Mac dialogs, menu bar or chrome are drawn.
- The original runs in MAME on the System 7.5.5 reference volume.

Each item gives the **goal**, then the scope, then *done when*: the evidence
required.

## Pending verification (owner-deferred)

- **M1.7b2 Rendered-picture acceptance for system windows — pending.**
  Owner update 2026-09-28: window access is not granted; inspect Slicks,
  Rescue on Fractalus, Revs and Vette, and leave screenshot verification pending
  if their methods cannot supply it. This is not a completed acceptance check.
  The active implementation queue resumes at M2.1 below.
  - M1.7b1's `window-core` verifies 1 MB/64 KB reads, exact bytes/clock,
    Paula interrupts, keyboard flush, DOS errors/save/readback, native resload
    ABI and bitplane snapshots on 68020. Memory snapshots do not prove video.
  - Slicks exports logical pixels/BMPs, not actual FS-UAE output. Revs/Vette
    use F12+S. Rescue's rendered captures use host Screen Recording permission.
    Revs additionally warns that remote-debugger runs grey/freeze the display;
    paused GDB checkpoints cannot establish appearance.
  - A local diagnostic app bundle makes the emulator discoverable, but computer
    use is not approved. Do not retry window access or substitute host event
    injection/capture for that denied access. GDB `monitor sc` is unsupported.
  - Future verification needs an authorized live emulator video capture before,
    during and after a window. If the OS changes the active copper/display,
    instrument and fix it before accepting the picture.

  *Done when* actual rendered snapshots are stable through the 1 MB/64 KB probe,
  `window-core` and production `boot` pass, and the window entry/exit cost is
  recorded with the full acceptance result. Only then is M1.7b complete.

## M2 Startup to intro

- **M2.3g27 Native driver selector 20 — final integration acceptance.**
  - The first-match identifier/status contract is implemented. Original active,
    completed, stopped-state, missing-ID and duplicate-ID cases are measured;
    host tests cover them. The native route proves active-query ABI/results.
  - The offscreen PaintRect and LineTo prerequisites are complete. The latest
    integrated run (`tmp/m2-lineto-native-accept.log`, exit zero) now proves
    199 active results followed by a completed query, with natural cleanup.
  - Confirm and record this final integration acceptance against the original
    status sequence; the shared LineTo regression run already supplies evidence.

  *Done when* original/native status sequences and results agree through an
  actual completed query, startup reaches its next named stop with MDRV absent,
  and the effect, logo/palette/AGA/startup regressions pass.
- **M2.3g29 Later intro PaintRect.**
  - After LineTo and the completed effect query, the original native route
    reaches $A8A2 at Dan2+$0D52 with 139 windows and balanced services.
  - Check caller bytes and measure the selected port, rectangle, pen/colour,
    regions and presentation role on both systems. Implement the reached fill
    contract; preserve D5/D7 suppression of Mac dialogs and menu presentation.

  *Done when* paired complete drawing buffers and port/ABI changes match the
  original, startup reaches its next named stop with MDRV absent, and line,
  effect, offscreen fill, logo/palette/AGA/startup regressions pass.
- **M2.1c Original File Manager read acceptance (after M2.2).**
  - This retains M2.1's original acceptance; diagnostic fixture reads do not count
    as original-game reads. M2.1b2a measured the intervening Get1NamedResource
    dependency at Engine+$3CDC. Implement the file core first, then the queued
    resource services, then return here for their integrated acceptance.
  - The original no-input idle route now proves both PAK reads on the Mac.
    Reproduce actual native execution and compare returned payloads; synthetic
    fixture reads do not satisfy this requirement.

  *Done when* the game opens and reads `ITD_RESS.PAK` and `PRESENT.PAK`, its
  returned bytes match the host files by debugger checksum, and startup window
  counts are recorded. If original bytes establish an unused file, document the
  evidence before revising that requirement; absence from one route is not proof.
- **M1.6b Final startup requirements acceptance (after file/resource services).**
  - M1.6a implements the measured identity records and verifies all eleven
    Engine capability flags. Full startup is still stopped before screen-size selection, before
    Core's initialization-result/alert branches; it is not a successful launch.
  - After M2.1/M2.2, verify Core+$0460 is reached with initialization result zero,
    without taking its failure-alert branches ($0410/$044E).

  *Done when* a bounded original-code observer positively reaches that success
  branch, no "requires" alert occurs, and identity.gdb still matches MAME.
- **M2.3a QuickDraw pattern-copy compiler defect.**
  - The M2.1b2c9b audit found the same GCC 15.1 m68k post-increment/base-register
    copy form in `initGraf`'s five default patterns. Diagnose with a native dump
    before changing it; the metadata fixture already proves the byte-shift defect.
  - Replace affected copies and audit the linked program for that instruction form.

  *Done when* all five native QDGlobals patterns match the source/Mac bytes,
  the instruction audit is clear or every remaining occurrence is explained,
  and startup regressions pass.
- **M2.3b Inverse coordinate conversion.**
  - The inherited GlobalToLocal subtracted Vette's fixed (64,91) origin.
    M2.3g11 replaces that guessed result with a named stop.
  - Measure the reached inverse conversion and use its actual selected port.

  *Done when* the reached GlobalToLocal calls match MAME, with point/adjacent-byte
  checks and no fixed Vette screen origin remaining.
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
  - Lores 320×200×8 in `AitdScreen`, centred for PAL and NTSC. The M2.5a
    prerequisite currently supplies the pinned PAL configuration.
  - A 256-colour copper palette through BPLCON3 banks, plus verified sprite
    palette ownership before enabling the pointer; preserve all game colours.
  - Publication in the VBI. Select the matching PAL/NTSC Paula clock for
    effect pitch and completion timing; M2.3g26 currently uses PAL only.

  *Done when* a test pattern and a 256-colour ramp display correctly (by eye, plus
  a gdb register dump) on `a1200-020` in PAL and NTSC, and the visible pointer
  preserves game colours, and effect period/duration use the selected video
  clock. Other processors remain deferred (D2).
- **M2.6 8-bit C2P with dirty rectangles.**
  - Verify the eight-bit converter against an independent C oracle. Assembly
    optimization and timing work remain deferred to M5 (D2).
  - Rectangles aligned to 32 pixels.

  *Done when* the verifier reports zero mismatches over the intro on
  `a1200-020`, including preservation across partial updates.
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
- **M3.3 Replace Mac dialogs with in-game interfaces (D5).**
  - Owner update 2026-09-29: replace all Mac dialog presentation, including
    new-game and save/load. Do not shrink/reproduce Mac dialogs or controls.
  - Reuse existing engine interfaces where available; otherwise provide an
    in-game interface inside 320×200. Preserve choices, text input, cancellation
    and resulting actions through measured item/service contracts.
  - Retain hidden compatibility state where original callers need it. DLOG 1000
    remains automatic and invisible under D4; no Mac menu bar under D7.

  *Done when* new-game, save-warning, save/load and every reached Mac dialog
  have replacements entirely inside 320×200, choices/results match the reference,
  and frame pairs prove no Mac dialog presentation or menu bar is drawn.
- **M3.4 Apple Events and misc Toolbox.**
  - Pack8 handler installation.
  - Exercise the five integer-only SANE ops implemented at Engine $47C2–$4852
    in the integrated session; unimplemented operations/states remain loud stops.
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
  - Extend the native startup seam from M2.1c3c (`Jnth`; original loader call
    Core+$1CC6, entry store +$1CF4) and the native driver stub. Unimplemented selectors are loud
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
  - Selector 22 now uses the same quiesce/free path as verified natural effect
    completion. Exercise an actual active-effect stop through its interface,
    including music-channel isolation and sample ownership.
  - The S/M keys and the game's toggles work.
  - `SysBeep` becomes a short Paula click.

  *Done when* the `audio` regression passes and effects in the first rooms match
  MAME by event.

- **M4.3a Remaining effect packet/allocation variants.**
  - M2.3g26 enables raw one-shots at integral rates. Loop boundaries/counter
    updates, fractional rates, samples beyond one DMA segment and occupied
    effect/Paula voice selection still have named stops.
  - Bring any reached prerequisite forward. Measure the original driver before
    implementing looping, aging/stealing and interaction with music.

  *Done when* each reached variant has paired original/native playback events,
  exact loop/sample ownership checks and verified stop/replacement cleanup;
  unsupported variants retain named stops.

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
    - dirty-box C2P tuning and a verified assembly kernel (evaluate Kalms'
      `c2p1x1_8_c5_030` against the retained C oracle);
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
  Bind the persistent read-stream API/cache to resload rather than DOS; pass the
  same read/seek/EOF/cache fixture under WHDLoad with zero OS-window entries.
- **M7.3 Packaging and 1.0:**
  - a deterministic LHA;
  - `make release-check`;
  - README requirements from measured numbers;
  - VERSION 1.0.
