# Music resource coverage

The original resource fork contains eight songs. `tools/survey_song_resources.py`
runs the existing SONG/MIDI/INST/sample decoder and PCM preparation oracle for
each song under AddressSanitizer and UndefinedBehaviorSanitizer. The 2026-10-06
survey passes all eight; full output, runner statuses and resource/log hashes
are retained in `tmp/m4-song-resource-survey/`. This establishes host format
coverage only. It does not establish original-driver event fidelity, actual
polyphony, interrupt timing or recognisable native playback.

| SONG | Name | MIDI | Note events | MIDI ticks | Instruments | Samples |
| ---: | --- | ---: | ---: | ---: | ---: | ---: |
| 130 | BDISK1 | 900 | 3364 | 226080 | 3 | 15 |
| 131 | BDISK2 | 901 | 1338 | 105120 | 2 | 9 |
| 132 | FIGHT | 902 | 1206 | 55680 | 8 | 24 |
| 133 | GDISK | 903 | 5098 | 290880 | 3 | 16 |
| 134 | H_END | 904 | 1948 | 80640 | 8 | 14 |
| 135 | INTRO1 | 905 | 3736 | 128640 | 7 | 28 |
| 136 | MONSTER | 906 | 602 | 13440 | 6 | 21 |
| 137 | SUSPENSE | 907 | 2250 | 82560 | 7 | 25 |

MIDI ticks are file time units, not milliseconds or emulated clock ticks.
Instrument/sample counts are unique referenced resources; they are not the
number of simultaneous voices.

The native runtime currently admits SONG 131, 132, 135, 136 and 137. BDISK1
(130), GDISK (133) and H_END (134) remain `SONG UNMEASURED` until their actual
original driver paths are measured and native event comparisons pass.
The successful host survey does not relax that guard.

Reproduce from an extracted, unchanged original resource fork:

```sh
python3 tools/survey_song_resources.py
```

Use `--resource` for another extraction and `--output` for a separate private
evidence directory. No original music resources or captures are committed.
The remaining playback and voice-allocation acceptance is tracked in
[open work](open-work.md).


## Original live voices and native allocation — 2026-10-07

Ordinary ADB input starts the natural attic songs and leaves the action menu
open. The observer reads every original note handler and all six voice slots;
it never writes guest memory or registers. Complete captures establish:

| Song | Live events | Peak held notes | First peak event | Original full-voice drops |
| --- | ---: | ---: | ---: | ---: |
| FIGHT (132) | 1206 | 6 | 526 | 0 |
| MONSTER (136) | 602 | 6 | 6 | 0 |
| SUSPENSE (137) | 2250 | 6 | 56 | 13 |

Held-note counts exclude release tails. All note identities and sample pitch,
extent, loop and note-off states match the original resources. These counts
come from full live original playback, not merely MIDI overlap analysis.

Fixed 68030 native fixtures match every original note identity/order and
verified sequencer deadline, including three seconds without a main-thread
trap, a priority effect interrupting four occupied music channels, and complete
sample/resource/heap/DMA cleanup. Independent channel-policy replay predicts
all 148 FIGHT, 183 MONSTER and 427 SUSPENSE steals, including the priority effect.
The policy starts every note, first reusing a matching voice when INST $0400
requests retrigger, otherwise taking a free channel or stealing the oldest
music voice; original six-voice drops are therefore documented differences.
These headless tests do not establish analog output or listening quality.

Use `tools/mac_song_live_gameplay.lua` with `AITD_LIVE_SONG` and
`AITD_LIVE_FOLDER` on the documented headless Mac reference. Clean-build
`SONGPROBE=1 SONGPROBEID=<id> SONGHARDWARE=1 PROBES=` and run
`amiga/song_live.gdb`; create `tmp/m4/native-song` first and retain its captures
before testing the next song. `tools/check_song_live.py` combines the complete
original voice check, paired native events and allocation replay. It accepts
only normal observer completion and complete, uncorrupted captures.

Evidence is retained under `tmp/m4/song{132,136,137}`. BDISK2's natural death
route switched to INTRO1 after 748 of 1338 events; that attempt is excluded
from complete-song polyphony acceptance. Early SUSPENSE attempts interrupted
by MONSTER are likewise excluded. SONG 130, 131, 133 and 134 still need complete
original live-voice measurements; no unsupported song guard was relaxed.
