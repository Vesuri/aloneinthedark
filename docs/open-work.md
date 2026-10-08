# Open work

This is the work queue. Work it from the top, one item per commit; split an item
only if it has independent parts. Delete an item in the commit that finishes it,
because the Git log records finished work. The design and its rationale are in
[design.md](design.md), cited below by § number; owner decisions D1–D8 are in
design.md §5.

Each item gives the **goal**, then the scope, then *done when*: the evidence
required.

## M6 Completion

- **M6.2 State-keyed fidelity set.** Frame compares for remaining representative mansion rooms,
  fights, death and new-game restart.
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

## After M6: Macintosh.js stair bug

- **MAC.1 Reproduce and fix [macintosh.js issue #103](https://github.com/felixrieseberg/macintosh.js/issues/103).**
  Start after M6 is complete. The report describes the floppy Mac version
  returning to the attic instead of descending after collecting five items,
  on an emulated Quadra 900 / 68040 at 25 MHz with Mac OS 8.1.
  Reproduce in Macintosh.js, compare with the original Mac and Amiga stairs
  evidence from M6.3, identify the cause, and implement a verified fix in the
  responsible component. Record exact versions, settings and reproduction
  steps; do not assume this is the same failure as any Amiga stairs issue.

  *Done when* the reproduced failure has a regression check and the fixed
  build descends successfully; if it cannot be reproduced, record the tested
  configurations and the missing evidence without claiming a fix.

## After M6: AITD 1 glitch audit

- **GLITCH.1 Check the Amiga port against the AITD 1 material in the
  [SDA mechanics and glitches guide](https://kb.speeddemosarchive.com/Alone_in_the_Dark_\(1-3\)/Game_Mechanics_and_Glitches).**
  Start after M6 and the queued Macintosh.js stair investigation. Enumerate
  applicable AITD 1 cases and reproduce them in the port and original Mac,
  with matching game state and recorded CPU/timing settings. The guide mainly
  covers the DOS CD release; verify applicability to our Mac version rather
  than assuming identical behavior. Cover timing and transitions, collisions,
  camera/actor state, inventory and save/load, rendering, sound, crashes and
  softlocks. Distinguish inherited original-game behavior from port regressions.

  *Done when* each applicable case has a result (reproduced, not reproduced,
  or unresolved), reproducible steps and evidence; version-inapplicable cases
  have reasons. File confirmed port defects as actionable open items. Report
  inherited glitches separately without silently changing original game logic.

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
