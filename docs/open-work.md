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

- **AUDIO.1 Reduce native song-start preparation cost.**
  Use the [per-song attribution](performance.md#monster-to-death-cycle) to optimize
  native song preparation. Preserve on-demand
  loading, original song events, sample bytes, interrupt timing and resource ownership.
  Exclude original game instructions and unrelated drawing/presentation from the target.

  *Done when* each of songs 136, 132 and 131 takes ≤ 0.3 s in `startNativeSong`
  on the pinned reference-68030 monster route, with repeatable event-boundary profiles.
  Report full frame intervals separately. Song playback, gameplay music/fight,
  death/cleanup, low-memory and fragmented-heap regressions must pass with no new
  allocation failures. Real-Amiga benchmarks remain deferred.

- **CACHE.1 Verify WHDLoad copyback caches on hardware — deferred by the owner.**
  Run the [cache validation](testing.md#whdload-cache-validation) on the owner's
  68040 with both caches enabled. Record the effect against PERF.3 and inspect a
  complete monster-to-death sequence for display/audio corruption.

  *Done when* the hardware performance comparison and complete visual/audio run
  are recorded. Corrected FS-UAE functional checks do not satisfy this hardware gate.

- **FRAME.8 Optimize ordinary thin-pen Line/LineTo strokes.**
  The remaining 1×1 strokes in the reference-68030 fight average about 331 µs
  for LineTo and 335 µs for relative Line. Profile validation, clipping and the
  original rasterizer separately from the zero-displacement thick particle pens.
  The owner chose to track this separately from FRAME.2.

  *Done when* original slope/reversal/clipping fixtures, relative-line and
  `lineto_call.gdb` pixel/ABI comparisons pass, and thin-pen Line/LineTo costs
  ≤ 80 µs per call in repeatable fight profiles. Preserve exact raster ties,
  dirty bounds and frame/callback service points.

- **FRAME.5 Speed up large BlockMove copies.**
  `Dark+$1B7A` makes 39 large BlockMoves in the fight (1.15 ms each, 5.5 ms per frame).
  Use aligned longword or MOVE16 paths with exact overlap semantics.

  *Done when* overlap, odd-alignment and length-boundary host tests pass and BlockMove
  costs ≤ 2 ms per fight frame.

- **FRAME.6 Reduce effect start and polling cost.**
  `playNativeEffect`, `serviceNativeEffects` and `waitPaulaDmaLines` cost about 5 ms per
  fight frame; each start converts the sample into new Chip memory again. Reuse
  converted immutable samples and avoid DMA waits for already quiet channels.

  *Done when* effect slot, loop, DMA, fraction and replace fixtures pass, priorities
  and audible timing are unchanged, and effect work is ≤ 1 ms per fight frame.

- **FRAME.7 Check fight-frame C2P bounds.**
  C2P takes 12.6 ms per fight frame. Verify that two-actor dirty bounds are the
  combined clipped coordinates before alignment and that no conversion overlaps.

  *Done when* `frame_pacing.gdb` and the C2P verification build pass and C2P is
  ≤ 10 ms per fight frame, or the bounds are shown to be already minimal.

- **FRAME.9 Assess larger unmasked CopyBits calls.**
  The actor-mask target excludes larger unmasked copies. The reference-68030
  fight currently measures about 658 µs at (Dark, $1DE6) and 908 µs under Misc2.
  Attribute setup, pixel movement and required services separately before
  selecting another optimization; these costs do not establish a defect.

  *Done when* repeatable profiles record call dimensions, total frame cost and
  the dominant work, with a justified optimization proposal or a finding that
  no further change is warranted. Preserve the original full-buffer comparisons.

## Runtime overhead

- **HEAP.1 Adopt shared heap helpers in Prince of Persia 2 — deferred by the owner.**
  Prince of Persia 2 work is ongoing elsewhere. When the owner resumes adoption,
  use AmigaXDev's shared MoveHHi and in-place resize implementations instead of
  forking allocator fixes. Preserve that port's placement, errors, handle state,
  payloads and memory publication contracts.

  *Done when* the deferred consumer uses the canonical helpers and passes its
  original/native placement, unchanged-size, grow/shrink, failure and fragmented
  heap fixtures, with matched native workloads establishing the effect.

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
