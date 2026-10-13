# Open work

This is the work queue. Work it from the top, one item per commit; split an item only if
it has independent parts. Delete an item in the commit that finishes it, because the Git
log records finished work. The design and its rationale are in [design.md](design.md),
cited below by § number; owner decisions D1–D9 are in design.md §5.

Each item gives the **goal**, then the scope, then *done when*: the evidence required.

## Runtime overhead

- **HEAP.1 Avoid heap-wide work for unchanged allocation sizes.**
  `MacHeap::resizeInPlace` calls `split` and `coalesce` even when the requested
  logical size already matches the allocation. The latter walks the entire
  zone. Inspect the reached `SetHandleSize`/`SetPtrSize` and internal region
  callers; measure their frequency and cost before changing the allocator.
  Reuse and consolidate the fix with Prince of Persia 2 through AmigaXDev.

  *Done when* unchanged-size requests preserve errors, handle state, addresses,
  payloads and heap invariants without a whole-zone walk; grow/shrink and
  fragmented-heap regressions pass, and matched native workloads on pinned
  CPU configurations establish the effect without changing original game state.

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
