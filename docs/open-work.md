# Open work

This is the work queue. Work it from the top, one item per commit; split an item only if
it has independent parts. Delete an item in the commit that finishes it, because the Git
log records finished work. The design and its rationale are in [design.md](design.md),
cited below by § number; owner decisions D1–D9 are in design.md §5.

Each item gives the **goal**, then the scope, then *done when*: the evidence required.

## Rendering performance

Baselines are the
[reference-68030 cycle profiles](performance.md#reference-68030-baseline):
`amiga/aprof.sh book 2 50` (88.5 ms per fold step) and `amiga/aprof.sh gameplay 60 100`
(103.3 ms per first-room frame). Each item's commit reports both runs before and after.
Original game instructions stay unchanged; these items reduce port cost only.

- **PERF.1 Fetch the 8-plane display with 64-bit AGA bitplane DMA (FMODE=3).**
  With FMODE=0, bitplane DMA takes nearly every Chip slot on visible lines; book C2P
  stores and back-buffer copies wait 26.5 ms per step. `AitdScreen` owns the change:
  the FMODE bitplane bits (BLP32/BPAGEM), DDFSTRT/DDFSTOP for 64-bit fetches and
  8-byte alignment of both bitplane buffers. The interleaved 40-byte plane stride and
  280-byte modulo are already multiples of 8. Keep sprite width and data format
  unchanged unless the cursor and empty sprites are converted and checked. Prove the
  window position is unchanged in PAL and NTSC.

  *Done when* the book run spends at most 13 ms per step in CPU Chip-bus accesses, with
  lower total time per step. The `intro` C2P verification and `frame_pacing.gdb` pass,
  and cursor/sprite fixtures pass. PAL and NTSC captures of the book, menu and first
  room match pre-change captures. Fixed `a1200-020` and `a4000-030-reference` runs
  complete.

- **PERF.2 Reduce the fixed cost of every Toolbox trap.** Before its own work, any trap
  costs about 1,500–2,600 cycles. In the first room, trap entry/dispatch, state lookups
  and VBL polling take 21.2 ms per frame for about 127 traps. PenMode costs 102 µs
  per call, MoveTo 122 µs and RGBForeColor 345 µs; the model's 11 lines cost 11.7 ms.
  Run per-trap housekeeping only when something is pending: VBL scheduling runs twice
  per trap, plus effect polling, song-error checks and frame-boundary tests. Add fast
  paths for the measured simple drawing-state traps. Preserve the Pascal ABI, live
  registers and CCR, patched-trap routing, frame batching boundaries, and VBL callbacks
  only at safe user-mode return points.

  *Done when* the attic run spends at most 10 ms per frame in those three buckets.
  Outermost PenMode and MoveTo calls cost at most 40 µs each. `frame_pacing.gdb`,
  `scene_frame_verify.gdb`, `apple_events.gdb` and `m5_circuit.gdb` with
  `check_m5_audit.py` pass, and the audit shows no added VBL callback or note lateness.

- **PERF.3 Stop revalidating unchanged mask regions in CopyBits.**
  `RegionRows::Cursor::begin` decodes and validates a whole QuickDraw region before
  every masked copy: 5.2 ms per first-room frame for seven copies. Each call also
  makes about five handle-size lookups. The original code can modify region handles
  directly, so any reuse must detect changed bytes, size or handle. A malformed region
  must still stop loudly before it is drawn.

  *Done when* port time below `Dark+$30A8` in the attic run is at most 8 ms per frame
  (baseline 13.3 ms). `RegionRows` takes at most 1.5 ms. The CopyBits, region and
  corridor-mask checks and scene-frame comparisons pass, including a malformed-region
  rejection case.

- **PERF.4 Speed up native solid fills, lines and back-buffer synchronization.** Measure
  after PERF.1. One book-fold LineTo spends about 500 cycles per pixel in `Line8::solid`
  (5.8 ms per step). Six PaintRects take 10.4 ms in `FillRect8::solid`, with
  stack-spilled row state. `presentMacFrame` copies prior dirty spans Chip-to-Chip with
  the CPU (9.7 ms per step). Keep exact QuickDraw pen, pattern, clip and region
  semantics and explicit dirty rectangles. A blitter copy must complete before
  presentation and respect VBI display ownership.

  *Done when* the book run spends at most 8 ms per step in QuickDraw fills, lines and
  regions (baseline 16.8 ms). Other presentation takes at most 3 ms (baseline 9.9 ms).
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
