# Open work

This is the work queue. Work it from the top, one item per commit; split an item
only if it has independent parts. Delete an item in the commit that finishes it,
because the Git log records finished work. The design and its rationale are in
[design.md](design.md), cited below by § number; owner decisions D1–D8 are in
design.md §5.

Each item gives the **goal**, then the scope, then *done when*: the evidence
required.

## After M6: Reported stair bug

- **MAC.1 Investigate the game's return-to-attic stair bug**, using
  [issue #103](https://github.com/felixrieseberg/macintosh.js/issues/103) as
  a symptom report, not evidence that Macintosh.js caused it. The owner
  explicitly excludes running or testing Macintosh.js. Use the existing
  original-Mac emulator and Amiga port to inspect the original stair track,
  animation progression and timing; compare with M6.3's passing descent matrix.
  Test the reported item-collection precondition and timing variants; determine
  whether the original game can return to the attic and whether the port is affected. Fix a confirmed port defect; preserve the owner's approval
  requirement for changes to original game behavior.

  *Done when* the cause and port applicability have supported findings and any
  fix has a regression check; if unreproduced, record the tested conditions and
  remaining uncertainty without claiming that Macintosh.js is at fault.

## After M6: AITD 1 glitch audit

- **GLITCH.1 Check the Amiga port against the AITD 1 material in the
  [SDA mechanics and glitches guide](https://kb.speeddemosarchive.com/Alone_in_the_Dark_\(1-3\)/Game_Mechanics_and_Glitches).**
  Start after M6 and the queued stair investigation. Enumerate
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
