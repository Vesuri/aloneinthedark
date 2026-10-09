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
door-object trigger. Its acceptance is **movement and door events**. The ambient fixtures below
complete the separate random-sound playback comparison.

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
`F09B4483` maps to entry 61 (10,806 bytes). The local LISTSAMP decoder
and byte-identical captures establish these identities; no original samples
are committed. Original life scripts 528/529 contain a `random(300)` switch
whose cases 0, 1 and 2 select those three samples. Both sides' captured actor
arrays contain the corresponding bodyless ambient objects 278/279 with life
528/529. Different random selections explain the unmatched ambient requests.
The reference script interpretation is corroborated by the local FITD life
interpreter; the paired entropy fixtures below exercise actual playback of each of these
ambient events through the original interpreter and loader.

The sample and script analysis is retained under `tmp/m4/gameplay/analysis`.
The maintained checker validates complete actor captures and rejects unknown
sound identities. Ambient events remain explicitly outside that checker's parity claim; their
separate checker validates playback and ownership.

This route reaches no new unsupported driver selector. It is bounded coverage,
not proof that the remaining static wrappers are unreachable in the whole game.

## Paired ambient playback

`tools/mac_ambient.lua` and native `AMBIENTCASE=0`, `1` or `2` isolate entropy
only: QuickDraw's seed becomes 1 and the game's accumulator becomes
`16807 XOR choice`. The original RNG executes and the original life interpreter
selects samples 58, 59 or 61 through its modulo-300 branch. Subsequent eligible
choices become 299 to prevent another ambient sound replacing the measured one.
Original instructions, resource bytes and CPU registers are never modified.
This is an authorized RAM fixture, distinct from the ordinary room-route run.

Original captures are `tmp/m4/ambient/mac-{0,1,2}`. Native captures are
`tmp/m4/ambient/native-dma-{0,1,2}`, built with `AMBIENTCASE=<case>` and
`EFFECTDMAPROBE=1` on `a4000-030-reference`, using `amiga/ambient.gdb` with its
output prefix changed to each fresh capture folder. All six exits are zero.
`tools/check_ambient.py <original-folder> --native <native-folder>` verifies:

- The actual RNG result and ambient actor/life, exact original driver-state
  transition, D0/D1/CCR and D2–A6 preservation, and complete original sample tail.
- Identical source PCM and packet fields, exact signed Paula bytes with odd-tail
  padding and silent reload, sample period and DMA allocation.
- Actual Paula interrupts at startup, after the complete attack, and at two
  silent reloads, followed by sample/channel cleanup and interrupt-vector restore.

| Sample | Bytes | Rate (Hz) | Paula period | Physical native attack | Mac completion ticks | Native cleanup ticks |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 58 | 27115 | 8000 | 443 | 3.386733 s | 205 | 205 |
| 59 | 21157 | 8000 | 443 | 2.642591 s | 159 | 163 |
| 61 | 10806 | 9009 | 394 | 1.200364 s | 73 | 232 |

Cleanup is a main-thread operation. Sample 61 starts during initial scene work;
its buffer is released later, but the DMA probe proves that its sound has
already ended and Paula is repeating silence. Treating the cleanup timestamp
as audible duration falsely reported a slow sample. This does not claim that
scene startup itself has no delay.

The stronger ABI test also found and fixed selector 17 retaining X on native
return: the original returns CCR=$04, including X clear. Production now matches
that result. Ambient entropy and DMA probes remain excluded from production.

Together, ordinary movement/door trigger evidence and the three isolated
ambient playback contracts complete the bounded first-room event requirement.
They do not establish all-song listening acceptance or a full-game sound survey.
