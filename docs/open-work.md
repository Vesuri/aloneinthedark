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
  checkers pass. Rendered-picture acceptance remains pending.
  A later normal visible PAL run (2026-10-02) produced a roughly six-minute
  black interval and an owner report of renewed car circling; repeatability
  is reopened below. The earlier successful diagnostic run is not a fix proof.
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
  The active implementation queue resumes at M2 below.
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

Delivery update (owner, 2026-10-02): finish M2 without blocking on
micro-optimizations. Work the actionable items below in order. Preserve the
unresolved visual report as an explicit acceptance gap; it does not block
independent service implementation or automated acceptance. Region expansion
and other general tuning remain M5.

- [ ] **M2.5** — PAL/NTSC automated display and native audio-clock checks pass;
  original-game pointer is enabled with verified inversion. Rendered-picture
  acceptance remains owner-deferred.
- [ ] **M2.3g44 visual report** — demonstrate the black-interval cause and verify
  the rendered result when authorized capture is available. M2 remains open
  while its required acceptance is outstanding.
- [ ] **M2.3g44 demo reliability** — investigate the owner's renewed car-circling
  report in the normal PAL run. Reproduce with measured actor/track state and
  verify natural completion on the normal uninterrupted route; retain original
  game instructions. One successful diagnostic route does not close this report.

- **M2.5 AGA 8-plane display.**
  - Lores 320×200×8 in `AitdScreen`, centred for PAL and NTSC. Video selection
    now passes the five-frame native display fixture on
    `a1200-020` in both standards, including all planes, colours, partial
    updates, mode registers and OS restoration (`m2-video-pal-native-full.log`,
    `m2-video-ntsc-native-full.log`, both exit 0). PAL advances 83 game ticks
    over 69 fields; NTSC advances 90 ticks over 90 fields. Both mode checkers
    pass. These are automated checks, not by-eye acceptance.
  - A 256-colour copper palette through BPLCON3 banks, plus verified sprite
    palette ownership before enabling the pointer; preserve all game colours.
    The two-sprite helper now preserves all 256 game RGBs with playfield XOR 1
    and the matching palette permutation, using sprite 0 for white and sprite 7
    for black. Original startup reaches CURS 132's two inversion pixels; the
    measured Mac operation XORs each indexed pixel with 255 and restores it on
    hiding without changing the palette. Native inversion retains only its
    applied mask, removes it from copied spans, and preserves clean C2P buffers.
    Baseline PAL/NTSC fixtures pass exact pixels/colours, motion without a new
    frame, clipping, hiding, disabling, cleanup and clean partial conversion
    (`m2-cursor-motion-pal-full.log` and `m2-cursor-motion-ntsc-full.log`, exit 0).
    No publications are late; cursor work ends by line 17 in both standards.
    Original-game startup now passes frame 9 with the pointer enabled and all
    pixels/colours exact (`m2-pointer-game-startup-full.log`, exit 0).
    Rendered acceptance remains pending; see [cursor.md](cursor.md).
  - Publication in the VBI. Select the matching PAL/NTSC Paula clock for
    effect pitch and completion timing.
    Mode-dependent display placement, 60 Hz game ticks and effect/song clocks
    are implemented. Sanitizer-backed host checks pass for both standards.
    Native original-effect captures also pass in both standards: selected
    Paula programming period, paired PCM, exact duration, natural completion
    and DMA/sample cleanup (`m2-video-effect-pal-native-full.log` and
    `m2-video-effect-ntsc-native-full.log`, both exit 0). The earlier failed
    guard read write-only AUD0PER; the maintained observer checks the actual
    Paula programming call instead. By-eye acceptance remains open.

  *Done when* a test pattern and a 256-colour ramp display correctly (by eye, plus
  a gdb register dump) on `a1200-020` in PAL and NTSC, and the visible pointer
  preserves game colours, and effect period/duration use the selected video
  clock. Other processors remain deferred (D2).

### M2.3g44 — unresolved visual report

The reported black interval is **not diagnosed or fixed**. Existing memory and
register checks cannot establish what the host window displayed. Follow the
host-window restriction under M1.7b2; do not retry denied capture or substitute
host input injection. This verification gap must not stall independent M2 work.

Owner-provided F12+S captures from a normal, unpaused `a1200-020` PAL run on
2026-10-02 are now available in `tmp/m2-owner-screenshots-pal/` (40 PNGs).
Amsterdam timestamps show the menu at 20:45:10, 14 identical all-black captures
from 20:45:25 through 20:51:01, and landscape at 20:51:44. They support the
owner's roughly six-minute black interval, but do not identify its cause.
The owner reports a moving mouse pointer during black output; the saved black
images contain no pointer, so that observation is not independently captured.
Later images show car movement and scene progression through 20:54:09; they
do not alone prove the reported circling or natural completion. The run was
stopped at the owner's request. No Enter was requested: the letter belongs to
the new-game route and is not expected in this idle demo. User-saved screenshot
inspection is authorized; autonomous host capture/input remains restricted.

A subsequent bounded baseline diagnostic (`tmp/m2-black-timeline-native-full.log`,
exit 0; `INTROSKIP=1`, ordinary randomness) reproduces a 21,678-tick gap
between frame submissions: tick 3,296 to 24,974, about 361 seconds. The first
frame's entire viewport is index 255 with RGB (0,0,0). Song/instrument/sample
resource requests occupy ticks 3,444–5,850; no further frame is submitted until
24,974. This establishes a long application-side blank-frame gap as a concrete
lead, but does not yet locate the work/wait after the last sample request or
prove why the normal run stayed black. Next measure the original continuation
and native service activity across that gap, then verify the correction against
the original Mac and owner-rendered output.

Follow-up activity and cost captures identify native music catch-up as the main
delay (`m2-black-activity-native-full.log`, `m2-black-cost-native-full.log`, both
exit 0). Only a handful of original calls progress while song catch-up consumes
17,181 ticks; repeated PCM conversion accounts for 16,697 ticks (278 seconds).
The in-progress sample-reuse change reduces the same blank-frame submission
gap from 21,663 to 2,976 ticks (361 to 49.6 seconds), with 65 conversion ticks
before the next picture (`m2-black-reuse-native-full.log`, exit 0). The host
original-event comparison and full native playback now pass, including all
3,736 timed events, 25 byte-exact retained PCM variants (458,974 bytes), effect
priority, natural completion and cleanup (`m2-song-reuse-native-full.log`,
exit 0). Normal route reliability and owner-rendered confirmation remain required;
the residual loading interval is not yet accepted.

Already verified (details and capture names in [development.md](development.md)):
- The baseline ordinary-randomness demo completes all nine original
  room/camera transitions and exits naturally at tick 60,426 with choice 0.
  Both original PAK payloads and palette reactivation pass. The earlier room-2
  stall is absent in that particular run after eliminating back-buffer copies
  of spans immediately overwritten by C2P; the later visible-run report reopens
  reliability. Original movement instructions and timers are unchanged.
  Car/frog frame fidelity passes with matched actual draw inputs.
- The idle menu has all 64,000 pixels, plane pointers and 256 colours verified.
  Read-only mode checks pass after 135 OS handbacks and at its original 900-tick
  exit. Persistent mode loss at those checkpoints is ruled out; transient
  handback behavior and host rendering remain unverified.
- Normal Enter input selects new game and the portrait; all eight letter pages
  pass strings, layout, artwork, palettes and AGA decoding, with only the owned
  placeholder glyph artwork differing. The Mac idle route waits about 15 seconds
  at the menu before the car/pond demo; it does not automatically show the letter.
- Owner screenshots establish visible logo, title, menu, portraits and letter
  after manual Enter, and eventual visible landscape/car/pond progression. They
  do not establish the cause of the preceding black interval. The DOS video is
  content context only, never the Macintosh pixel/font reference.

Remaining: capture the reported black state across logical pixels, palette,
AGA publication and authorized rendered output. FS-UAE's
`Not a valid drawable size for glViewport` remains a clue, not a diagnosis.
The completed sequence checks do not establish what the host window displayed.
See [development.md](development.md) for the baseline sequence evidence and
[cursor.md](cursor.md) for display synchronization checks.

*Done when* the black-interval cause is demonstrated and the rendered result
is verified. This remains pending while authorized capture is unavailable.

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
  - A PROBES build and a gameplay scene, on `a1200-020` and `a1200-030`, run
    twice.
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
