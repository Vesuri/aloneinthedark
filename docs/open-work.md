# Open work

This is the work queue. Work it from the top, one item per commit; split an item
only if it has independent parts. Delete an item in the commit that finishes it,
because the Git log records finished work. The design and its rationale are in
[design.md](design.md), cited below by § number; owner decisions D1–D8 are in
design.md §5.

Each item gives the **goal**, then the scope, then *done when*: the evidence
required.

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

- **M3.4 Apple Events and misc Toolbox.**
  - Exercise the remaining first-floor paths, measuring and
    implementing newly reached Apple Event or Window Manager contracts.
    Unsupported operations and states remain loud stops.
  - If a new Mac dialog is reached, measure its choices/results and provide an
    engine-style interface inside 320×200 under D5; unsupported paths stay loud.

  - Verify the continuous first-floor circuit from a new game on both
    acceptance CPUs, including the remaining combat-recovery paths below.
    Pair each native extension with the original Mac's actual routes.
  - Verify the post-combat room 5 Search and hallway return on both acceptance
    CPUs, requiring actual action state before continuing movement and zero
    dropped synthetic transitions. Verify ordinary-input recovery from the
    living room 4 transition caused by enemy knockback on the 68020; use
    measured connecting-door behavior rather than assuming every combat stays
    in room 5. Verify ordinary walking recovery when combat knockback leaves
    the hero beyond kick range, including completed enemy death/removal.
    Integrate the measured bedroom encounter into the connected return route.
    Verify the bathroom continuation on the acceptance CPUs, then expand a
    continuous circuit through connected first-floor rooms with positive
    movement and destination checks. Measure steering changes against the
    original controls.
  - Bound steps by living hero identity; a death followed by the attract demo
    must terminate the observer rather than be counted as gameplay.

  *Done when* a paired session includes at least ten minutes of active
  first-floor gameplay without a loud stop, with positive state checks and Mac
  evidence for the covered routes. Owner play-testing can supplement acceptance.
## M4 Audio

- **M4.1 Remaining driver-interface coverage.**
  - Complete ordinary-game reachability for the [direct-call inventory](sound-driver.md#remaining-direct-call-inventory--2026-10-07),
    especially selectors 1, 2, 6, 9–12, 14, 16, 23 and 25; implement each reached
    contract against the original driver.
    Unimplemented selectors remain loud stops; original MDRV never runs.

- **M4.2 Audible all-song acceptance.**
  - Verify recognizable audio-enabled playback for all eight songs on the
    fixed 68030 setup. Complete original/native event, timing and allocation
    acceptance is recorded in [music coverage](music-resource-coverage.md).
    Keep listening evidence distinct from the completed headless fixtures.

  *Done when* all eight songs play recognizably within the documented
  four-channel voice-stealing policy.
- **M4.3 Sound effects and toggles.**
  - Effects through the driver's selectors take priority on the channels.

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

## M6 Completion

- **M6.1 Full manual play-through,** in MAME and on `a1200-020`, with the runtime
  trap log. Implement every new trap and path it finds.

  *Done when* the game can be finished on the Amiga with no loud stop.
- **M6.2 State-keyed fidelity set.** Frame compares for representative rooms,
  inventory, book/reading views, fights, death, new-game restart and the ending.
  Pair idle animation frame and interpolation phase before exact restart pixels.

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
- **M6.5 Remaining visible Mac font faces (D6).** Capture and bundle raw
  original bitmaps for reached visible families/sizes beyond Times/plain/14,
  including pause. Preserve glyph bearings, styles and measured text layout.

  *Done when* every reached visible Mac-font draw uses the original bitmap
  artwork and state-matched text captures agree with MAME.

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
