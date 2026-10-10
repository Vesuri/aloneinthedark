# Performance measurement

Use fixed-clock `a1200-020` or `a4000-030-reference`, with CPU/video/memory settings
recorded. Measure guest ticks/fields and completed frames; host wall time measures
emulator throughput. Warp speeds up a diagnostic without being a game benchmark. The
[intro reference](intro-comparison.md) has matched car, frog, walking and transition
results. The following profiles describe retained measurement builds, not universal
frame-rate guarantees.

## Cycle profiler

`amiga/aprof.sh` gives exact emulated cost, not samples. It runs a private FS-UAE
built by `tools/build_fsuae_aprof.sh`: the same barto remote-debugger fork as the shared
ARM emulator, plus `tools/fsuae_aprof.patch`. Between `monitor aprof start` and
`monitor aprof stop FILE`, the cycle-exact 68020/68030 loop charges every instruction's
cycle units, including wait states, to its PC. This covers original CODE segments,
native code, Kickstart and interrupts. The patch also times every CPU Chip-bus access.
A call tree follows JSR/BSR/RTS and exceptions; each Line-A exception is keyed by its
trap word. Warp does not change emulated cycles. Other CPU loops (MMU, 040/060, fast
mode) refuse to start, and timing matches the emulator's memory model, not proof of
hardware timing.

```sh
. amiga/env.sh
tools/build_fsuae_aprof.sh                  # once; FSUAE_APROF overrides the result
amiga/aprof.sh book 2 50 book               # book steps 2..52, production build
amiga/aprof.sh gameplay 60 100 attic        # INGAME scenes 60..160, first room
python3 tools/aprof_report.py report attic
python3 tools/aprof_report.py annotate attic RegionRows::row
python3 tools/aprof_report.py subtree attic 'JT291->Dark3+$1D50'
```

`aprof.sh` clean-builds the matching executable and defaults to
`a4000-030-reference`. It stops loudly if the interval is incomplete, the room or camera
changes, or a CODE segment moves. Outputs go to ignored `tmp/aprof/`; the report also
writes the call tree and the hottest instructions there. Original functions are named
`Segment+$offset` from LINK prologues and observed call targets. `JTn->` marks a
jump-table entry, resolved from the live table. Unmatched RTS/RTE counts measure
call-tree noise from stack manipulation and task switches; flat PC times are exact.

### Reference-68030 baseline

| PAL, `a4000-030-reference` | Book fold, steps 2–52 | First room, scenes 60–160 |
| --- | ---: | ---: |
| Fields / steps | 220 / 50 | 516 / 100 |
| Time per step | 88.5 ms | 103.3 ms |
| Original game code | 0.6 ms | 53.8 ms |
| C2P | 35.9 ms | 9.1 ms |
| QuickDraw fills, lines, regions | 16.8 ms | 3.2 ms |
| QuickDraw CopyBits | 4.0 ms | 10.1 ms |
| Trap entry/dispatch, state lookups, VBL polling | 19.1 ms | 21.2 ms |
| Other presentation | 9.9 ms | 0.6 ms |
| CPU Chip-bus accesses (included above) | 26.5 ms | 6.4 ms |

In the first room, the original model renderer (`Dark3+$1D50`, entered via jump-table
entry 291) costs 43.8 ms. Skeleton animation and vertex transform account for 16.0 ms,
and its own edge and span fill for 14.0 ms. Its O(n²) primitive depth sort costs about
6.7 ms, and per-primitive dispatch 4.8 ms. The same call adds 14.3 ms of port time,
mostly from the model's 11 lines: RGBForeColor, PenMode, MoveTo and LineTo are separate
traps. Any trap costs roughly 1,500–2,600 cycles before its own work. That includes a
~230-cycle Chip RAM exception-vector read, since VBR is 0. CopyBits from `Dark+$30A8`
spends 5 ms per frame revalidating mask regions.

The book has 8 bitplanes at FMODE=0, so bitplane DMA takes nearly every Chip slot on
visible lines. C2P stores and the CPU back-buffer synchronization wait an average 32
cycles per access. With the Kickstart CACR of $2001, the 68030 data cache is off.
Enabling it with emulated data-cache timing did not speed up the first room.

## Steady gameplay

Load the ordinary first-floor checkpoint with `FIRSTFLOORLOAD=1 INTROSKIP=1`, settle for
200 PAL fields, and count completed scenes over 3,000 fields. Compare like-for-like
instrumentation. The retained fixed-020 diagnostic baseline rose from 7.12 to 9.62 FPS
through dirty-only publication, palette seed caching, constant-time handle validation,
common-trap fast paths, CopyBits span/stride work and constant-time scene completion.
These are diagnostic-build rates.

The older statistical sampler remains for the first-floor checkpoint; prefer the cycle
profiler for cost attribution. `sample_gameplay.py` interrupts the debugger at
randomized host intervals. Use
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

## Book turns and frame pacing

The book uses 56 authored steps per forward page turn. The original wait at
(Dan1, $4978) holds each page for 300 Mac ticks (five seconds). On the unlimited
68040/JIT PAL configuration, the opening's 15 turns run at 50 FPS; the 14 intervening
holds account for 70 seconds of the 86.5-second interval from the first animated
publication to the last. Rendering optimizations do not shorten these reading holds.

On the default cycle-exact 15.6672 MHz 68030/PAL setup, a lightweight
`FRAMEAUDIT=1` run measures **11.74 displayed steps/s** within the moving folds
(825 intervals, 2–8 fields each, mean 4.259). The first-to-last book publication
spans 145.74 seconds: 70.28 seconds within folds and 75.46 seconds in the 14
page-transition gaps, including the 70 seconds of deliberate reading holds.
These are emulated-field measurements, independent of host warp speed.

The [cycle profile](#reference-68030-baseline) of a fold attributes 40.6% of each step
to C2P, half of it Chip-bus waiting. Six PaintRects take 11.7% and one fold LineTo
6.5%; the back-buffer copy in `presentMacFrame` takes 11.0%. Original code is 0.6%.
Completed-frame pacing adds no extra wait per drawing call.

Book dirty bounds are accumulated from the min/max coordinates of actual clipped
fills, lines and copies. At frame completion, combine those bounds **before** C2P
alignment. This avoids overlapping conversions caused by separately aligned page
strips. No shadow framebuffer or pixel comparison computes the dirty rectangle.
All 840 opening steps use one converted rectangle, ranging from 6,400 to 38,400 pixels
(mean 22,057), rather than the full 64,000-pixel viewport. Alignment is 16 pixels at
the left edge and a width divisible by 32, as required by the Kalms converter.

Solid spans align their longword stores and handle unmasked rectangles with a
fixed row stride, without region-edge work on each row. Back-buffer synchronization
copies only prior dirty spans not fully replaced by the current conversion. With the
pointer disabled, these copies
need no cursor-inversion interrupt guard: VBI cannot alter the buffers until the
completed frame is queued. The explicit cursor fixture retains its guarded path.

`frame_pacing.gdb` checks the original 106 armadillo loop steps and all 840 book steps:
one wait and one publication per step, no waits inside drawing batches, and C2P bounds
exactly matching coordinate bounds plus alignment. The ordinary build contains no
profiling timers. `FRAMEAUDIT=1` adds a bounded report for WHDLoad/emulators without GDB;
its timing field is written at the actual VBI buffer swap. Neither diagnostic needs
shadow comparisons. The separate `C2PVERIFY=1` correctness build decodes every pixel,
including pixels outside dirty areas; never use its expensive verifier for FPS claims.

The action-menu observer also requires exactly one wait/publication per completed
preview rotation, rather than one per drawing trap. Gameplay scene batching retains
its unchanged-frame simulation pacing and complete-frame publication checks.

## Save-related WHDLoad switches

A fresh save measured seven OS returns on the maximum-speed 68030 with 8 MB
Fast RAM plus 32 MB Zorro III RAM, PRELOAD enabled and FILELOG disabled.
The individual resload calls account for all seven:

| Operation | OS returns |
| --- | ---: |
| Create empty data fork | 1 |
| Create 32-byte Finder metadata | 1 |
| Write 36,254-byte game state | 1 |
| Create empty resource fork | 1 |
| Publish initial 286-byte resource map | 1 |
| Publish resource payload and subsequent map update | 2 |

Later metadata writes were cached by WHDLoad. Updating an existing save in a
fresh launch measured four returns: two initial fork reads, one metadata write,
and one resource-fork write. These counts depend on cache contents and resource
sizes; they are observations, not fixed guarantees. FILELOG inflated the measured
fresh-save count to nine and the existing-save count to seven, so disable it
when measuring normal-play disk switches.

The File Manager already buffers individual writes and publishes a whole dirty
fork at flush/close. Resource Manager creation, WriteResource and UpdateResFile
publish distinct resource states. The remaining fresh-save writes are not
identical redundant writes. Combining them would defer successful creation or
publication across original service boundaries, changing failure reporting and
persistence behavior. The resload API accepts one file per save call; it has no
multi-file transaction API. No additional runtime buffering is applied.

WHDLoad's default write cache can itself defer writes until exit. Preserve its
policy; do not interpret a cached success as a physical disk flush. Normal Quit
and a fresh uncached load are the persistence checks. One or two OS returns
are therefore not a safe general target for this save implementation.
