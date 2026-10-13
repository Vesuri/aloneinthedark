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

## VBL service contracts

- **VBL.1 Verify dormant countdowns and callback auto-removal.**
  `scheduleVBLTask` decrements only positive counts and dispatches zero/negative
  counts; `aitdVBLCallbackComplete` leaves a callback's zero-count task queued.
  Prince of Persia 2's System 7.5.5 fixture instead observes modulo-16-bit
  countdowns, dispatch only on reaching zero, and removal when a callback
  returns without rearming. Reproduce these cases on this game's Macintosh
  reference before changing the service; the shared `VBLPasses` helper only
  owns queue-pass bookkeeping, not these task semantics.

  *Done when* paired original/native fixtures cover initial counts 1, 2, 0 and
  -1, rearming, automatic removal, subsequent `VRemove` results and queued
  passes; confirmed deviations are corrected through the shared workflow,
  callback ABI checks pass, and existing gameplay/VBL latency gates pass.

## Profiling validity

- **PERF.1 Keep debugger stops outside the measured profile window.**
  `amiga/aprof.gdb` installs a conditional `AitdScreen::queueFrame` breakpoint
  after `monitor aprof start` and waits for a completed-step threshold. Verify
  whether the remote stub evaluates that condition or GDB stops the guest at
  intermediate frames. AmigaXDev's measurement method forbids debugger stops
  inside the window because they can bias timing. Use a one-shot in-target
  completion marker if intermediate stops occur; preserve normal game work.

  *Done when* the measurement has only start/end stops, the interval has positive
  completion and matching game state, and an A/B check establishes the effect
  on existing profiles before any affected performance conclusions are reused.

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
