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
  all 80 original slope fixtures and 47 measured car calls pass. Natural
  sequence completion and rendered-window acceptance remain separate gaps.
- M2.1c now passes actual native reads of both PAKs: 1,536 bytes from
  ITD_Ress and 17,920 bytes from Present match the installed files exactly.
  The intervening palette reactivation matches the Mac; the completed
  deterministic a4000-030 run records 1,490 windows, 111 resource reads and
  42,132 balanced services (`m2-pak-pointer-native-full.log`, exit 0).
  Both payload and palette checkers pass. This does not close the separate
  unseeded route or rendered-picture gaps.
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
- [ ] **M2.3g44 sequence** — finish the baseline run with ordinary randomness,
  verifying natural demo exit without input, both PAK reads and palette
  reactivation through all nine reference room/camera transitions. Ordinary
  baseline runs stall in room 2; the latest copy-span trial also failed its
  256-frame movement guard. Resolve that stall; natural exit remains unverified.
- [ ] **M2.3g44 visual report** — demonstrate the black-interval cause and verify
  the rendered result when authorized capture is available. M2 remains open
  while its required acceptance is outstanding.

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

### M2.3g44 — unresolved visual report and sequence acceptance

The reported black interval is **not diagnosed or fixed**. Existing memory and
register checks cannot establish what the host window displayed. Follow the
host-window restriction under M1.7b2; do not retry denied capture or substitute
host input injection. This verification gap must not stall independent M2 work.

Already verified (details and capture names in [development.md](development.md)):
- Streaming masked copies let the fixed-entropy idle demo exit naturally without
  manual input through all nine Mac room/camera transitions. Actor identity,
  room, life and track agree; the final entrance position is 105 versus 109,
  followed by native completion at 122. Car/frog frame fidelity now passes
  with matched actual draw inputs; ordinary-randomness progression is separate.
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

Remaining: resolve the ordinary-randomness room-2 movement stall and verify
natural sequence completion; capture the reported black state across logical
pixels, palette, AGA publication and authorized rendered output. FS-UAE's
`Not a valid drawable size for glViewport` remains a clue, not a diagnosis.
An unseeded native PAK acceptance run also timed out before its cleanup
checkpoint after 25 minutes, with the interrupted PC in frame presentation.
It did not capture scene state; neither its sequence position nor the cause of
that missed checkpoint is established by this result.
A replacement baseline `a1200-020` run used ordinary randomness
and an observer installed before the first PAK read
(`m2-pak-ordinary-early-native.log`, exit 124). It read ITD_Ress and recorded five
room transitions, through room 2/camera 4 at frame 734, but reached the
2,400-second limit without another transition; the final tick count was 184,708.
Natural exit, the Present read and palette reactivation remain unverified.
The follow-up baseline diagnostic completes 257 observed frames in that room
(`m2-room2-ordinary-native-full.log`, exit 0). With choice 1, actor 288/body 265
remains on track 26 at word offset 59 while its x position varies around 2,550
and z remains 1,085. Original Dark2+$49F0/+4A08 identify the track resource and
word offset at actor +$54/+$58. The ordinary Mac run with the same choice
advances to room 7 in 129 frames (`m2-room2-ordinary-reference.log`, exit 0).
This establishes a native movement stall; its cause is still under investigation.
The follow-up longword copy-span trial also fails on baseline `a1200-020`
with ordinary randomness (`m2-copyspan-ordinary-native-full.log`, exit 1).
It reaches room 2/camera 4 at frame 587, then actor 288 stays on track 26,
word 59 for 256 observed frames; its later position is 2,460/0/1,099.
The observer deliberately stops on this guard, rather than waiting for a
timeout. This trial does not resolve the sequence failure or establish a
speedup. Keep further general copy tuning in M5; the next acceptance work is
to explain and correct the native movement divergence from the original Mac.
Replaying the stalled native position into the original Mac confirms distance
1,109 and steering 0 for the target 2,450/0
(`m2-room2-stall-replay-reference.log`, exit 0). With matching numeric actor
bounds and world coordinates, the original also remains at 2,460/0/1,099,
track word 59 for 257 frames while its animation advances
(`m2-room2-stall-recovery-reference.log`, exit 0). These diagnostic data
fixtures preserve original instructions and timers. They locate the next
investigation earlier in the approach to the waypoint: the stalled state's
turn calculation itself agrees with the Mac. They do not prove the cause of
entering that state or complete sequence acceptance.
Routine service tests use `INTROSKIP=1`; uninterrupted playback is reserved for
sequence acceptance. `FIXEDRNG=1` needs the matching Mac entropy fixture;
elapsed ticks alone do not establish paired scene state.

*Done when* the black-interval cause is demonstrated, the car reaches its
near-camera endpoint and advances to the frog without repeated circling or
manual input, and fixes pass original sequence and paired frame/publication
checks. Rendered verification remains explicitly pending while authorized
capture is unavailable.

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
