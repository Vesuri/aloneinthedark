# Open work

This is the work queue. Work it from the top, one item per commit; split an item only if
it has independent parts. Delete an item in the commit that finishes it, because the Git
log records finished work. The design and its rationale are in [design.md](design.md),
cited below by § number; owner decisions D1–D9 are in design.md §5.

Each item gives the **goal**, then the scope, then *done when*: the evidence required.

## Monster sequence performance

Use the maintained [monster-to-death profile](performance.md#monster-to-death-cycle)
for each item's effect. The current reference-68030 baseline and per-phase costs
are in that document; preserve matching game state when comparing changes.

- **PERF.3 Record the owner's 68040 baseline — deferred by the owner.**
  Real-Amiga benchmarks are deferred. When resumed, use the
  [debugger-free monster audit](performance.md#debugger-free-hardware-audit)
  on the 68040/40 under WHDLoad and plain AmigaOS with SetPatch. Preserve each
  binary report and record memory, video, storage, library and WHDLoad settings.
  For plain AmigaOS, record the SetPatch/CPU-library versions and full CACR before
  gameplay and after cleanup; both 040 cache-enable bits (`$80008000`) must be set.
  Investigate any cache-policy change. The executable must retain OS cache ownership.

  *Done when* both hardware results are recorded and later items quote their 68040
  effect against them. Emulator smoke tests do not satisfy this hardware gate.

- **IO.1 Reduce remaining song-resource I/O latency.**
  Profile the plain-AmigaOS resource reads separately from preparation CPU work
  and compare the unchanged WHDLoad/resload path. Use the pinned reference-68030
  MONSTER route and the current song-start figures in [performance](performance.md#song-start-preparation).
  Preserve on-demand resource loading, bounded reads, error reporting and ownership;
  do not preload other songs or trade the wait for unbounded memory use.

  *Done when* the remaining read/seek and scheduler-wait costs are attributed,
  a bounded I/O improvement is measured and retained or rejected on that evidence,
  and full transition intervals are reported separately. Retained changes must
  pass resource-byte, playback, low-memory and normal-cleanup checks. Set any
  latency target from those measurements; real-Amiga benchmarks remain deferred.

- **CACHE.1 Verify WHDLoad copyback caches on hardware — deferred by the owner.**
  Run the [cache validation](testing.md#whdload-cache-validation) on the owner's
  68040 with both caches enabled. Record the effect against PERF.3 and inspect a
  complete monster-to-death sequence for display/audio corruption.

  *Done when* the hardware performance comparison and complete visual/audio run
  are recorded. Corrected FS-UAE functional checks do not satisfy this hardware gate.

## Runtime overhead

- **HEAP.1 Adopt shared heap helpers in Prince of Persia 2 — deferred by the owner.**
  Prince of Persia 2 work is ongoing elsewhere. When the owner resumes adoption,
  use AmigaXDev's shared MoveHHi and in-place resize implementations instead of
  forking allocator fixes. Preserve that port's placement, errors, handle state,
  payloads and memory publication contracts.

  *Done when* the deferred consumer uses the canonical helpers and passes its
  original/native placement, unchanged-size, grow/shrink, failure and fragmented
  heap fixtures, with matched native workloads establishing the effect.

## Profiling validity

- **MEASURE.3 Verify debugger-injected negative controls reach the CPU.**
  A compiled wrong-tick injection trips the service-cache oracle immediately;
  debugger writes to a pending-pass field and to the compared tick register
  did not trip it after resuming. The cause is unverified. Do not interpret
  debugger readback alone as proof that the CPU consumed an injected fault.

  *Done when* a minimal fixture checks memory and register writes across resume
  on the selected FS-UAE builds, with an in-target observation and a compiled
  negative control. Correct the fixture or emulator as indicated and identify
  any existing regression claims affected by the result.

- **TEST.5 Make monster-profile startup preferences reproducible.**
  A fresh private run directory can fail the initial monster-state check while
  a repeat with the generated preferences passes. Determine which initial
  fields differ and isolate the measured preference fixture before launch;
  do not silently inherit or overwrite owner preferences.

  *Done when* fresh and existing run directories both reach the specified
  initial state with byte-identical prepared preferences, a clean repeat passes
  the profile's state/field checks, and original preferences are restored on
  success and failure. Preserve the explicit initial-state diagnostic.

- **TEST.6 Verify the standalone fight-song observer's setup.**
  `gameplay_fight.gdb` with `INGAME=1` timed out on maximum-speed `a4000-030`
  after installing its original Core caller breakpoints. The maintained
  debugger-free monster audit reaches song 132 and normal cleanup. Determine
  whether the standalone fixture lacks required setup or loses its live caller;
  do not treat its timeout as evidence of a gameplay failure or a pass.

  *Done when* its documented build/settings produce a bounded positive song-132
  transition with caller-byte, register and resource checks, or the obsolete
  observer is replaced by equivalent maintained coverage.

- **TEST.7 Enforce the long-effect fixture's timing requirements.**
  The injected 131,073-byte effect needs about 16.37 seconds. On maximum-speed
  `a4000-030`, original driver selector 22 stops it after about 10.8 seconds,
  before the fixture's complete-stream assertion. The documented reference-68030
  configuration passes the entire sample. This is an observer setup limitation,
  not evidence that production should ignore the original stop command.

  *Done when* the fixture rejects incompatible settings before running, or a
  properly isolated fixture verifies the complete stream at those settings.
  Preserve the separate original stop/replacement contracts and full PCM checks.

- **MEASURE.2 Preserve the executed PC across CPU exceptions.**
  The profiler reads `instruction_pc` after the CPU instruction returns, but
  FS-UAE's PC setter changes it during exception entry. Line-A entry is thus
  charged to the first native handler instruction, whose count is doubled.
  Preserve the pre-execution PC/opcode in the shared profiler; distinguish
  native instruction cost from CPU exception entry when interpreting results.

  *Done when* an isolated Line-A fixture counts the trap and first handler
  instruction once each, JSR/RTS and interrupt controls pass, and total cycles
  remain conserved. Re-measure affected profiles and keep CPU Line-A entry in
  the dispatch budget explicitly; attribution changes alone are not speedups.

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

## TickCount resolution

- **TICK.1 Measure short waits against PAL field-only ticks.**
  TickCount returns the field-updated shadow. The shared VideoTicks test shows
  that repeated five-tick waits can lock onto six-tick intervals when observing
  only the PAL sequence 0,1,2,3,4,6. This establishes the clock-resolution
  limitation, not its effect on this game's routes. Measure the original and
  state-paired native waits before changing the clock; investigate coherent
  within-field sampling through the shared helper if affected.
  Acceptance: matched original/native deadline and cadence evidence, with
  monotonicity, rollover, pending-VBI and callback-time controls.
