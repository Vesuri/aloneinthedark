# Return-to-attic investigation

The Amiga high-speed failure is reproducible from the owner's Emily save during
an automatic descent. The character turns at the foot of the stairs and returns
to the attic with all four movement keys released. The matching configuration is
A1200, unlimited 68040-NOMMU, 32 MB Zorro III RAM, uaegfx-z3 and official
macOS FS-UAE 3.2.35, with warp off. It is not explained by a held Up key.

## Timing evidence

| Configuration | Result |
| --- | --- |
| Original Mac IIx/68030, fresh descent | Living manual control in floor 1 room 6 |
| Development emulator, native and WHDLoad, supplied save, roughly 20–26 FPS | Remains downstairs |
| Official emulator, owner's configuration, supplied save, uncapped | Reverses and returns upstairs; roughly 2,300–3,100 scene updates per second |
| Same save/configuration, global VBlank pacing, PAL/JIT | Remains downstairs, 50 scene updates per second |
| Same paced test, JIT disabled | Remains downstairs, 50 scene updates per second |
| Same paced test, NTSC/JIT | Remains downstairs, 60 scene updates per second |
| Fresh Carnby route, official PAL/JIT configuration, paced | Reaches stable manual floor 1 room 6 |

The saved-state fixture loads through the original Load interface and observes 32
samples one second apart without movement input or actor-state edits. Its final
five samples must show idle animation 4, floor 1, room 6 and manual mode 1.
The uncapped A/B control fails this check; the paced runs pass. These fully
PRELOAD-cached runs require no WHDLoad OS switches.

This establishes excessive simulation frequency as a trigger and a working
port-side remedy. It does not identify the exact original instruction responsible
for retriggering the return route, or prove equivalence to the Macintosh.js issue.
Do not run or test Macintosh.js. Original game instructions and route decisions
remain unchanged; the owner explicitly authorizes global VBlank pacing.

## Original-code evidence

Original ListTrak entry 31 disables collision/decor interaction, stops, fixes
angles, starts walking, records starting coordinates and runs command 18 toward
(0,0,-2000), then restores collision/decor and ends. (Dark2, $4F06–$508E)
handles this Z-axis movement. At $4F30–$4F46 it tests room Y plus step Y
against target Y ±100; only the in-band branch advances the track at $4F86.
Otherwise it interpolates height from Z progression and steers toward the target.
The proportional helper (Dark3, $0840) uses signed integer multiplication/division.
This is byte evidence, not proof that the failure skips that band.

Actor offsets 82/84/86/88/90/92/94 are track mode, track number, mark, track
position and step X/Y/Z. The ordinary fresh-descent fixture also checks Carnby
and Emily, releases Up at the start of automatic descent and requires three
seconds of continuous idle/manual control downstairs. See [testing.md](testing.md).
