# Performance measurement

Use fixed-clock `a1200-020` or `a4000-030-reference`, with CPU/video/memory settings
recorded. Measure guest ticks/fields and completed frames; host wall time measures
emulator throughput. Warp speeds up a diagnostic without being a game benchmark. The
[intro reference](intro-comparison.md) has matched car, frog, walking and transition
results. The following profiles describe retained measurement builds, not universal
frame-rate guarantees.

## Steady gameplay

Load the ordinary first-floor checkpoint with `FIRSTFLOORLOAD=1 INTROSKIP=1`, settle for
200 PAL fields, and count completed scenes over 3,000 fields. Compare like-for-like
instrumentation. The retained fixed-020 diagnostic baseline rose from 7.12 to 9.62 FPS
through dirty-only publication, palette seed caching, constant-time handle validation,
common-trap fast paths, CopyBits span/stride work and constant-time scene completion.
These are diagnostic-build rates.

`sample_gameplay.py` interrupts the debugger at randomized host intervals. Use
`gameplay_sample.gdb` after connecting at MacLoader::run with the matching ELF/save.
Pass `--gdb`, `--elf`, `--connect`, `--setup`, `--out` and `--samples 2000`, from
`amiga/`. `summarize_gameplay_profile.py` verifies the room and assigns each PC exactly
once, prioritizing original segment ranges over native backtraces. Sampling can be
biased by emulator throughput; zero sampled PCs is not proof of zero cost. Do not add
overlapping scope timers.

Two instrumented fixed-020 samples total 99.67/99.65 ms per frame; original code
accounts for 59.30/60.83 ms and other native/trap services for 27.96/28.00 ms. The
fixed-030 sample totals 86.67 ms, with 51.66 ms in original code. These used different
emulator builds and do not establish a cycle-accurate hardware ratio. Rare IRQs need
direct E-clock accounting rather than PC sampling.

## Item menu and enemy room

The record item's original preview calls PtInRect for individual nontransparent pixels
at (Dan2, $1966), within $1934–$199E. That accounted for 46.3% of the baseline samples.
The shared fast dispatcher removes this overhead while preserving signed half-open
bounds, Pascal ABI, patched-trap fallback and frame/ callback service rules. Original
game instructions are unchanged.

| Fixed 68030 preview | Updates per second |
| --- | ---: |
| Native before fast PtInRect | 2.741 |
| Native with fast PtInRect | 4.001 |
| Original Mac IIx | 2.094 |

These measure steady preview redraws at the original angle decrement (Dan1, $0F7A), not
menu-opening or key-response latency. Compare completed draws at Dan1+$10EA with the
same item, angle, focus and inventory. A past 186-byte screen mismatch was exactly the
selection-label colour change; matching angle alone was not matching UI state. The
preview pane and palettes match in the controlled comparison. Remaining work is spread
across copying, original per-pixel processing and common services.

The pirate room's native sample is 45.0% original code, 52.5% native runtime and 2.1%
Kickstart; C2P is 9.1% and CopyBits 5.4%. Two dynamic native windows produce 2.68 and
2.53 FPS. Mac context is about 3.51 FPS, but positions, poses and attack phases differ,
so this is not a matched-state ratio. Health was raised only for the bounded profiling
fixture. No single enemy-specific service dominates as PtInRect did in the item menu.

## Loading and interrupts

Cold scene masks, synchronous song-resource preparation and steady rendering are
separate workloads. Heap/allocator changes removed large preparation penalties, but a
resource switch can still contain seconds of synchronous work. Measure the complete
old-to-new scene boundary and identify its constituent operations before optimizing a
helper. Keep sprite/VBI and CIA music progress independent of that main-thread latency.

Use `M5AUDIT=1` with the matching observers for memory and IRQ accounting; see
[amiga-arch.md](amiga-arch.md#interrupt-checks). C2P may only convert changed areas
after a completed frame. Do not reintroduce chunky shadow comparisons.
