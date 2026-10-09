# Open work

This is the work queue. Work it from the top, one item per commit; split an item only if
it has independent parts. Delete an item in the commit that finishes it, because the Git
log records finished work. The design and its rationale are in [design.md](design.md),
cited below by § number; owner decisions D1–D8 are in design.md §5.

Each item gives the **goal**, then the scope, then *done when*: the evidence required.

## Reported stair bug

- **MAC.1 Investigate the game's return-to-attic stair bug**, using
  [issue #103](https://github.com/felixrieseberg/macintosh.js/issues/103) as
  a symptom report, not evidence that Macintosh.js caused it. The owner
  explicitly excludes running or testing Macintosh.js. Use the existing
  original-Mac emulator and Amiga port to inspect the original stair track,
  animation progression and timing; compare with M6.3's passing descent matrix.
  See [initial original-code findings](mac-stairs.md).
  The owner also reports immediate automatic return upstairs on unlimited
  68040-NOMMU with JIT, without collecting any attic items. Reproduce this
  configuration and compare the same route with JIT disabled.
  Test the reported item-collection precondition and timing variants; determine
  whether the original game can return to the attic and whether the port is affected. Fix a confirmed port defect; preserve the owner's approval
  requirement for changes to original game behavior.

  *Done when* the cause and port applicability have supported findings and any   fix has
a regression check; if unreproduced, record the tested conditions and   remaining
uncertainty without claiming that Macintosh.js is at fault.

## AITD 1 glitch audit

- **GLITCH.1 Check the Amiga port against the AITD 1 material in the
  [SDA mechanics and glitches guide](https://kb.speeddemosarchive.com/Alone_in_the_Dark_\(1-3\)/Game_Mechanics_and_Glitches).**
  Start after the queued stair investigation. Enumerate
  applicable AITD 1 cases and reproduce them in the port and original Mac,
  with matching game state and recorded CPU/timing settings. The guide mainly
  covers the DOS CD release; verify applicability to our Mac version rather
  than assuming identical behavior. Cover timing and transitions, collisions,
  camera/actor state, inventory and save/load, rendering, sound, crashes and
  softlocks. Distinguish inherited original-game behavior from port regressions.

  *Done when* each applicable case has a result (reproduced, not reproduced,   or
unresolved), reproducible steps and evidence; version-inapplicable cases   have reasons.
File confirmed port defects as actionable open items. Report   inherited glitches
separately without silently changing original game logic.

## Startup observer maintenance

- **TEST.1 Update the combined startup observer for fast trap dispatch.**
  `driver_startup.gdb` / `menu_lifecycle.gdb` reaches the font and native driver
  checks but fails with `FAIL original RGB caller` in `rgb_colors_calls.gdb`.
  Reproduced on the pre-embedding revision `f6a4c56` with `PROBES=1` on
  `a4000-030`; the RGB observer watches general dispatch while RGB traps can
  take the fast path. Audit the subsequent caller/endpoint assumptions too.

  *Done when* the combined observer reaches its positive completion on the
  current runtime, with original-byte and register checks preserved.
