# Open work

This is the work queue. Work it from the top, one item per commit; split an item only if
it has independent parts. Delete an item in the commit that finishes it, because the Git
log records finished work. The design and its rationale are in [design.md](design.md),
cited below by § number; owner decisions D1–D9 are in design.md §5.

Each item gives the **goal**, then the scope, then *done when*: the evidence required.

## Rendering performance

Baselines are the
[reference-68030 cycle profiles](performance.md#reference-68030-baseline):
`amiga/aprof.sh book 2 50` (66.5 ms per fold step) and `amiga/aprof.sh gameplay 60 100`
(83.0 ms per first-room frame). Each item's commit reports both runs before and after.
Original game instructions stay unchanged; these items reduce port cost only.

- **PERF.4 Speed up native solid fills, lines and back-buffer synchronization.** Measure
  against the current profiles. One book-fold LineTo spends about 500 cycles per pixel
  in `Line8::solid`
  (5.8 ms per step). Six PaintRects take 10.4 ms in `FillRect8::solid`, with
  stack-spilled row state. `presentMacFrame` copies prior dirty spans Chip-to-Chip with
  the CPU (about 5.5 ms of other presentation per step). Keep exact QuickDraw pen, pattern, clip and region
  semantics and explicit dirty rectangles. A blitter copy must complete before
  presentation and respect VBI display ownership.

  *Done when* the book run spends at most 8 ms per step in QuickDraw fills, lines and
  regions (baseline 16.8 ms). Other presentation takes at most 3 ms (current baseline 5.5 ms).
  The `Line8`/`FillRect8` host tests, book page and route observers, `frame_pacing.gdb`
  and the `intro` C2P verification pass.

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
