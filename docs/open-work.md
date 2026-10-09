# Open work

This is the work queue. Work it from the top, one item per commit; split an item only if
it has independent parts. Delete an item in the commit that finishes it, because the Git
log records finished work. The design and its rationale are in [design.md](design.md),
cited below by § number; owner decisions D1–D8 are in design.md §5.

Each item gives the **goal**, then the scope, then *done when*: the evidence required.

## Saving and input after disk switches

- **INPUT.2 Verify post-save keyboard recovery under WHDLoad.** The owner
  reports stuck dialog input after entering a save name, despite the Escape
  fix. Check lost physical key releases during host OS switches and stale
  filename events. The return callback must preserve kickemu restoration and
  the resload ABI; cached calls must leave input untouched.

  *Done when* saving through the installed icon returns responsive controls,
  including Enter and Escape, with native and WHDLoad regressions and owner
  verification of the reported physical-key case.

- **SAVE.1 Reduce save-related OS switches.** Measure the reported roughly
  seven switches, separate file/metadata operations from WHDLoad cache policy,
  and batch redundant work where safe. Preserve save/load correctness and
  error reporting; target one or two switches without deferring durability
  silently.

  *Done when* before/after switch counts and full save/load checks support the
  change, or document the remaining WHDLoad constraint.

## AITD 1 glitch audit

- **GLITCH.1 Check the Amiga port against the AITD 1 material in the
  [SDA mechanics and glitches guide](https://kb.speeddemosarchive.com/Alone_in_the_Dark_\(1-3\)/Game_Mechanics_and_Glitches).**
  Start after the preceding fixes. Enumerate
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
