# Open work

This is the work queue. Work it from the top, one item per commit; split an item
only if it has independent parts. Delete an item in the commit that finishes it,
because the Git log records finished work. The design and its rationale are in
[design.md](design.md), cited below by § number; owner decisions D1–D8 are in
design.md §5.

**M2 completed 2026-10-02.** Startup, intro, original demo, music and PAL/NTSC
rendered display acceptance pass. Evidence is in [development.md](development.md).
M3 is the next implementation milestone; the separately deferred M1.7b2 window
fixture acceptance remains listed below.

**Current state:**
- Original CODE 1 loads, expands the exact A5 world, relocates Core and enters
  startup on the 68020 without an FPU. Resources and hidden compatibility state
  support the measured initialization path; original MDRV code is never loaded.
- The uninterrupted intro passes on the baseline 68020: all 956 frames, including
  944 partial updates and all 840 book batches, pass C2P verification. Four
  instruction-matched intro frames pass paired pixel/palette/AGA checks; both
  logos are exact and title/credits have only verified owned-font differences.
  The pointer-enabled rerun passes the same complete coverage and comparisons.
  M2.10 also passes the car/frog frame checks: matched actual model/transform
  inputs produce exact 64,000-pixel Mac images, all 256 colours and native AGA
  publications. The car comparison exposed and fixed descending LineTo ties;
  all 80 original slope fixtures and 47 measured car calls pass. The final
  uninterrupted-intro rerun after the display synchronization change also
  passes all 956 frames and four paired captures. The full host suite and all
  six native regression cases now pass on `a1200-020`, including all eight
  resource-exit phases (`m2-final-native-regression-isolated.log`, exit 0).
  Rendered-window acceptance remains separate.
- M2.1c now passes actual native reads of both PAKs: 1,536 bytes from
  ITD_Ress and 17,920 bytes from Present match the installed files exactly.
  The intervening palette reactivation matches the Mac. The baseline
  `a1200-020` ordinary-randomness run now completes all nine room/camera
  transitions and exits naturally without demo input, with 1,500 windows,
  111 resource reads and 70,729 balanced services
  (`m2-sync-ordinary-native-full.log`, exit 0). Both payload and palette
  checkers pass. The subsequent six-minute black interval was traced to repeated
  sample conversion and free-memory copying. Both are fixed; the owner video
  confirms a 7.95-second transition and completion of the visible demo.
- The title-screen copy now matches the Mac with documented placeholder text
  differences. The credits now use the measured 16-pixel line spacing and owned dot-above
  artwork, including â in the original “Yaâl” credit. Game-window lines and
  their AGA publication pass. The intro returns successfully;
  the post-intro offscreen copy also matches. GetKeys now passes its original-call and native
  held/released-key checks. Selector 13 now passes its control-word/ABI checks;
  selector 0 now retains and arms song $87 with verified native playback.
  The clock query now passes its original ABI and 32-bit condition-code checks.
  Song-status selector 4 now passes its original ABI and flags; the direct-map
  CopyBits at Dark+$1E4A now returns with matching pixels. RectRgn and the reached canonical-empty
  EmptyRgn now pass exact region/ABI checks.
  Intro LineTo and mode-0 fills match the Mac; the first raw effect plays on Paula and its
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
  The active implementation queue resumes at M3 below.
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
  - Pack8 registration/lookup already pass; complete and verify event delivery
    at user-mode safe points.
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
  - Existing file/resource writes, pending-write tracking and preference exit
    persistence pass native fixtures. Verify them through the actual game save
    and reload path, including reset immediately after reported save success.

  *Done when* a save survives an emulator reset made immediately after the game
  reports it saved.

## M4 Audio

- **M4.1 Remaining driver-interface coverage.**
  - The intro-driver prerequisite and its no-loud-stop exit criterion pass with
    M2. Preserve the broader selector inventory: decode every selector used by
    gameplay and implement each reached contract against the original driver.
    Unimplemented selectors remain loud stops; original MDRV never runs.
  - Full-game selector coverage is not established by the intro song fixture.

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
    A free second effect slot must also reproduce D1.W from the preceding active
    slot; the old guessed $7FFF result is now `EFFECT SECOND SLOT`.
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
  - Revisit 68030/68040/68060 only after the functional milestones on 68020.
    Add explicit configurations and verify ROM compatibility, actual CPU and
    OS-visible RAM before using them for later profiling/stairs checks.
  - The exploratory 68040 run failed before the loader, with Z3 fast RAM not
    configured by the selected ROM; it is not a supported configuration.

  *Done when* each added configuration reports its intended CPU and available
  memory, and passes all regression cases implemented so far in bounded runs.
- **M5.1 Full-accounting profile.**
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
    the complete region three times per output row. The unprofiled idle demo
    now completes, so further optimization belongs here rather than blocking M2.
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
