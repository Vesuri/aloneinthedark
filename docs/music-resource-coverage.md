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
