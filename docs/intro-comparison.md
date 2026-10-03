# 68030 intro comparison — 2026-10-03

The current port is not yet comparable throughout the intro. Outdoor animation
is about 1.6–1.8 times slower than the reference. Several indoor views are
2–3.5 times slower, and the later corridor reverse view is approximately five
times slower. Camera-transition gaps are much closer: the longest measured
boundary span is 9.05 seconds on Amiga versus 8.07 seconds on Mac.

## Setup and measurement

Both CPUs run at 15.6672 MHz: MAME `maciix`, 8 MB RAM, and FS-UAE's
`a4000-030-reference`, 68030, AGA, 2 MB chip/8 MB fast RAM, no JIT/MMU/FPU.
Amiga audio is enabled and warp disabled. MAME runs headlessly with host sound
disabled; original emulated sound processing remains active. MAME's unthrottled
host execution does not change the emulated 60 Hz clock used here. Different
memory systems and the emulators' approximate timing prevent cycle-exact
hardware equivalence.

The native configuration explicitly requests 8 MB Zorro II fast RAM and no
motherboard RAM ([FS-UAE option definition](https://fs-uae.net/docs/options/fast_memory/)).
However, the installed core's actual post-autoconfiguration map reports
`00200000 8192K ID* F32 Fast memory` in the bulk-copy profile. Its effective
timing classification therefore does not support blaming the residual gap on
a 16-bit fast-RAM bottleneck. Retain the fixed reference configuration; do not
substitute a faster memory setup on that unproven assumption.

The ordinary native build is commit `8cd8f60` with `INTROSKIP=1`, without
profiling or fixed randomness. The original Mac game is unmodified. Read-only
observers capture original Dark+$5658 loop entries, indexed viewport pixels,
palette and actor records. Normal input gets to the menu; no debugger writes
force a character, route or game timer. The measured section starts with the
menu's unattended demo, excluding the book.

The first Mac run selected Carnby and the Amiga selected Emily. A second Mac
run, with a one-frame change in normal launch-input timing, selected Emily
naturally. **Tables below compare Emily with Emily.** All three runs reached
natural completion and all nine original major transition checkpoints. The
native run also passed all 3,736 music events, maximum delivery lateness one
logical tick and zero late frame publications. An earlier native run that
ended outdoors is excluded.

Frame rates count distinct completed viewport images during visible actor
movement, divided by the corresponding emulated time. Actor IDs are 286 (car),
289 (frog) and 288 (person). Movement uses position, angle and animation-frame
changes; visibility uses the original bounding rectangle. The first loop of
each camera visit is excluded from animation rates. Identical images, including
subpixel movement of the distant frog, do not count as new frames. These are
scene averages, not the display's refresh rate or matched-pose microbenchmarks.

Transition spans run from the last loop checkpoint in the old view to the first
completed loop in the new view, including intermediate setup-only camera states.
They include one old-view loop and first-frame work; they are comparable
checkpoint spans, **not exact measurements of black pixels on the display**.
Room/camera numbers are reused between floors, so visits and actual backgrounds
are matched in sequence rather than by those two numbers alone.

Raw evidence is local-only under `tmp/route-comparison/`: `mac-loops.log` and
`mac/` for Carnby, `mac-delay.log` and `mac-delay/` for Emily, `amiga-full.log`
and `amiga/` for Emily. The corresponding Lua/GDB observers and `analyze.py`
are alongside the captures. Mac Emily has 2,410 loop snapshots; Amiga has
1,100. Both runners exit zero. Original pixels and data are not committed.

## Active animation

| Scene | Mac FPS | Amiga FPS | Amiga time per visible frame / Mac |
| --- | ---: | ---: | ---: |
| Car, opening wide pond view | 4.61 | 2.72 | 1.69× |
| Frog, near road/car view | 4.55 | 2.58 | 1.76× |
| Frog, distant pond view | 4.03 | 2.31 | 1.74× |
| Person approaching mansion | 10.69 | 7.66 | 1.40× |
| Approach viewed from window | 5.92 | 4.47 | 1.32× |
| Entering front doors | 5.66 | 2.65 | 2.14× |
| Entrance hall, next view | 6.09 | 5.40 | 1.13× |
| Lower hallway, first view | 8.10 | 4.66 | 1.74× |
| Lower hallway, stairs visible | 7.33 | 2.08 | 3.52× |
| Foot of stairs | 6.21 | 2.12 | 2.93× |
| Ascending stairs | 10.34 | 7.56 | 1.37× |
| Upper hall, room 2/camera 5 | 6.80 | 2.94 | 2.31× |
| Upper hall, camera 3 | 8.08 | 3.63 | 2.23× |
| Upper landing | 9.58 | 6.57 | 1.46× |
| Later corridor, toward camera | 8.04 | 4.29 | 1.87× |
| Later corridor, reverse view, first visit | 5.74 | 1.13 | 5.08× |
| Later corridor, toward camera, second visit | 7.20 | 3.61 | 1.99× |
| Later corridor, reverse view, second visit | 6.08 | 1.25 | 4.86× |
| Final hallway, first view | 8.11 | 1.86 | 4.36× |
| Final hallway, next view | 10.59 | 5.59 | 1.89× |
| Final room | 10.95 | 6.61 | 1.66× |

The slow corridor result is not an artifact of averaging in camera changes.
Its median active loop interval is 49 ticks on Amiga versus 10 on Mac on the
first visit, and 48 versus 10 on the second. The first visit includes a native
96-tick interval (1.6 seconds), versus a Mac maximum of 13 ticks. Carnby's Mac
rates in the same reverse views are 5.84 and 6.29 FPS, corroborating the scale
of the gap independently of character choice.

The very close car pass contains pauses on both machines and is not represented
by the opening-car rate: only three/four distinct images occur in the selected
Mac/Amiga active intervals, giving 0.65/0.60 FPS. The longest individual
intervals are 205/189 ticks. This is a short, irregular scripted passage and
does not establish a general car-rendering rate.

## Camera transitions

| From → to | Mac seconds | Amiga seconds |
| --- | ---: | ---: |
| Opening wide pond → near frog/car | 1.08 | 1.07 |
| Near frog → distant frog | 1.22 | 1.70 |
| Distant frog → gate | 1.40 | 1.53 |
| Gate → mansion approach | 2.30 | 2.27 |
| Mansion approach → window view | 1.77 | 2.02 |
| Window view → inside front doors | 8.07 | 9.05 |
| Front doors → next entrance-hall view | 2.03 | 2.88 |
| Entrance hall → lower hallway | 3.77 | 4.82 |
| Lower hallway → stairs visible | 1.72 | 2.23 |
| Stairs visible → foot of stairs | 1.83 | 2.40 |
| Foot of stairs → ascending view | 1.57 | 2.13 |
| Ascending view → upper hall | 6.08 | 6.88 |
| Upper hall camera 5 → camera 3 | 1.78 | 2.67 |
| Upper hall → landing | 4.50 | 4.70 |
| Landing → later corridor | 2.95 | 4.17 |
| Corridor toward camera → reverse | 1.15 | 1.62 |
| Corridor reverse → toward camera | 1.58 | 3.37 |
| Corridor toward camera → reverse again | 1.18 | 1.82 |
| Corridor → final hallway | 1.98 | 2.40 |
| Final hallway camera change | 1.07 | 1.07 |
| Final hallway → final room | 1.05 | 1.03 |

The Amiga additionally revisits exterior cameras 1 and 0 before the final
gate-to-mansion-approach change. Those extra changes take 1.40 and 1.55 seconds;
they have no corresponding visit in these Mac runs. They are not silently
folded into the 2.27-second final gate-to-approach change.

No camera boundary in the completed current runs reproduces a 15-second gap.
The Mac itself spends several seconds on major room changes. That explains
part of the perceived pause, without explaining away the remaining port costs.

## Scenes and car route

Both versions show the wide pond, car passing near the frog, distant frog/pond,
gate, mansion exterior, approach seen from a window, front doors, lower hall,
staircase, upper hall, landing, narrow corridors and final room. Paired internal
framebuffer captures confirm the backgrounds. Both close and distant frog
animation are present. **A full-screen frog bitmap was not observed in these
68030 idle-demo runs.** This does not prove that such an image is absent from
other routes or timing conditions; there is no evidence here of an Amiga-only
omission to repair.

The car follows the same original script-offset progression through the
approach and departure, but not the same geometric trajectory. Both reference
Mac runs circle near the early turning waypoint. At original track word 20,
the Carnby Mac run spends 120.23 seconds and the Emily Mac run 217.60 seconds;
the Amiga spends 20.00 seconds there. Conversely the Amiga spends 20.43 seconds
at word 60, where the Emily Mac run has only one sampled loop entry. These are
first-to-last sampled residence spans, not exact instruction-level durations.
The Amiga's extra exterior camera revisits accompany that later loop.

The first 44 straight-approach samples at track word 4 cover identical endpoints
on both machines, taking 12.80 seconds on Mac and 19.30 seconds on Amiga. Paths
diverge during turning. Existing original-code observations establish a
400-unit waypoint threshold and timed turns of 64 angle units over 15 ticks
(Dark2+$4C6C/$4C7A/$4CD2). Movement sampled at different frame intervals can
overshoot a waypoint and circle; the captures support that explanation rather
than an Amiga-specific replacement route. Exact sensitivity to the initial
timing is not fully isolated. The original movement code remains unchanged.

Consequently total demo duration is unsuitable as a speed score: Mac Emily
takes 430.35 seconds from menu return to completion, versus 304.87 seconds on
Amiga, despite the Amiga's markedly lower indoor frame rates.

## Attribution and remaining work

Earlier matched car geometry measures the native renderer at 15 ticks versus
12 on Mac, and the full frame at 18 versus 12. Frog model drawing alone is
3–4 versus 2–3 ticks, while cold mask construction has a much larger gap.
The bulk key-release fix removed substantial repeated file-window overhead;
major transition costs now lie much closer to Mac. These findings and their
limits are recorded in [amiga-arch.md](amiga-arch.md#intro-performance-comparison-2026-10-03).

Those isolated measurements do **not** explain or excuse the newly measured
fivefold sustained corridor slowdown. Its cause must be profiled at the actual
late visit; room 1/camera 2 is also used earlier at the front doors. P1 remains
open, prioritizing this large rendering gap and the other 3–4× indoor views
over marginal heap or helper optimizations. No owner-run Mac comparison is
required for that work.

An additional `PROFILEFRAME=900` corridor diagnostic was stopped: after 1,281
publications it was still outdoors at tick 28,608, circling in room 0/camera 0.
The profiler had not started. This invalidates publication count as a way to
distinguish the later corridor from the earlier entrance. That run supplies no
corridor attribution or performance result. The next profile must follow the
original scene sequence through the upper landing before arming the corridor
capture. The ordinary unprofiled build is restored after this experiment.

The subsequent sequence-triggered profile succeeds (`CORRIDORPROFILE=1`,
`INTROSKIP=1`, `PROBEFIELDS=250`; `amiga/corridor_profile.gdb`). It arms only
after room 7/camera 1, then starts in the later room 1/camera 2. The retained
`tmp/route-comparison/corridor-sequence-full.log` exits zero; its end-frame
capture confirms the narrow corridor with Carnby. The interval contains 250
PAL fields, 10 publications and 20,029,736 beam units. Inclusive presentation
is 6,221,215 units (31.1%), including synchronization 2,821,028 and C2P
2,914,705. Shared trap servicing is 7,054,685 (35.2%); original Mac VBL
callbacks total 4,494,699 (22.4%). These categories overlap. Region expansion
is only 652,802 (3.3%), so further tuning it would miss the main cost here.

The unprofiled Emily trace exposes repeated presentation within each game
step: after the first reverse-view loop, 10 animation intervals cause 29
publications; on its second visit, six cause 19. Most steps publish three
times. Each publication performs conversion and back-buffer synchronization.
Investigate complete-frame presentation boundaries before more local geometry
optimizations. This is a measured source of repeated work, not yet a verified
fix or a complete explanation of the fivefold gap.

An opt-in `SCENEFRAMEBATCH=1` experiment now defers native presentation until
the original scene renderer returns. Original drawing, trap services, input
and music continue normally. The controlled `FIXEDRNG=1` baseline and trial
both select Carnby. Their two late reverse-corridor visits improve from
1.13 to 2.04 FPS and 1.22 to 2.65 FPS; median active-step times fall from
48 to 24 and 46 to 23 Mac ticks. The Mac Carnby reference achieves 5.84 and
6.29 FPS, so the remaining gap still requires investigation.

The trial (`tmp/route-comparison/amiga-fixed-batch.log`) completes naturally
with 1,411 balanced scene batches, 1,170 queued/presented frames, all 3,736
music events, maximum logical note lateness one tick and no late presentation.
`tools/check_scene_batches.py` independently decodes all 1,156 captured planar
buffers from the first scene batch through the final publication. Every pixel
and every palette entry matches the completed Mac surface. This establishes
buffer correctness, not host-window or audible acceptance. Baseline and trial
retain different timing-dependent outdoor routes; total intro duration is not
a speed comparison. After the full buffer check and residual-cost profile,
batching is enabled by default; `SCENEFRAMEBATCH=0` retains the diagnostic
baseline. The overall performance goal remains open.
Most controlled indoor averages improve, but the next foyer falls from 4.83
to 4.31 FPS and the first far-frog visit from 2.86 to 1.94 FPS. The latter
includes timing-dependent differences in visible motion and extra outdoor
visits; neither decrease should be dismissed without examining matched active
steps. Upper-hall and stairs views also remain more than twice as slow as the
Mac. The corridor improvement alone does not establish goal completion.

Closer inspection of the far-frog visit finds four unique matching moving
steps (identical start/end position, angle and animation frame). They total
55 baseline ticks versus 59 batched ticks, all producing changed images.
The scene averages cover different jump portions and different numbers of
unchanged subpixel/animation poses. Thus the 32% average FPS decrease does not
establish a 32% drawing regression; these four matched steps are about 7%
slower and remain too few to establish broad equivalence. The next foyer has
no exact matching moving-step pair under the same criterion, so its average
decrease also remains unassigned rather than being declared harmless.

The controlled Carnby scene averages are below. The Mac column uses its
naturally selected Carnby run; native columns use `FIXEDRNG=1`. These match
characters and scene visits, not every pose or timing-dependent car waypoint.

| Scene | Mac FPS | Native baseline FPS | Batched FPS |
| --- | ---: | ---: | ---: |
| Opening car | 4.36 | 2.75 | 2.95 |
| Near frog | 4.73 | 2.83 | 2.90 |
| Distant frog, first visit | 3.80 | 2.86 | 1.94 |
| Mansion approach | 11.90 | 7.25 | 7.46 |
| Window view | 6.50 | 4.60 | 4.67 |
| Front doors | 6.02 | 2.58 | 3.56 |
| Next foyer | 6.14 | 4.83 | 4.31 |
| Lower hall | 8.89 | 4.65 | 5.85 |
| Stairs visible | 7.30 | 2.04 | 3.33 |
| Foot of stairs | 6.43 | 1.97 | 2.76 |
| Ascending stairs | 10.59 | 6.45 | 6.49 |
| Upper hall, camera 5 | 7.59 | 2.98 | 3.04 |
| Upper hall, first camera 3 visit | 8.84 | 3.59 | 3.69 |
| Landing | 11.21 | 6.70 | 7.05 |
| Late corridor, toward camera | 9.31 | 3.72 | 4.51 |
| Reverse corridor, first visit | 5.84 | 1.13 | 2.04 |
| Toward camera, second visit | 8.45 | 3.56 | 3.68 |
| Reverse corridor, second visit | 6.29 | 1.22 | 2.65 |
| Final hallway | 7.41 | 2.34 | 3.47 |
| Next hallway view | 10.34 | 4.69 | 5.23 |
| Final room | 10.98 | 6.22 | 6.85 |

Batching makes little difference to complete camera-transition spans: entering
the mansion is 9.23→9.08 seconds (Mac 8.05), ascending stairs→upper hall is
6.83→6.82 (Mac 6.05), and the first late reverse→toward corridor change is
3.35→3.32 (Mac 1.58). These use the same checkpoint-span definition as the
earlier table. No batched indoor boundary exceeds 9.08 seconds. Improving
sustained rendering does not remove the remaining transition costs.

The batched late-corridor profile completes successfully with Carnby at
tick 24,240 (`amiga-fixed-batch-profile.log`, 250 PAL fields). Inclusive
presentation falls from 31.1% to 13.9% of measured time; synchronization falls
from 14.1% to 0.23%. Conversion is 10.5%, CopyBits 17.9%, original Mac VBL
callbacks 18.0%, and region expansion 4.0%. Categories overlap. Six complete
publications replace the old profile's ten intermediate publications; those
counts are not directly comparable animation rates. The unprofiled table is
the speed evidence. Buffer synchronization is no longer a major target;
inspect the dominant pixel-copying path next.

Reproduce the complete buffer/route check with a clean build using
`INTROSKIP=1 FIXEDRNG=1`, create
`tmp/route-comparison/amiga-fixed-batch/`, and run the maintained
`amiga/scene_batches.gdb` through `diag_run.sh` with the audible/no-warp
wrapper. Preserve the runner's exit status and log, then pass them to
`tools/check_scene_batches.py LOG CAPTURE_DIRECTORY --status STATUS`.
The checker also requires the independently measured, hash-checked local
`tmp/video-transfer-lut16.bin`; it does not replace it with the runtime's
colour implementation.

The pending bulk-copy candidate uses explicit `move.l` for direct 8-bit
spans, retaining masks, clipping, byte tails and palette-remapped copies.
Its complete controlled run (`amiga-fixed-copylong.log`, runner exit zero)
passes 1,087 independently decoded buffers, 1,336 balanced scene batches,
all 3,736 music events, maximum logical lateness one tick, and zero late
publications. Host sanitizer checks cover all alignments and lengths 0–129,
the existing clipping/mask suite, and retained original direct/masked-copy
destinations. A separate older capture is excluded because `enter-from.bin`
is missing. The first candidate was stopped after disassembly revealed GCC
had expanded an alignment-one integer copy into byte shifts; it supplies no
performance result. The tested candidate emits a real longword transfer.

Relative to batching alone, the two late reverse-corridor averages improve
2.04→2.26 and 2.65→3.11 FPS, with median intervals 24→21 and 23→20 ticks.
Upper hall camera 5 improves 3.04→3.17, camera 3 3.69→3.86, and the final
room 6.85→7.13. However, front doors fall 3.56→2.96, next foyer 4.31→3.83,
and final hallway 3.47→2.95. These runs sample different animation steps;
do not claim a universal speedup. The longest indoor transition remains
9.07 seconds. The successful residual-cost profile below supports adoption.

For the three lower averages, whole-view intervals are much closer than their
active-motion samples: front doors contain 58→60 loop snapshots over 920→939
ticks; next foyer 57→58 over 690→696; final hallway 15→15 over 220→222.
The final-hall active sample changes from seven distinct images in 121 ticks
to six in 122, explaining much of that reported FPS decrease. This does not
prove equal cost at identical poses, but avoids mistaking a changed active
sample for a 15% increase in the duration of the entire hallway passage.

The follow-up profile (`amiga-fixed-copylong-profile.log`, exit zero) covers
250 PAL fields at the late reverse corridor with Carnby. CopyBits falls from
3,567,754 units across 51 calls to 2,638,466 across 58 calls: average inclusive
call cost falls about 35%, and total copying time about 26% despite more calls.
This is an aggregate attribution, not identical-argument per-call timing.
Seven complete publications occur versus six in the preceding profile.
CopyBits now occupies 13.2%, C2P 12.5%, original Mac VBL callbacks 17.4%, and
region expansion 4.0%; categories overlap. Adopt the small bulk-copy change
with the full-buffer evidence above, then investigate remaining large gaps
and machine-memory differences rather than further instruction-level tuning.

An uninterrupted `SONGHARDWARE=1` run reaches natural completion with all
3,736 events and 1,868 music starts, but its first CIA-TOD timestamp capture
is rejected: the counter repeatedly resets and one before/after pair differs
by -255 lines. Counts alone do not validate the hardware clock. The rejected
data is retained locally as `song-hardware-cia-rejected.*`; do not use it for
jitter or latency claims. The pending replacement records the VBI field count
and raster position on both sides of the DMA-enable write, with no debugger
stops during playback. Its checker requires an explicit field length verified
from the emulator core log and distinguishes DMA arming from first-sample or
host audio output.

The corrected field/raster capture completes naturally (`song-hardware.log`,
exit zero) and passes `check_song_hardware.py --field-lines 313`: all 1,868
DMA starts cover 750 intended onset ticks, and the largest before/after
timestamp bracket is one line (0.064 ms). The core log confirms 313-line PAL
fields during playback. The fitted mean logical tick is 16.6933 ms; onset
phase spans 17.629 ms after removing mean-rate drift. Notes intended on the
same tick are armed up to 4.768 ms apart. Intended eight-tick gaps (133.546 ms)
range 119.359–140.991 ms; nine-tick gaps (150.239 ms) range 139.711–160.767 ms.
The roughly one-field variation is consistent with the current 50-field to
60-logical-tick VBI scheduler. All events are present, but tick-level delivery
checks hide this sub-field unevenness. Replace music's display-quantized
scheduling with a dedicated timer and remeasure; this is DMA-arming evidence,
not yet proof of first-sample or host-output timing or audible acceptance.

The opt-in `CIAMUSIC=1` candidate completes an uninterrupted intro using a
resource-allocated CIA-A timer A (`song-hardware-cia.log`, exit zero). Its
field/raster capture contains all 1,868 starts and 750 intended onset ticks.
Comparison with the validated VBI capture preserves every relative intended
onset tick, period, instrument and note. Mean ticks are 16.6667 ms; fitted
onset phase range falls from 17.629 to 0.951 ms. Eight-tick gaps now range
132.639–133.983 ms, and nine-tick gaps 149.279–150.591 ms. The maximum
same-tick spread increases from 4.768 to 5.440 ms. These measure DMA arming,
not first-sample output or audible acceptance.

Voice fidelity remains unresolved: 1,263 physical channel assignments differ.
Comparing note indexes that restart the same channel within one intended tick
finds 155 replacement pairs in the VBI capture versus 156 in the CIA capture;
44 prior pairs disappear and 45 new pairs appear. These affect 108 versus
104 onset groups. Thus the difference is not merely a fixed permutation of
Paula channels, and the exact note-start sequence cannot prove equal sounding
notes, release tails or stereo placement. The existing allocator can steal
the oldest channel when none is free; determine the actual voice lifetimes
and effect interactions before adopting the timer. Resource shutdown and
reallocation, deferred updates, retained PCM fidelity and complete published
frames also require candidate validation. `CIAMUSIC` remains opt-in.

The separate `SONGPROBE=1 CIAMUSIC=1` regression completes naturally with
audio enabled and warp disabled (`music-cia-song.log`, runner exit zero).
`check_song_playback.py --interrupt` matches all 3,736 timed events against
`m2-song-clock-reference.log` and all 25 retained PCM variants (458,974 bytes)
against the original resources, including loop phase and release silence.
Music advances 28 events during 180 game ticks of CPU-only work; the forced
nested-ownership/deferred-release fixture passes, and all deliveries have
zero logical-tick lateness. Effect priority and effect/resource/voice cleanup
pass. The observer verifies CIA-A timer A acquisition and a cleared ownership
indicator after release. This does not yet prove that another client can
reacquire the timer. There are 1,021 steals and no dropped starts; the prior
VBI fixture had 1,008 steals. The documented four-channel oldest-note policy
allows stealing, so validation must explain these differences against that
policy rather than require the previous display-quantized allocation.

The regression's old shared-CIAB-TOD duration diagnostic is invalid in this
run: `maxLines=16776961` is a wrapped negative 255-line interval. Do not use
its total or maximum as an interrupt-cost measurement. Functional assertions
and byte/event comparisons above are independent of that counter. Replace
the duration clock before making further interrupt-cost claims; the separate
uninterrupted field/raster capture remains the valid onset-timing evidence.

Timer lifecycle validation now passes in `music-cia-lifecycle.log` (runner
exit zero), using `SONGPROBE=1 CIAMUSIC=1` and `amiga/song_timer.gdb`.
Before loading the song, the fixture starts and releases the real timer twice.
Each acquisition advances its clock, each release clears ownership and leaves
the clock unchanged over six game ticks, and reacquisition selects the same
timer. Subsequent normal song startup acquires CIA-A timer A again. These are
runtime checks with a read-only observer, not debugger-injected calls.

The complete controlled rendering run with `INTROSKIP=1 FIXEDRNG=1 CIAMUSIC=1`
also finishes naturally (`amiga-fixed-cia.log`, runner exit zero, audio on and
warp off). All 1,233 captured back buffers pass independent pixel and palette
decoding; 1,489 scene batches balance, all 1,247 queued frames are presented,
and all 3,736 music events arrive with zero logical-tick lateness. Carnby is
selected, and the 31 consecutive room/camera groups match the preceding
bulk-copy run in order. The retained core log is `amiga-fixed-cia-core.log`.

| Scene | Previous VBI FPS | CIA FPS |
|---|---:|---:|
| Opening car | 2.85 | 2.91 |
| Near frog | 2.94 | 2.99 |
| Far frog | 2.62 | 2.63 |
| Approach | 7.53 | 7.30 |
| Window | 4.48 | 4.40 |
| Front doors | 2.96 | 3.78 |
| Next foyer | 3.83 | 4.42 |
| Lower hall | 5.91 | 5.63 |
| Stairs visible | 3.41 | 3.41 |
| Foot of stairs | 2.91 | 2.82 |
| Ascending stairs | 6.52 | 6.52 |
| Upper hall, camera 5 | 3.17 | 3.13 |
| Upper hall, camera 3 | 3.86 | 3.76 |
| Landing | 7.02 | 7.14 |
| Late corridor toward | 4.83 | 4.68 |
| Late corridor reverse | 2.26 | 2.48 |
| Late corridor toward again | 4.21 | 3.97 |
| Late corridor reverse again | 3.11 | 3.11 |
| Final hall | 2.95 | 4.04 |
| Next view | 5.04 | 5.43 |
| Final room | 7.13 | 7.09 |

These use the same active-motion metric as earlier tables, not identical-pose
per-call timings. Complete transition spans remain close: mansion entry
9.07→9.08 seconds, ascending stairs→upper hall 6.78→6.83, and first late
reverse→toward corridor 3.32→3.32. There is no broad rendering regression,
but the existing Mac comparison still leaves substantial indoor gaps. CIA
scheduling improves onset spacing; it does not establish overall performance
parity. Voice-allocation explanation and actual output timing remain pending.

A song-only offline replay does not explain the intro's channel assignments:
its first mismatch is note-start index 8 (the ninth note). A targeted read-only
runtime observation (`music-allocation.log`, runner exit zero) establishes
why. Immediately beforehand, channel owners are `{0, 6, 2, -1}`: effect slot
0 owns Paula channel 1, with two effect starts and one stop recorded. The
active effect spans game ticks 3099–3333. Music therefore cannot choose the
model's channel 1; channel 3 is the free channel, as in the hardware capture.
The observer's optimized argument display is invalid and is not used as
evidence; global voice/effect ownership supplies this finding. The earlier
observer with an unreachable conditional breakpoint was stopped and retained
as `music-allocation-rejected.log`, not counted as a passing run.

This explains the first mismatch with the song-only model, not every difference
between VBI and CIA runs. A full allocation comparison must include effect
start/stop times and their priority; treating the intro as music alone gives
false discrepancies. Do not change the allocator to satisfy that model.

The expanded late-corridor profile (`corridor-services.log`, exit zero;
`CORRIDORPROFILE=1 INTROSKIP=1 FIXEDRNG=1 PROBEFIELDS=250`, audio on, warp
off) covers 250 fields and 20,030,443 beam units. Original VBL callbacks
occupy 4,980,580 units across 295 calls; traps entered within those callbacks
occupy 3,179,253 units across 1,601 dispatches, approximately 64% of the
callback bracket. These are inclusive instrumented costs, not shipping FPS.

Shared services total 5,960,170 units. Scene-boundary checks total 2,680,889,
but include completion-time presentation; total presentation is 2,494,397,
including C2P 2,091,002. Do not sum these overlapping categories. Book-boundary
checks, effect service and VBL scheduling respectively total 411,877,
391,515 and 421,741 units over approximately 2,940 calls each. The empty
control bracket itself costs 346,494 units over 2,941 calls, so those small
categories offer little evidence for worthwhile local optimization. Extra
scopes perturb this run; its five publications are not a shipping speed score.

The private sound-driver trap remains substantial: 2,368,836 units across
720 dispatches (the preceding lighter profile measured 1,801,691 across 784).
Current dispatch defers every driver selector to user mode, including read-only
song/effect status and clock queries. Investigate avoiding the extra dispatch
for verified non-OS queries, while preserving return registers/CCR and keeping
allocation, sample mutation and OS calls on their existing safe path. The
original callback itself maintains audio/effect state and invokes game hooks;
removing it is not a behavior-preserving optimization.
