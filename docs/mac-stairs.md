# Return-to-attic investigation

This is supporting evidence for MAC.1 in [open work](open-work.md), not a resolved
cause. The issue report does not establish an emulator defect, and Macintosh.js must not
be run or tested for this investigation.

Ordinary original Mac IIx/68030 descent succeeds using `mac_attic_stairs.lua`, reaching
living manual control in floor 1 room 6. Native descent passes the sixteen CPU/video
configurations in the maintained stairs fixture. These passing baselines do not rule out
the reported item-collection or timing preconditions.

Original ListTrak entry 31 disables collision/decor interaction, stops, fixes angles,
starts walking, records starting coordinates and runs command 18 toward (0,0,-2000),
then restores collision/decor and ends. Original Dark2+$4F06–$508E handles this Z-axis
movement. At $4F30–$4F46 it tests room Y plus step Y against target Y ±100; only the
in-band branch advances the track at $4F86. Otherwise it interpolates height from Z
progression and steers toward the target. The proportional helper at Dark3+$0840 uses
signed integer multiplication/division. This is byte evidence, not proof that the
failure skips that band.

The passing reference trace starts at Y=-1900/Z=2500 and ends at Y=0/Z=-2023, heading
zero, idle animation 4 and manual mode 1. Actor offsets 86–94 are mark, track position,
step X/Y/Z. Use `register_frame_done` for per-field observation and record the actual
input/state preconditions. Retained local baseline data is under `tmp/mac1/reference/`.
No game instructions or actor fields changed in that run; no gameplay fix or global cap
has been introduced.
