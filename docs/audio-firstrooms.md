# First-room audio evidence

`tools/mac_audio_firstfloor.lua` attaches a read-only MDRV observer to the
ordinary first-floor route. Set `AITD_CIRCUIT_STOP_AT_ROOM5=1` and
`AITD_CIRCUIT_DIR` to a fresh existing capture folder. It stops after the
published room-5 entrance; it does not claim combat or ten-minute acceptance.
The observer records every reached selector and effect packet's size, 16.16
rate, loop range, ID and FNV-1a checksum of unsigned source PCM. It does not
write original RAM, instructions or registers.

Build the native route with `ROOM5COMBAT=1 INTROSKIP=1` and run
`amiga/audio_firstrooms.gdb` on `a4000-030-reference`. The combat build flag
selects the measured stricter heading for the shared approach; the observer
exits before combat, at exploration stage 52. It records genuine effect
requests and dumps their source PCM into `tmp/m4/gameplay/native/`. Create
that directory and `tmp/m3-explore` before launching. Preserve the native log
and the `tmp/m3-explore` captures before another route overwrites them.

The original menu controller waits for the inventory and selected item to
appear. It releases Return when Use executes, then separately waits for the
restored room and measured message ink. The original paints the scene
progressively: an early snapshot can contain gameplay across only its top rows
while the rest still contains the menu. Holding Return until rendering ends
can reopen the menu. The full checker still verifies the exact feedback glyphs,
colour and position after these input/publication guards.

The 2026-10-07 paired route passes `tools/check_south_rooms.py`, including its
lamp, stairs and hallway checks. Accepted local captures are
`tmp/m4/gameplay/mac-complete-frame` (original status 0),
`tmp/m4/gameplay/native` (native status 0) and
`tmp/m4/gameplay/paired/check.log`. Earlier menu/partial-frame and combat-failed
captures are diagnostic only.

The follow-up captures `tmp/m4/gameplay/mac-trigger` and `native-trigger`
include all 50 actors at each sound request. The paired route passes again in
`trigger-paired/check.log`. `tools/check_firstroom_audio.py` verifies the exact
PCM checksum, size, rate, loops and packet ID against the original animation or
door-object trigger. Its acceptance is **movement and door events**, not the
remaining random ambient playback.

Both sides produce the same ten stair events in order and the same two door
sounds from object/life pairs 24/27 and 31/38. Every native footstep has the
original life/animation/frame trigger with END_FRAME set. The Mac records 42
steps; native records 45. The three extra native steps occur at `(4116,-3917)`
near the lamp approach stop, `(7200,4040)` before turning toward the stairs, and
`(2647,-376)` at the hallway approach stop. These are additional completed
animation steps along the controllers' slightly different routes, not
extra requests at an identical trigger. The earlier native one-step deficit
does not recur. Whole-route counts are therefore not a playback parity test.

The earlier native-only PCM checksums map exactly to original LISTSAMP entries
58 (`E237BE27`, 27,115 bytes) and 59 (`235E2009`, 21,157 bytes); the original-only
`F09B4483` maps to entry 61 (10,806 bytes). The local original archive decoder
and byte-identical captures establish these identities; no original samples
are committed. Original life scripts 528/529 contain a `random(300)` switch
whose cases 0, 1 and 2 select those three samples. Both sides' captured actor
arrays contain the corresponding bodyless ambient objects 278/279 with life
528/529. Different random selections explain the unmatched ambient requests.
The reference script interpretation is corroborated by the local FITD life
interpreter; fresh captures must still pair actual playback of these ambient
events before accepting the entire first-room sound requirement.

The sample and script analysis is retained under `tmp/m4/gameplay/analysis`.
The maintained checker validates complete actor captures and rejects unknown
sound identities. Ambient events remain explicitly outside its parity claim.

This route reaches no new unsupported driver selector. It is bounded coverage,
not proof that the remaining static wrappers are unreachable in the whole game.
