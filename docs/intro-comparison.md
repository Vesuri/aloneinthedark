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
