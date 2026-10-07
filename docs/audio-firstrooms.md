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

Audio parity is **not yet accepted**. From the original initial-attic checkpoint,
seven packet identities also appear on native: source checksums `171F8B11`,
`53D73494`, `4873D55C`, `B3655384`, `2C00645F`, `8767831D`, `1A9EDE1F`.
Their sizes, rates and loop bounds match. Counts are respectively
4/4, 11/11, 15/14, 2/2, 5/5, 5/5 and 2/2 (original/native).
The native interval also includes two `235E2009` requests and one `E237BE27`;
the latest original interval includes `F09B4483`. Original runs themselves
vary around this startup interval. Align their startup state, timing and sound
triggers before interpreting these differences or changing playback.

This route reaches no new unsupported driver selector. It is bounded coverage,
not proof that the remaining static wrappers are unreachable in the whole game.
