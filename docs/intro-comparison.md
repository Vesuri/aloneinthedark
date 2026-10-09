# Intro performance reference

The retained fixed-clock comparison uses MAME Mac IIx/68030 and FS-UAE
`a4000-030-reference`, both at 15.6672 MHz with 8 MB RAM/Fast RAM. Amiga audio is on and
warp off. The native measurement is the mask-bounds implementation at `cbf61a4`, with
`INTROSKIP=1 FIXEDRNG=1`; later gameplay optimizations are not retroactively included in
these numbers. Both runs select Carnby.

These results are a baseline for future regressions, not a current-hardware benchmark.
Matching CPU clocks does not make emulator memory timing identical. Rates count distinct
completed viewport images during visible actor movement, excluding the first loop of
each camera visit. Transitions run from the last old-view loop to the first completed
new-view loop, including setup-only camera states. They are not exact measurements of
black pixels on the display.

## Scene and transition measurements

| Moving scene | Mac FPS | Amiga FPS | Amiga frame time / Mac |
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

| Complete indoor transition | Mac seconds | Amiga seconds |
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

Most scene frame times are 1.1–1.9 times the Mac result; the first late reverse corridor
is 2.12 times, with measured cold polygon-mask construction cost. None of these
camera-transition measurements reproduces a 15-second gap. Keep first-use resource
preparation separate from steady rendering profiles.

## Scenes, route and randomness

Both runs show the wide pond, car/frog, distant frog, gate, mansion exterior, window
approach, front doors, halls, staircase, landing, corridors and final room. Their
ordered 22 indoor room/camera states match, including setup-only states. A full-screen
frog bitmap was not observed in these idle-demo runs; that does not establish its
absence from every original route.

The car follows the same script-offset progression and straight-approach endpoints. Its
geometric turning path differs. Original movement has a 400-unit waypoint threshold and
turns of 64 angle units over 15 ticks (Dark2+$4C6C/$4C7A/$4CD2). Different frame
intervals can overshoot a waypoint and produce circling on either machine. Character
choice and random/timing state also vary between natural runs. Total intro duration is
therefore not a useful speed score. Do not replace the route to make elapsed durations
match.

## Presentation and audio interpretation

The captured native frames pass independent planar/palette decoding and complete
scene-batch publication checks. That validates this measured path, not every possible
game state. Match original logical pixels before waiting for the corresponding native
VBI publication.

The captured silent gaps correlate with the emulator's host output queue running short
of PCM after Paula emulation. They are not evidence that the port failed to schedule a
note. Native DMA timing and voice ownership have separate checks. An emulator queue fix
was not established by those captures. Four-channel Paula allocation also differs
intentionally from the original Mac mixer; audio comparisons use events, pitch and
lifetime, not identical PCM.

## Reproduction

Use the pinned configuration in [development.md](development.md), the maintained `intro`
regression in [testing.md](testing.md), and original state-paired framebuffer capture in
[mac-reference-loop.md](mac-reference-loop.md). Record actor identity/pose, room/camera
visit, guest tick and completed frame. The retained baseline captures are local under
`tmp/route-comparison/` and `tmp/mask-bounds*`; historical observer experiments and
intermediate results can be recovered from Git history.
