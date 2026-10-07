# Audio regression

Run `AMIGA_CONFIG=a4000-030-reference amiga/regression.sh audio` from the
repository root. `AITD_AUDIO_MAC_DISK` selects a private, writable System 7.5.5
reference disk containing the original game; its current default is the local
`tmp/m4/sysbeep/mac.hd` fixture disk. Original ROMs, extracted resource/data files,
MAME and the Amiga cross toolchain must already be installed as described in
[development](development.md). Original resources and captures remain private.

The runner records a fresh output directory under `tmp/m4/audio-*`, including
revision, working patch, actual process exit statuses, build logs, original
captures and native binary traces. Preferences and saves in the selected
`DIAG_RUN_DIR` (default `.run`) are isolated and restored on success or failure.
A completed run leaves a clean production build. Failed runs retain diagnostics;
a failure never inherits a prior positive completion marker.

The headless checks cover:

- Fresh original and native playback of all eight songs: every event, sequencer
  deadline, original voice state, native allocation, priority effect, interrupt
  progress without main-thread traps, and sample/resource/DMA cleanup.
- Zero/one/three/negative loop counters, active-loop stop and replacement, and
  a 131,073-byte sample with the complete odd tail.
- Two effect slots, oldest-slot/tie replacement, fractional sample pitch and
  actual Paula attack/silent-reload timing,
  duration-1 SysBeep, and ordinary S input stopping an active effect while
  leaving music intact.

To reuse a prior complete set of original song captures, set
`AITD_AUDIO_SONG_REFERENCES=tmp/m4/audio-<previous-run>`. Their recorded statuses,
full voice states and every original event are revalidated against the decoded
resources; all native cases still run anew. This option does not reuse native
PASS records. Omit it to recapture the eight original songs.

The effect and SysBeep checks use the previously measured, retained original
RAM fixtures with their recorded statuses. Prepare those using
`tools/mac_effect_fixture.lua`, `mac_effect_loop_action.lua`,
`mac_effect_slots.lua` and `mac_sysbeep_fixture.lua`, following their contracts
in [sound-driver](sound-driver.md) and the M4 sections of
[development](development.md). Required folders are
`tmp/m4/effects/{loop0,loop1,loop3,loopnegative,action17,action18,long,slots,fraction}`
and `tmp/m4/sysbeep`. The active sound-off and song references are recaptured on
each integrated run. Original guest-RAM fixtures must remain separate from
ordinary-gameplay acceptance.

The runner's final PASS is evidence for these headless contracts. It does not
prove recognizable speaker output, remaining driver-call reachability, or
matching sound-effect events across an ordinary first-floor route. Those
requirements remain tracked in [open work](open-work.md).
