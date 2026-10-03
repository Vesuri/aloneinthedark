# 68030 intro comparison — 2026-10-03

The latest controlled Carnby run reaches 2.86 FPS for the car, 3.36/3.35 for
the near/far frog and 2.76/3.75 for the two late reverse-corridor visits.
The same-character Mac reference reaches 4.36, 4.73/3.80 and 5.84/6.29 FPS
respectively. Most measured scene frame times are now 1.1–1.9 times Mac;
the first late corridor visit remains 2.12 times. Mansion entry is 8.82 seconds
versus 8.05 on Mac. The reverse-to-toward corridor transition remains 3.12
versus 1.58 seconds. No current camera transition reproduces a 15-second gap.
The sections below distinguish the current comparison from the initial baseline
and explain the remaining limits. Overall acceptance, including the remaining
actual-audio-output checks, is still open.

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

The initial baseline native build is commit `8cd8f60` with `INTROSKIP=1`, without
profiling or fixed randomness. The original Mac game is unmodified. Read-only
observers capture original Dark+$5658 loop entries, indexed viewport pixels,
palette and actor records. Normal input gets to the menu; no debugger writes
force a character, route or game timer. The measured section starts with the
menu's unattended demo, excluding the book.

The first Mac run selected Carnby and the Amiga selected Emily. A second Mac
run, with a one-frame change in normal launch-input timing, selected Emily
naturally. **The initial baseline tables compare Emily with Emily.** All three runs reached
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

## Current comparison: same-character Carnby

This is the complete mask-bounds run (`tmp/mask-bounds.log`, exit zero),
compared with `tmp/route-comparison/mac-loops.log`. Both use the same fixed-clock
68030 setups above. The native build uses `INTROSKIP=1 FIXEDRNG=1`, default CIA
music, changed-block conversion and mask-bounds clipping, without broad profiling.
The entire indoor room/camera sequence matches, including setup-only states;
visits are aligned from mansion entry so repeated room/camera numbers are not
confused. Natural actor poses and sample counts differ. Original game instructions
and movement decisions remain unchanged.

| Moving scene | Mac FPS | Current Amiga FPS | Amiga frame time / Mac |
| --- | ---: | ---: | ---: |
| Opening car | 4.36 | 2.86 | 1.52× |
| Near frog | 4.73 | 3.36 | 1.41× |
| Distant frog | 3.80 | 3.35 | 1.13× |
| Entering front doors | 6.02 | 3.77 | 1.60× |
| Entrance hall, next view | 6.14 | 4.98 | 1.23× |
| Lower hallway, first view | 8.89 | 6.70 | 1.33× |
| Lower hallway, stairs visible | 7.30 | 4.17 | 1.75× |
| Foot of stairs | 6.43 | 3.80 | 1.69× |
| Ascending stairs | 10.59 | 6.92 | 1.53× |
| Upper hall, camera 5 | 7.59 | 4.05 | 1.87× |
| Upper hall, camera 3 | 8.84 | 5.04 | 1.75× |
| Upper landing | 11.21 | 7.25 | 1.55× |
| Later corridor, toward camera | 9.31 | 5.91 | 1.58× |
| Later corridor, reverse, first visit | 5.84 | 2.76 | 2.12× |
| Later corridor, toward, second visit | 8.45 | 5.05 | 1.67× |
| Later corridor, reverse, second visit | 6.29 | 3.75 | 1.68× |
| Final hallway, first view | 7.41 | 3.80 | 1.95× |
| Final hallway, next view | 10.34 | 5.65 | 1.83× |
| Final room | 10.98 | 7.31 | 1.50× |

| Complete indoor transition | Mac seconds | Current Amiga seconds |
| --- | ---: | ---: |
| Window view → inside front doors | 8.05 | 8.82 |
| Front doors → next entrance-hall view | 2.05 | 2.82 |
| Entrance hall → lower hallway | 3.73 | 4.60 |
| Lower hallway → stairs visible | 1.73 | 2.10 |
| Stairs visible → foot of stairs | 1.78 | 2.18 |
| Foot of stairs → ascending view | 1.55 | 1.95 |
| Ascending view → upper hall | 6.05 | 6.67 |
| Upper hall camera 5 → camera 3 | 1.78 | 2.53 |
| Upper hall → landing | 4.45 | 4.63 |
| Landing → later corridor | 2.92 | 3.98 |
| Corridor toward camera → reverse | 1.15 | 1.53 |
| Corridor reverse → toward camera | 1.58 | 3.12 |
| Corridor toward camera → reverse again | 1.17 | 1.75 |
| Corridor → final hallway | 1.97 | 2.38 |
| Final hallway camera change | 1.02 | 1.00 |
| Final hallway → final room | 1.07 | 0.98 |

The current car trace visits the same script-offset sequence as Mac, including
all approach/departure waypoints. Its straight approach at word 4 has identical
sampled endpoints and takes 17.85 seconds versus 12.82 on Mac. Turning still
produces different geometric trajectories: the early word-20 residence is
31.17 seconds versus 120.23 on Mac, while word 60 takes 20.30 versus 0.18.
These are first-to-last sampled spans, not exact instruction durations. They
support the existing frame-step/waypoint-overshoot explanation and do not show
an Amiga-only route replacement. Total demo duration remains unsuitable as a
performance score.

Matched polygon captures below attribute the remaining first-use mask gap
to processing the same geometry, rather than different scene inputs. The
row-clipping improvement does not eliminate polygon construction. Shared compatibility services and Amiga display-format
conversion also remain additional work. Do not pursue local tuning merely to
make every short natural sample faster: upper landing and final-room averages
are slightly lower than the immediately preceding run, with unequal motion
samples. The overall scene comparison, rather than total intro duration or one
helper, is the performance evidence.

## Initial baseline: active animation

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

## Initial baseline: camera transitions

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

The direct-query candidate keeps selectors 4 (song status), 15 (clock) and
20 (effect status) in the normal trap handler, while other driver operations
retain user-mode deferral. Selector-specific CCR handling preserves the
measured clock and song-status flags; the assembly return skips its generic
word-sized status calculation for the private driver trap.

`driver-query-clock.log` passes the original-matched seven full-width clock
boundary cases and X/N/Z/V/C checks. `driver-query-live.log` completes with
the unchanged game's clock and active-song callers preserving stack/registers
and returning the expected D0/D1/CCR; the clock check brackets driver state
before callback delivery. Two earlier observer attempts are rejected: one
armed a breakpoint before Core residency, and another still required the old
deferred path. They provide no candidate acceptance evidence.

`driver-query-effect.log` completes 239 observed direct status queries: 238
playing and one finished, with preserved caller registers and complete
effect/DMA/sample cleanup. `check_driver20.py` passes against the original
Mac reference. The native start-effect call remains deferred. Full published
buffer checks and matched-scene speed measurements are still pending in the
`amiga-fixed-query` run; ABI success alone does not justify adoption.

That run now completes naturally (exit zero): all 1,034 captured buffers pass
independent pixel/palette checks, 1,272 scene batches balance, all 1,048 queued
frames are presented, and all 3,736 music events arrive within one VBI-clock
tick. The indoor visit order matches the bulk-copy baseline after aligning
the approach: the new run has three fewer repeated outdoor visits, which
must not be mistaken for missing indoor scenes or a total-duration speedup.

| Scene | Bulk-copy baseline FPS | Direct-query FPS |
|---|---:|---:|
| Opening car | 2.85 | 2.92 |
| Near frog | 2.94 | 3.24 |
| Far frog | 2.62 | 2.95 |
| Approach | 7.53 | 7.92 |
| Window | 4.48 | 4.64 |
| Front doors | 2.96 | 3.76 |
| Next foyer | 3.83 | 5.51 |
| Lower hall | 5.91 | 6.20 |
| Stairs visible | 3.41 | 3.53 |
| Foot of stairs | 2.91 | 2.88 |
| Ascending stairs | 6.52 | 6.58 |
| Upper hall, camera 5 | 3.17 | 3.46 |
| Upper hall, camera 3 | 3.86 | 4.24 |
| Landing | 7.02 | 7.04 |
| Late corridor toward | 4.83 | 4.72 |
| Late corridor reverse | 2.26 | 2.54 |
| Late corridor toward again | 4.21 | 4.46 |
| Late corridor reverse again | 3.11 | 3.19 |
| Final hall | 2.95 | 4.02 |
| Next view | 5.04 | 5.34 |
| Final room | 7.13 | 7.22 |

Active-motion samples differ, so large percentage gains in short views should
not be read as identical-pose speedups. Median active steps in upper hall
camera 3 fall 16→14 ticks; reverse-corridor medians fall 21→20 and 20→19.
Complete transition spans improve slightly: mansion entry 9.07→8.95 seconds,
stairs→upper hall 6.78→6.73 and late reverse→toward 3.32→3.25. Foot-of-stairs
and late-toward averages fall slightly, without a median-step regression.
The overall measured gain and full-frame/ABI checks support keeping direct
queries. Move on to the residual performance gap rather than tuning this
helper further. This run uses the default VBI music scheduler; it does not
validate the combination with the opt-in CIA scheduler.

Combined query/CIA validation now completes in `amiga-fixed-query-cia-retry`
(runner exit zero). All 1,042 captured buffers match pixel-for-pixel and in
palette; 1,267 scene batches balance and all 1,056 queued frames are presented.
All 3,736 music events arrive with zero logical-tick lateness. The audio trace
contains 1,868 note starts and 256 effect transitions, with neither trace
overflowing. The first combined run reached the final scene but failed its
audio-capture guard and remains rejected. Its observer omitted the specific
counters; the retry's 256 transitions exceed the initial 64-entry capacity,
supporting a capacity explanation without proving the missing original counts.

`check_song_allocation.py` replays the original Mac event sequence using
captured note service/release clocks and effect ownership, with pitch and
non-looping sample durations derived from original resources. All 1,868
channel assignments and the aggregate 1,160 steals follow the documented
four-channel oldest-note policy. An immediate effect replacement retains its
channel: the trace captures paired stop/start transitions but not replacement
intent separately, so that part establishes policy consistency rather than
unique intent. A synthetic effect/release fixture passes, and corrupting a
note to take an effect-owned channel is rejected. This resolves the false
discrepancies of the earlier song-only model; it does not prove analog output
or exact audible voice tails.

Combined car and near/far frog rates are 2.80 and 3.16/2.96 FPS, versus
2.92 and 3.24/2.95 for the query-only run. Late corridor toward/reverse/toward/
reverse rates are 4.78/2.54/3.95/3.10 versus 4.72/2.54/4.46/3.19. Final hall,
next view and final room are 3.12/5.48/7.14 versus 4.02/5.34/7.22. These are
different active-motion samples, with two additional outdoor revisits in the
combined run; do not infer unchanged performance in every view from the
matching first reverse-corridor average. The combined capture contains debugger
frame stops, so its audio timestamps must not replace the separate uninterrupted
onset-jitter measurement. Keep CIA opt-in pending that combined timing check.

Examining the two lower averages more closely: the second toward-corridor
visit spans 259 ticks with query-only scheduling and 276 with CIA (6.6% longer),
with 17 loop snapshots in each. Its first loop grows from 61 to 66 ticks;
the median active interval remains 11 ticks, while the maximum grows from
30 to 34. The final-hall visit instead shrinks from 241 to 203 ticks,
with 18 versus 14 snapshots. Its active sample contains 11 versus five
changed images, and median intervals are 15 versus 16 ticks. Thus its lower
FPS does not mean the whole passage takes longer. Neither view contains an
exact matching person step when matching start/end position, angle, animation
and track. These observations explain the limited comparability of the short
averages but do not establish identical-pose costs or dismiss the modest
toward-corridor slowdown. Avoid repeated full runs to tune these small samples;
use a fresh residual-cost profile for the substantial remaining indoor gap.

The combined uninterrupted run (`tmp/query-cia-uninterrupted.log`, exit zero)
now reaches the original completion endpoint without playback breakpoints.
It records all 3,736 events, 1,868 DMA starts and 258 effect transitions without
overflow or logical lateness. The independent allocation replay agrees with
every channel assignment and all 1,141 steals. Against the original event
reference and retained VBI DMA capture, note identities, pitches and intended
onsets agree. With the core's 313-line PAL field, the measured mean tick is
16.6667 ms and fitted onset phase range is 0.855 ms (VBI: 17.629 ms).
Eight-tick gaps range from 132.639 to 134.047 ms; nine-tick gaps from
149.343 to 150.623 ms. The maximum spread within a chord is 5.504 ms.
This closes the combined uninterrupted scheduling check, not actual
first-sample latency, audible release tails or host-output fidelity. CIA
remains opt-in while those audio checks remain open.

The post-query CIA corridor profile (`tmp/corridor-query-cia.log`, exit zero,
`CORRIDORPROFILE=1 INTROSKIP=1 FIXEDRNG=1 CIAMUSIC=1 PROBEFIELDS=250`)
reaches the late room 1/camera 2 after the upper landing with Carnby.
Its 250 fields contain six publications and 19,993,157 beam units:

| Inclusive phase | Beam units | Share of interval |
| --- | ---: | ---: |
| Presentation | 2,508,377 | 12.5% |
| Chunky-to-planar conversion, within presentation | 2,090,660 | 10.5% |
| Back-buffer synchronization, within presentation | 45,751 | 0.2% |
| CopyBits | 2,208,546 | 11.0% |
| Shared trap services, including presentation | 5,951,560 | 29.8% |
| Original Mac VBL callbacks | 3,998,739 | 20.0% |
| Compatibility traps within those callbacks | 2,684,923 | 13.4% |
| Heap lookup | 900,317 | 4.5% |
| Region expansion | 654,411 | 3.3% |

Categories overlap and instrumentation perturbs the interval; do not sum these
shares or quote six frames per five seconds as shipping performance. The
empty control bracket alone totals 316,041 units over 2,669 dispatches.
Private sound-driver dispatch now totals 1,636,531 units over 367 calls,
versus 2,368,836 over 720 in the earlier service profile, with different
scene samples and scheduler. GetZone/SetZone together account for 1,966,715
inclusive units over 897 calls; their shared service/profiler work is included,
so this does not justify treating the constant-time zone access itself as
a bottleneck. Presentation synchronization is no longer a substantial cost.
The remaining gap requires separating original drawing from compatibility
work in matched indoor steps, rather than another heap cache, region tweak
or speculative rewrite of these small services.

Read-only original drawing checkpoints now separate the person model from the
rest of that corridor step (`tools/mac_corridor_phases.lua`,
`amiga/corridor_phases.gdb`, checked by `tools/check_corridor_phases.py`).
Both natural runs exit zero; the native build uses `INTROSKIP=1 FIXEDRNG=1
CIAMUSIC=1` without the broad profiler. Captures are under
`tmp/corridor-phases/{mac,amiga}` with their corresponding logs. The initial
native observer failed because breakpoint command lists inside its continue
loop did not dispatch as expected; `rejected-amiga*` is retained and excluded.
The corrected observer handles each stopped PC explicitly.

| Person-render stage, in 60 Hz game ticks | Mac: 27 calls, min/median/max | Amiga: 20 calls, min/median/max |
| --- | ---: | ---: |
| Original model call, Dark+$3ED4→+$3EDA | 3 / 4 / 5 | 3 / 4 / 5 |
| Model setup through sorted surfaces | 2 / 3 / 3 | 1 / 1 / 3 |
| Drawing the sorted surface list | 1 / 1 / 2 | 1 / 2 / 4 |

Seven model-geometry keys are shared, covering 12 native calls, after excluding
the model's ten-byte runtime header. No complete geometry-plus-transform key
matches: these are natural same-view samples, not identical-pose timings.
Their interval medians nevertheless localize the major remaining question:
loop-to-loop is 10 ticks on Mac versus 20 on Amiga, while the person model
call itself has the same four-tick median. The Mac trace also shows another
model draw after the person. Post-person work is normally about 3 ticks on
Mac versus 5–6 on Amiga; later in the visit it grows to about 5 versus 16–17.
Both runs include a larger isolated post-person interval (20 versus 50 ticks),
without proving these are identical events. Investigate complete scene work
before and after the person—including other actors, background restoration,
masking, copying and compatibility calls—rather than attributing the whole
frame gap to the person model renderer or CPU frequency.

CIA music scheduling is now the default (`CIAMUSIC=0` preserves the old VBI
diagnostic path). Adoption is supported by the complete combined uninterrupted
timing and allocation checks above, exact original event/PCM checks, successful
timer stop/reacquisition and the full combined frame comparison. It does not
claim unmeasured analog/host fidelity or exact first-sample and release-tail
timing; those remain open. The earlier opt-in statements describe the trial
stage, not the current ordinary build.

The complete scene-stage comparison now succeeds on both machines
(`tmp/corridor-scene/{mac,amiga}.log`, both exit zero). The native observer
was reduced after its first attempt filled the emulator's breakpoint table;
`rejected-amiga*` is excluded. Reproduce with `tools/mac_corridor_scene.lua`
and `amiga/corridor_scene.gdb`, then run `tools/check_corridor_scene.py`
with `mac` or `amiga` and the recorded `--status`. The native build has
`INTROSKIP=1 FIXEDRNG=1` and default CIA scheduling, without broad profiling.

| Interval, median game ticks | Mac, 27 steps | Amiga, 20 steps |
| --- | ---: | ---: |
| Previous loop entry to scene-renderer entry | 2 | 8 |
| Scene entry through background restoration | 1 | 2 |
| Actor processing, including drawing and masks | 6 | 6 |
| Overlays/copies after actors through scene exit | 2 | 3 |
| Scene exit through next loop entry | 0 | 0 |
| Whole loop interval | 10 | 20 |

Individual medians do not sum to the median whole interval. All intervals
include callbacks and compatibility work occurring inside them; they are not
exclusive CPU categories. The two actually drawn objects are Carnby (288,
body 265) and object 56 (body 57). Their model-call medians are respectively
four and one tick on both machines. The largest persistent difference is
therefore before scene rendering starts. That interval also includes any
deferred presentation at early trap boundaries, so do not label all eight
ticks as original game logic without further separation.

Masking accounts for the late-visit spike: Carnby's first expensive mask call
takes 16 Mac ticks versus 43 native ticks, followed by about 2 versus 9–11
ticks on subsequent steps. The different natural transforms prevent a claim
of identical mask inputs, but identify the specific work to compare next.
Prioritize the pre-render interval and this foreground-mask path; another
person-renderer optimization would miss the measured gap.

The focused native update trace (`tmp/corridor-update/amiga.log`, natural
completion and runner exit zero) narrows the pre-render interval further.
Across 21 complete samples, loop entry through the first GetGWorld return
(Dark+$56C8) has a six-tick median. Input completion, the pre-actor hook,
actor reset, motion and life stages each have a zero-tick median; visibility
through scene entry has a one-tick median. These tick-granularity results
support targeting deferred presentation rather than rewriting original logic.
The earlier C2P profile corresponds to about 87 ms per submitted frame, although
its six heavily observed frames must not be used as ordinary intro FPS.

All 89 masked CopyBits samples in the same run have matching source/destination
palette seeds (2/2), ruling out repeated palette remapping for those calls.
Their rounded durations sum to 44 game ticks, with a zero-tick median and
two-tick maximum. This does not yet explain the full foreground-mask interval.

The 20 native corridor framebuffer captures from `tmp/corridor-phases/amiga`
contain only 260 changed 32-pixel blocks at the median between successive
images, out of 2,000 blocks (13%). An exact-byte Fast RAM cache and row masks
now suppress redundant C2P work. Host checks cover sparse,
reverting and unchanged pixels, alternating planar buffers and odd viewport
moves. The clean `INTROSKIP=1 FIXEDRNG=1` build passes both link audits.

The full native run (`tmp/changed-blocks.log`, runner exit zero, audio on,
warp off, unchanged 15.6672 MHz 68030 setup) passes
`tools/check_scene_batches.py` against
`tmp/route-comparison/amiga-changed-blocks`: all 1,062 captured buffers match
all 64,000 pixel indices and all palette entries, 1,321 scene batches balance,
and all 1,076 queued frames are displayed. All 3,736 music events complete
with zero recorded logical lateness and zero late publications. This capture
run is not a new uninterrupted audio-jitter measurement.

| Naturally moving view, visible FPS | Previous default CIA build | Changed-block conversion |
| --- | ---: | ---: |
| Initial car | 2.80 | 2.84 |
| First frog view | 3.16 | 3.18 |
| Close frog view | 2.96 | 3.35 |
| Room 5, camera 0, person | 2.88 | 3.37 |
| Room 2, camera 3, person | 4.15 | 4.29 |
| Room 7, camera 1, person | 6.93 | 7.39 |
| Late corridor 1/2, first visit | 2.54 | 2.74 |
| Late corridor 1/2, second visit | 3.10 | 3.53 |

Metrics use the existing changed-image/visible-moving-actor method, excluding
the first loop. Logs, captures and metrics are under `tmp/route-comparison`
with prefixes `amiga-fixed-query-cia-retry` and `amiga-changed-blocks`.
Natural poses and numbers of samples differ; these are same-view comparisons,
not exact-pose benchmarks. Late-corridor moving-interval medians fall from
20 to 18 ticks and 19 to 16 ticks. The gain is useful but modest, leaving
roughly 1.8–2.1 times the Mac frame time. This does not establish improved
scene-transition latency or resolve the foreground-mask bottleneck. Retain
the verified change and prioritize that larger residual cost rather than
further tuning block comparisons.

The subsequent mask-stage run (`tmp/corridor-mask/amiga.log`, natural runner
exit zero, unchanged changed-block build) brackets 40 complete calls across
20 corridor steps. Its analysis explicitly excludes 169 later internal stage
hits outside those bracketed scene-mask calls, after the scene starts changing.
Within the complete calls, 88 CopyBits intervals total 41 game ticks, 22
FramePoly intervals total 16 ticks, and 22 InsetRgn intervals total 22 ticks.
Polygon setup through FramePoly entry totals another 12 ticks. The large first
Carnby mask call remains 43 ticks and builds 14 polygons; later calls take
8–10 ticks and each build one polygon. Tick rounding and callback/observer
cost remain included, so these are measured intervals rather than exclusive
instruction costs.

Inspection of the earlier 89 saved mask/rectangle pairs finds 48 empty bounding
intersections and 51 calls with no actual output pixels. Their destination
rectangles cover 15,049 rows before the mask bounds are considered, versus
4,265 rows after intersection. CopyBits previously walked the larger range.
The candidate now validates the region, intersects its destination-coordinate
bounds, then walks only the remaining rows. Host checks cover disjoint and
partly clipped irregular masks and malformed-input atomicity. All 89 captured
geometries also pass against independently decoded full 64,000-pixel expected
results. The full native run exits zero and passes `tools/check_scene_batches.py`:
all 1,117 captured buffers match every pixel and palette entry, 1,380 scene
batches balance, all 1,131 queued frames are displayed, and all 3,736 music
events complete with zero recorded logical lateness and late publications.
Evidence is under `tmp/mask-bounds*` and
`tmp/route-comparison/amiga-mask-bounds`. The current comparison above reports
the complete measured result; retain this clipping change.


The paired cold-mask comparison now passes on the original Mac as well
(`tmp/corridor-mask/mac.log`, runner exit zero). Reproduce with
`tools/mac_corridor_mask.lua` and `amiga/corridor_mask.gdb`, then run
`tools/check_corridor_masks.py tmp/corridor-mask --mac-status 0 --amiga-status 0`.
The saved native trace predates the mask-bounds fix; the tracked native observer
now limits internal-stage reporting to bracketed scene-mask calls. The checker
explicitly excludes the saved trace's 169 later unbracketed stages.

All 16 unique polygon inputs match exactly, and every expanded output region
is byte-for-byte identical across the two machines. The expensive cold call
builds the same ordered set of 14 polygons on both machines. This strengthens
the earlier same-view comparison: its construction inputs and outputs really
match even though the moving actor poses do not.

| Matched cold call component, game ticks | Mac | Amiga before mask-bounds clipping |
| --- | ---: | ---: |
| Polygon setup through FramePoly entry | 1 | 8 |
| FramePoly conversion | 1 | 9 |
| CloseRgn | 3 | 1 |
| InsetRgn expansion | 11 | 13 |
| Expanded region through copy entry | 0 | 2 |
| Masked CopyBits | 0 | 10 |
| Entire cold call | 16 | 43 |

These are adjacent checkpoint totals for one matched cold call; they include
callbacks and observation costs, and zero ticks means below clock resolution.
The 27-tick excess is primarily setup/conversion and copying, not region
expansion. The accepted mask-bounds change addresses unnecessary row traversal;
its complete current-run gains and limits are reported above. The remaining
first-use polygon work explains a bounded subsecond part of the residual gap,
not an unexplained multi-second stall. Do not launch another expansion rewrite
or micro-optimize warmed model drawing on the basis of these results.


Actual emulator-output evidence is now available from the current masked-copy
build. `tools/capture_fsuae_audio.c` intercepts only FS-UAE's SDL2 playback
callback, calls the original producer, and copies its unchanged PCM into a
shared mapping. It records no microphone or other application audio. The
installed emulator is x86-64; the library is built for that architecture.
A deterministic SDL dummy-device fixture verified every captured byte and
retention after forced process termination. This is capture infrastructure,
not a change to native music playback.

The complete `INTROSKIP=1 FIXEDRNG=1 SONGHARDWARE=1` run uses default CIA
scheduling, audible output and warp off, with no debugger stops during the
intro. `tmp/audio-output/intro.log` exits zero. Hardware and allocation checkers
pass all 1,868 original note starts, 248 effect transitions and 1,162 modeled
steals, with zero logical lateness. Hardware onset phase range is 0.875 ms,
and maximum same-tick chord spread is 5.824 ms. The four-channel allocation
limitations still apply; matching starts alone does not prove voice tails.

`tools/check_sdl_audio_capture.py tmp/audio-output/intro.capture` validates
31,238 contiguous callbacks, 63,975,424 committed PCM bytes and zero overflow:
362.672472 seconds of 44.1 kHz, 16-bit stereo. Host callback gaps have median
11.613 ms, p99 11.704 ms and maximum 15.575 ms. The exported WAV is
`tmp/audio-output/intro.wav`. These measurements establish PCM supplied to SDL,
not physical speaker output or a complete musical onset/release comparison.
Silence in the waveform must be compared against actual note/effect lifetimes
before labeling it a dropout. That analysis remains open. The ordinary
`INTROSKIP=1 FIXEDRNG=1` build was restored after this first capture.

An idle-host repeat, `tmp/audio-output/idle.log` (runner exit zero), avoids
concurrent analysis while playback runs. Its capture checker passes 29,785
contiguous callbacks, 60,999,680 PCM bytes, 345.803175 seconds and zero overflow.
Callback gaps are median 11.611 ms, p99 11.699 ms and maximum 13.016 ms.
Hardware checks pass all 1,868 starts and 3,736 events: mean tick 16.6667 ms,
fitted onset phase range 0.948 ms, maximum same-tick spread 5.888 ms and zero
logical lateness. Allocation replay passes 250 effect transitions and 1,175
policy-predicted steals. Different total run length is not a performance metric
because the outdoor route remains timing-sensitive.

Exploratory waveform alignment finds output delay increases in the first
capture near audio times 99.7 and 189.1 seconds. Those interruptions disappear
in the idle-host repeat, but a smaller one occurs near 164.5 seconds. Thus
concurrent host analysis does not explain the whole symptom. In the repeat,
twelve all-zero stereo intervals of at least 44 samples between 164.5 and
164.75 seconds total 44.354 ms; every interval ends at sample index modulo
512 equal to 44. The capture uses 512-frame callbacks. This is strong evidence
of output-buffer behavior, but not yet a direct underrun measurement. The
exploratory mixed-envelope model also finds a persistent timing offset after
this burst; its release model is not yet a checked acceptance oracle.

Nearby FS-UAE source implements zero-fill on underrun and a roughly one-field
audio target, but that checkout uses SDL3 while the installed x86-64 emulator
uses SDL2. Do not claim that source proves the installed implementation or
change game timing based on it. The installed binary contains the `log_audio`
option; trace-level buffer evidence is the next investigation. The repeat
leaves the diagnostic `INTROSKIP=1 FIXEDRNG=1 SONGHARDWARE=1` build in place;
restore the ordinary build after the remaining captures. Audio-output and
release-tail acceptance remain open.

The next installed-emulator trace (`tmp/audio-output/trace-core.log`,
`--log_audio=5`) directly reports the audio queue before each callback.
The uninterrupted runner exits zero. Capture validation passes 31,521
callbacks, 64,555,008 bytes and 365.958095 seconds, with zero overflow;
maximum host callback spacing is 12.598 ms. Hardware timing remains steady:
1,868 starts, fitted phase range 0.952 ms, same-tick spread 5.504 ms and zero
logical lateness. Allocation replay passes 252 effect transitions and 1,160
predicted steals.

The first post-startup burst provides direct corroboration of starvation:
at audio times 67.205125, 67.226848 and 67.235102 seconds, captured callback
indices 5788, 5790 and 5791 report only 6, 5 and 1 ms queued respectively,
against 512/44100 = 11.610 ms requested. Their PCM has all-zero runs of
6.032, 7.528 and 10.884 ms, ending 44 samples into the following callback.
All twenty callback-aligned silent intervals identified between 67.2 and
67.91 seconds coincide with queue levels of 1–11 ms. This establishes output
buffer starvation in the installed emulator while emulated note timing stays
steady. Trace logging can perturb host performance; use the previous untraced
captures to establish that the symptom also exists without verbose logging.
Do not label every silent passage an underrun: some later callback-aligned
silences have ample queued audio. The log ends mid-line after 31,503 callback
records because runner cleanup kills the emulator; exclude its unlogged tail.
The supported buffering remedy and musical release-tail verification remain
open; no native scheduling change is justified by this evidence.

The local FS-UAE repository also retains the SDL2 branch at
`bfa0c7522c6c5f73cceb340d677491d056febd01` (`origin/fs-uae-4`). Its
`fsemu/src/fsemu-sdlaudio.c` uses the observed SDL2 callback API, fills the
unavailable suffix with zeros, and sets `add_silence=1` on shortage.
`fsemu/src/fsemu-audiobuffer.c` then inserts one millisecond of silence before
the next generated samples. At 44.1 kHz this is 44 stereo frames, explaining
the observed silence ending at callback offset 44; it is inserted silence,
not evidence of a fade-in ramp. This branch's latency target is hard-coded to
one video frame and has no buffer-target option in that function. The installed
binary's exact build revision remains unknown, so this is corroborating source
evidence alongside the installed trace, not a binary-identical source claim.
No supported larger-buffer setting has been established; changing that target
would require an emulator-side change rather than a game scheduler fix.

`tools/check_song_release_gaps.py tmp/audio-output/idle
tmp/m2-song-clock-reference.log --origin 55.0095238095` now checks four
exposed five-tick note-release deadlines against the actual stereo PCM. It
derives each NoteOff from the original event sequence, uses captured event
ticks for the deadline and beam timestamps for the next attack, then compares
the intervening all-zero PCM duration. The independent first-note alignment
only selects the nearby gap; a constant output latency cancels in its duration.

| Last voice note index | Expected rest ms | Recorded rest ms | Difference ms |
| --- | ---: | ---: | ---: |
| 408 | 500.048 | 500.726 | +0.677 |
| 1130 | 99.929 | 99.909 | −0.020 |
| 1265 | 99.943 | 100.454 | +0.510 |
| 1344 | 516.722 | 517.370 | +0.648 |

All four pass a 2 ms tolerance and precede the idle-host output-starvation
burst. The complete ownership checker separately passes for this capture.
These rests verify exposed release cutoffs and following attacks; they do not
prove every tail obscured by another voice, stereo equivalence, or correction
of host buffering. The normal `INTROSKIP=1 FIXEDRNG=1` runtime is restored
after these captures. Its clean build exits zero with no-float and 98-symbol
probe audits passing (`tmp/audio-output/restore-build.log`).
