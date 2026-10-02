# Open work

This is the work queue. Work it from the top, one item per commit; split an item
only if it has independent parts. Delete an item in the commit that finishes it,
because the Git log records finished work. The design and its rationale are in
[design.md](design.md), cited below by § number; owner decisions D1–D8 are in
design.md §5.

Each item gives the **goal**, then the scope, then *done when*: the evidence
required.

## Priority: intro performance before M3

- **P1 Comparable-Mac intro performance.**
  - Compare matched intro scenes, steady animation and complete transitions on
    the fixed-clock 68030 Amiga and original Mac IIx at 15.6672 MHz. Record
    remaining machine/timing-model differences and use
    emulated time, not host wall time, for performance claims.
  - Identify and remove dominant algorithmic or compatibility costs. Preserve
    original instructions, game decisions, sample content and timing; do not
    substitute a faster emulator or focus on minor optimizations.
  - Prioritize repeated region decoding and other measured scene-preparation
    costs, then remeasure the whole experience rather than isolated helpers.

  *Done when* matched scene/transition timings demonstrate roughly comparable
  performance to the reference Mac, long unexplained port stalls are resolved,
  and original frame/audio/route checks plus owner-visible playback confirm
  the result.

## Pending verification (owner-deferred)

- **M1.7b2 Rendered-picture acceptance for system windows — pending.**
  - Obtain owner-provided live emulator captures before, during and after the
    1 MB/64 KB system-window probe. Debugger-paused frames and logical
    bitplane dumps do not establish rendered stability.
  - Autonomous host-window capture/input remains restricted. Do not substitute
    host event injection for owner-provided captures.
  - If OS handback changes the display, instrument and fix it.
  *Done when* actual rendered snapshots are stable through the 1 MB/64 KB probe,
  `window-core` and production `boot` pass, and the window entry/exit cost is
  recorded with the full acceptance result. Only then is M1.7b complete.

## M3 Playable

- **M3.1 Events and keyboard.**
  - Extend the existing startup event, key and cursor services through gameplay.
    Verify WaitNextEvent, GetNextEvent, GetKeys, Button, StillDown, FlushEvents,
    SystemClick and ObscureCursor on the first-room paths; implement any
    remaining measured contracts.
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
  - Complete and verify Apple Event delivery at user-mode safe points.
  - Exercise the five integer-only SANE ops implemented at Engine $47C2–$4852
    in the integrated session; unimplemented operations/states remain loud stops.
  - The remaining Window Manager calls.

  *Done when* no loud stop occurs in a 10-minute manual session covering the first
  floor.
- **M3.5 `newgame` and `saveload` regressions.**
  - Scripted key input in the Amiga runner.
  - PASS records keyed on game state: the room, and actor positions read from the
    A5 world.

  *Done when* both cases pass on `a1200-020`.
- **M3.6 Durable writes.**
  - Verify actual game save and reload, including reset immediately after
    reported save success.

  *Done when* a save survives an emulator reset made immediately after the game
  reports it saved.

## M4 Audio

- **M4.1 Remaining driver-interface coverage.**
  - Complete the gameplay selector inventory and implement each reached
    contract against the original driver.
    Unimplemented selectors remain loud stops; original MDRV never runs.

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
  - Verify active-effect stop through selector 22, including music-channel
    isolation and sample ownership.
  - The S/M keys and the game's toggles work.
  - `SysBeep` becomes a short Paula click.

  *Done when* the `audio` regression passes and effects in the first rooms match
  MAME by event.

- **M4.3a Remaining effect packet/allocation variants.**
  - Measure and implement loop boundaries/counter updates, fractional rates,
    samples beyond one DMA segment and occupied effect/Paula voice selection.
    A free second effect slot must also reproduce D1.W from the preceding active
    slot; resolve the `EFFECT SECOND SLOT` loud stop against the original.
  - Bring any reached prerequisite forward. Measure the original driver before
    implementing looping, aging/stealing and interaction with music.

  *Done when* each reached variant has paired original/native playback events,
  exact loop/sample ownership checks and verified stop/replacement cleanup;
  unsupported variants retain named stops.

- **M4.3b Investigate reported grainy music playback.**
  - The owner hears persistent grain/buffering-like breakup during diagnostic
    playback. Current runs use warp and debugger pauses; the emulator log
    confirms warp/no full synchronization but reports no audio underrun.
  - Compare an uninterrupted, non-warp run with the diagnostic run. Inspect
    emulator audio timing and native Paula sample/loop/note timing before
    attributing the symptom to host speed or normal 8-bit quantization.

  *Done when* a repeatable listening/capture test establishes the cause,
  any playback defect is fixed with regression evidence, and remaining
  sample-fidelity limitations are explained. Do not infer audio quality from
  successful note-event tests alone.

## M5 Performance

- **M5.0 Deferred CPU compatibility configurations.**
  - Finish broader regression acceptance of the selected fixed-clock 68030
    configuration; keep 68040/68060 deferred until after functional milestones.
    Add explicit configurations and verify ROM compatibility, actual CPU and
    OS-visible RAM before using them for later profiling/stairs checks.

  *Done when* each added configuration reports its intended CPU and available
  memory, and passes all regression cases implemented so far in bounded runs.
- **M5.1 Full-accounting profile.**
  - Separate steady 3D rendering from complete scene-transition preparation.
    Attribute the reported long intro pauses across file/cache reads, original
    decompression, region construction, drawing and compatibility services;
    correlate emulated timing with the owner recording. Do not infer a steady
    FPS from a sample containing loading, or sum nested profile categories.
  - A PROBES build and a gameplay scene on `a1200-020`, run twice. Add a
    68030 comparison only after M5.0 validates its configuration.
  - Report ms/frame by phase: game code, drawing traps, CopyBits, C2P, palette,
    audio sequencer, system windows.

  *Done when* the table is in amiga-arch.md.
- **M5.2 Optimise by the profile.**
  - One measured optimisation per commit, with before and after numbers. Record
    rejected attempts in their commit message.
  - Candidates:
    - further dirty-box C2P tuning, using the integrated Kalms
      `c2p1x1_8_c5_gen` and retained host oracle as the baseline;
    - FMODE;
    - a fast srcCopy;
    - a fast path for the SetGWorld/GetGWorld traps (138 sites);
    - a TickCount fast path.

  *Done when* the profile shows no remaining optimisation worth its risk, and the
  frame rates on both configs are recorded in README.
- **M5.2a Region expansion cost.**
  - After streaming masked copies, four InsetRgn calls use 14,256,985 of
    24,022,099 beam units in a bounded diagnostic sample. RegionExpand decodes
    the complete region three times per output row.
  - Consider validated forward traversal of neighbouring rows, preserving exact
    encoding and atomic malformed/capacity rejection. Inspect combined native
    stack usage and interrupt headroom; no large new automatic arrays.

  *Done when* independent host shapes and original/native InsetRgn bytes, ABI
  and ownership pass, measured native cost decreases, interrupt headroom is
  verified, and the unprofiled idle route still completes without manual Enter.

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

- **M6.1 Full manual play-through,** in MAME and on `a1200-020`, with the runtime
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
