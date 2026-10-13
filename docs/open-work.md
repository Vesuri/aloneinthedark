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

- **REGION.1 Speed up camera-change mask rebuilding.**
  A camera change (`JT254->Dark2+$5D30`) rebuilds masks below `JT187->Dark+$3694`.
  InsetRgn costs about 28–40 ms per call (`RegionExpand::one`), FramePoly 14–19 ms
  (`PolygonRegion::encode`), and CloseRgn and KillPoly about 2.7 ms each. The original
  background decompression (`Dark+$2A78`/`$29FE`, about 0.8 s per change) is a fixed
  floor. Keep exact region results and loud rejection of malformed regions.

  *Done when* region-variant, InsetRgn, polygon, mask-rejection and corridor-mask
  fixtures pass and port time below `Dark+$3694` falls by at least 60%.

- **FRAME.1 Memoize RGBForeColor/RGBBackColor colour lookup.**
  A fight frame makes about 70 RGBForeColor calls at 179 µs each, mostly
  `gWorldForPort`, handle checks and `GWorld8::colorIndex`. Cache the result per port,
  keyed by the colour and inverse tables' seeds and contents identity plus the RGB value.
  Invalidate it on any table change.

  *Done when* every call in a monster-profile run returns the uncached index (checked by a
  verifying build), `rgb_colors_calls.gdb` and window colour fixtures pass, and a call
  costs ≤ 30 µs.

- **FRAME.2 Draw thick-pen Line and LineTo directly.**
  `(Dan2, $3D08)` runs about twice per fight frame, drawing about 23 thick-pen lines
  each with an RGBForeColor per line (36 ms per frame, 28 ms in the port). Line costs
  317 µs per call, mostly `lineGWorld` → `FillRect8::solid` setup and a `handleSize`
  lookup per call.

  *Done when* pen-size/shape, relative-line, point-line and `lineto_call.gdb`
  fixtures pass and Line/LineTo cost ≤ 80 µs per call in the fight.

- **FRAME.3 Reduce per-call CopyBits cost for actor masks.**
  `Dark+$30A8` makes about 43 CopyBits per fight frame (9 in the empty attic) at 814 µs
  each: `CopyBits8::copy`, `RegionRows::ValidationCache::validate`, `RegionRows::row`,
  `copyPortBits8` setup and heap lookups.

  *Done when* copybits8, maskcopy, mask-rejection and corridor fixtures pass and
  CopyBits averages ≤ 350 µs in the fight.

- **FRAME.4 Extend quick-trap entry to fight-frame traps.**
  Line, RGBForeColor, PenSize and QDExtensions still pay full Line-A dispatch (trap
  entry and dispatch about 18 ms per fight frame). Keep the register image, CCR, Pascal
  ABI, patched-trap fallback and frame/callback service points.

  *Done when* `quick_traps.gdb`, `frame_pacing.gdb`, `scene_frame_verify.gdb`,
  `apple_events.gdb` and `m5_circuit.gdb` + `check_m5_audit.py` pass with no added
  lateness, and trap entry/dispatch is ≤ 9 ms per fight frame.

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

## Runtime overhead

- **HEAP.1 Avoid heap-wide work for unchanged allocation sizes.**
  `MacHeap::resizeInPlace` calls `split` and `coalesce` even when the requested
  logical size already matches the allocation. The latter walks the entire
  zone. Inspect the reached `SetHandleSize`/`SetPtrSize` and internal region
  callers; measure their frequency and cost before changing the allocator.
  Reuse and consolidate the fix through AmigaXDev. Prince of Persia 2 adoption,
  including the shared MoveHHi implementation, is deferred by the owner while
  work there is ongoing.

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
