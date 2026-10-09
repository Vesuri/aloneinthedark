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

## Unlimited 68040 with JIT

The owner reports descending and immediately turning back upstairs on
68040-NOMMU with unlimited CPU and JIT enabled, with no attic items collected.
This establishes a reported port symptom; JIT causality and equivalence to the
Macintosh.js report remain unconfirmed.

The fresh Carnby route passes without JIT on unlimited 68040/PAL, reaching
floor 1, room 6, manual mode 1 and idle animation 4 at Z=-1873. The stair
portion measures 215 frames over 599 guest ticks (21.536 FPS). This run used
warp; it does not reproduce the owner's JIT timing. A native ARM-host run
with unlimited 68040, JIT off and warp off also reaches manual room 6 at
Z=-1867 (209 frames / 589 guest ticks through the stair portion).

Use the explicit JIT reproducer:

```sh
AMIGA_CONFIG=a4000-040-jit EXTRA_ARGS=--warp_mode=0 amiga/regression.sh stairs
```

The regression runner preserves an explicit warp setting. The available x86-64 emulator under
Rosetta exits before the game starts with `Caught illegal access to 40001000
at eip=0x40001000` after enabling its 8 MB JIT cache. That failed launch is
not gameplay evidence. A working JIT host and the owner's JIT-off comparison
are still needed. No gameplay or original-code changes have been made.
