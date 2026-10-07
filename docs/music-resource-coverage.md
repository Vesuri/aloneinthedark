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

The native runtime admits all eight original SONG IDs after complete paired
original/native event and allocation checks. IDs outside 130–137 remain loud
stops. Host format coverage alone did not remove any song guard.

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

Evidence is retained under `tmp/m4/song{130,131,132,133,134,136,137}`. The earlier
BDISK2 death-route and interrupted SUSPENSE attempts remain excluded.

## Authorized remaining-song fixtures — 2026-10-07

The owner authorized guest-RAM writes for isolated M4 contract tests.
`mac_audio_song.lua` changes only the first selector-zero song-ID argument on
the guest stack; original instructions and resources remain unchanged. These
are original-driver contract fixtures, not ordinary-gameplay acceptance.
Full original playback and paired fixed 68030 native fixtures establish:

| Song | Live events | Peak held notes | First peak event | Original drops | Native predicted steals |
| --- | ---: | ---: | ---: | ---: | ---: |
| BDISK1 (130) | 3364 | 6 | 340 | 0 | 1172 |
| BDISK2 (131) | 1338 | 5 | 1331 | 0 | 288 |
| GDISK (133) | 5098 | 6 | 148 | 1 | 1660 |
| H_END (134) | 1948 | 6 | 102 | 8 | 334 |

All 11,748 paired events match note/instrument/order and sequencer deadlines.
The checker also verifies the actual original driver's song ID, every sample
plan and note-off, every native channel allocation and note lifetime, priority
effect behavior, three seconds of trapless interrupt progress and complete
resource/heap/DMA cleanup. All runners exit zero. BDISK1 owns 24 resources/15
samples, GDISK 25/16 and H_END 28/14; no new format or allocation policy was
needed. All eight songs now have complete original live polyphony evidence.
Headless event/ownership acceptance does not claim a new listening session.

Use `AITD_LIVE_SONG=<id> AITD_LIVE_FOLDER=<folder>` with
`tools/mac_audio_song.lua`, then the same native `song_live.gdb` and
`check_song_live.py` path above. Keep the original fixture's output in a
separate folder from ordinary-input attempts. The actual exit status must be
passed to the checker, and all native captures must be saved before the next
song overwrites the shared diagnostic directory.

## Audio-enabled fixed-68030 recordings — 2026-10-07

All eight songs were rerun with audio enabled and warp disabled on
`a4000-030-reference`. Every runner exited zero; the complete original/native
event, allocation, trapless IRQ and cleanup checks passed again. SDL output
captures contain contiguous stereo 16-bit 44100 Hz PCM with zero capture
overflow and zero clipped samples. These are isolated song fixtures.

| Song | Captured seconds |
| --- | ---: |
| BDISK1 | 213.531 |
| BDISK2 | 117.354 |
| FIGHT | 69.927 |
| GDISK | 208.968 |
| H_END | 82.048 |
| INTRO1 | 154.796 |
| MONSTER | 32.612 |
| SUSPENSE | 126.700 |

Evidence is in `tmp/m4/listening/song130` through `song137`: actual exit
status, observer captures, checker output and full WAVs. `index.html` provides
all recordings; `review.wav` contains fifteen seconds from each song in ID
order, separated by one second of silence. `review.json` records source offsets
and signal statistics. Excerpts preserve the recorded PCM without processing.

The capture interposer was additionally verified on arm64 against deterministic
SDL output: all 63,488 bytes from 31 callbacks survived forced termination and
matched the producer. It captures only the emulator's SDL callback, with no
microphone or other application audio. Callback spacing is not itself an
underrun measurement. Nonzero PCM and event agreement establish output, not
recognizable music or physical speaker quality. The clean production build
passed after these fixture runs.

The owner accepted the listening review on 2026-10-07: “The songs sound very
good to me.” This supplies the separate listening evidence and completes M4.2
within the documented four-channel voice-stealing policy.
