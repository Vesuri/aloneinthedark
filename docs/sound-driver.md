# Native SoundMusicSys driver

**Status, 2026-10-04:** The native intro driver and complete reference song pass
M2. M3.2 verifies first-room sound/music controls and driver shutdown. All-song
coverage, gameplay effect variants and perceived audio quality remain M4.

## INTRO1 original polyphony — 2026-10-06

The complete original live capture records six voice slots after each of its
3,736 note events. The verified positive active-state words establish a peak
of six simultaneously held notes, first reached at event 74. Note-off release
tails are excluded from this count. The same checker still verifies every
sample/pitch/loop plan, 1,868 note-off releases and the eight original note-ons
that the full six-voice mixer drops. This measures INTRO1, not the other seven
songs or an audible mixture during release tails.

The native policy prefers a free Paula channel, otherwise replaces the oldest
music voice; effects take priority. Four physical channels cannot retain the
six held notes observed on Mac. Event identity remains exact, while this
allocation policy is an explicit playback difference.

Reproduce the existing complete original-input checker with `--voices tmp/m2-song-live-reference.log --voices-status 0` in addition to its reference,
driver and clock arguments below. The sanitized rerun exits zero; output is
retained in `tmp/m4-event-capacity/intro-polyphony-checked.log`.

## BDISK2 music — 2026-10-05

The original natural death sequence requests SONG 131 / MIDI 901 (`BDISK2`).
Its loading contract has 95 service pairs, two instruments and nine samples:
13 new resources plus the preceding four SMOD handles. Native loading owns 17.
The original call returns 0/12 and preserves all 13 registers and SP.

All 1,338 note/instrument/velocity/channel events and pulse/step timings match
complete native interrupt playback. Delivery is within one music tick. The
fixture verifies 180 ticks without traps, effect priority and full resource,
heap and Paula cleanup. Original loading, original preflight, host and native
runners all exit zero. Other unmeasured song IDs remain named stops.
The natural combat/death route now also passes the 0/12 result, 13 preserved
registers, 17 resources and nine samples on the reference 68030 and baseline
020, then returns to the menu and restarts Carnby. See
[the maintained route](development.md#autonomous-death-and-new-game-restart--2026-10-05).
The full-song fixture remains separate from gameplay/exploration acceptance.

Reproduce with `AITD_GAMEPLAY_SONG=131 tools/mac_driver137.lua` and
`AITD_SONG_EVENTS=131 tools/mac_song_events.lua` environment/script pairs on
headless Mac. Clean-build `INTROSKIP=1 PROBES=1 SONGPROBE=1 SONGPROBEID=131`
and observe `amiga/song131.gdb`. Check the four actual zero statuses with
`tools/check_song131.py`. Local-only logs and captures are under `tmp/m3-death`:
`mac-driver131.log`, `mac-song131-events.log`, `host-song-131.log`,
`native-song131-gdb.log` and `song131-checked.log`. The original resource
inputs belong in its `inputs` directory; do not commit them.

## FIGHT music — 2026-10-05

SONG 132 / MIDI 902 uses eight instruments and 24 samples. The original natural
Core+$138C call makes 236 service pairs, acquiring 34 resources and retaining
four SMOD resources from the preceding song. Native loading owns all 38.
Both return D0=0, D1=12 and preserve D2–D7/A0–A6 and SP. The native natural
attic transition passes with exactly those resources and no original MDRV.
Other unmeasured song IDs remain loud stops.

All 1,206 original preflight events match host decoding and complete native
playback by note, instrument, velocity, channel and order. Pulse/step timing
also matches; interrupt delivery is within one music tick. The fixture verifies
180 ticks of progress without trap calls, effect priority, natural completion
and complete resource/Paula cleanup. This is one song's acceptance, not all M4.

Use `AITD_GAMEPLAY_SONG=132 tools/mac_driver137.lua` and
`AITD_SONG_EVENTS=132 tools/mac_song_events.lua` as environment/script pairs
with the documented headless Mac command. Build the host resource decoder from
`tools/test_song_inputs.cpp` using local-only inputs in `tmp/m3-fight/inputs`.
Clean-build `INTROSKIP=1 PROBES=1 SONGPROBE=1 SONGPROBEID=132`, then observe with
`amiga/song132.gdb`. `tools/check_song132.py` requires all four actual runner
statuses to be zero and checks complete reference, host, loading and native logs.
For the natural gameplay ABI, clean-build `INGAME=1 PROBES=1` and run
`amiga/gameplay_fight.gdb`. Accepted captures are in `tmp/m3-fight`:
`mac-driver132.log`, `mac-song132-events.log`, `host-song-132.log`,
`native-song132-gdb.log` and `natural-gdb.log`. Every runner exits zero.

## Death fade gain — 2026-10-04

Death reaches selector 19 at Core+$1F0A with gain 248. The original driver
builds an unsigned mixer lookup table using linear 8.8 gain: 256 is unity,
zero is silence. It returns D0=0, D1=$0000FFFF and CCR=4 (including X cleared),
preserving D2–D7/A0–A6 and the caller's stack. The measured natural call and
33 isolated levels (256 down to zero in steps of eight) preserve every state
byte except the command/argument/status header; their complete 2,052-byte
lookup tables match the integer oracle in `tools/check_driver19.py`.

Native selector 19 scales Paula AUDxVOL for assigned music/effect channels,
under the audio ownership guard. Future DMA starts use the same gain. Sample
buffers, pitch, DMA and voice ownership remain unchanged; no sample conversion
or allocation happens during fading. Paula quantizes volume to 0–64; the
measured eight-unit fade steps map exactly to two hardware volume units.
Unmeasured gain outside 0–256 remains loud. Gain resets on driver initialization,
and song/effect loading retains it until the original game changes it.

Reproduce the original with `tools/mac_driver19.lua` and the documented headless
Mac command; check `tmp/m3-toolbox/mac-driver19.log` with `--status 0`. Clean and
build `GAINPROBE=1 PROBES=1`, then run `amiga/gain.gdb` on the 68030 configuration.
This CPU-executed fixture loads MONSTER through the ordinary driver service,
verifies all 33 calls' ABI and unchanged active voice ownership, captures values
immediately after hardware volume writes, and observes seven later note starts
inheriting silence before releasing all song resources and audio DMA. AUDxVOL
is write-only; debugger register readback is not used as volume evidence.
This covers the gain contract, not the complete death/restart
route.

## Reached MONSTER music prerequisite — 2026-10-04

The owner-operated M3.4 session stopped with `SONG UNMEASURED`. A subsequent
idle-attic reproduction records selector 0 / SONG 136 (`MONSTER`), matching the
next natural request in the original Mac. The original capture establishes
MIDI 906, six instruments, 21 samples and 29 newly owned resources; the four
SMOD handles remain from the preceding song. Native loading owns 33 resources,
including those four modifiers, and uses the existing supported formats.
Other unmeasured song IDs retain the named stop.

The complete original preflight and native playback agree on all 602 note,
instrument, velocity and channel events. The native fixture also matches the
verified sequencer timing, plays from the music interrupt during 180 ticks of
CPU-only work, steals a music voice for its effect test, completes naturally,
and releases its sample buffers, resources and Paula channels. This verifies
this track; it does not close all-song M4.2 or scripted first-floor acceptance.

The Mac driver can execute through both ordinary and `$80xxxxxx` instruction
addresses. The observers now cover both aliases. The first MONSTER preflight
capture missed 47 notes and was rejected; the complete retry observes 602.
The loading observer also records a nested selector-20 effect query, which
overwrites the driver's last-command header while preserving the song state
and the caller's registers. The checker compares that header with the observed
last query instead of assuming the loading command remains there.

For original captures, run `tools/mac_driver137.lua` with
`AITD_GAMEPLAY_SONG=136`, and `tools/mac_song_events.lua` with
`AITD_SONG_EVENTS=136`, using the documented headless Mac command. For native
playback, clean and build `INTROSKIP=1 PROBES=1 SONGPROBE=1 SONGPROBEID=136`,
then use `song136.gdb` with audio on and warp off. `SONGPROBEID` defaults to 135
and changes only the CPU-executed diagnostic fixture. Require runner exit zero
and check the captures with:

```sh
python3 tools/check_song136.py tmp/m3-toolbox/mac-song136-events-alias.log \
  tmp/m3-toolbox/song136-host.log tmp/m3-toolbox/mac-driver136-alias.log \
  tmp/m3-toolbox/native-song136-gdb.log \
  --original-status 0 --host-status 0 --driver-status 0 --native-status 0
```

The host decoder capture is produced by `tools/test_song_inputs.cpp`, using
SONG 136 / MIDI 906 and the original INST/`snd ` resources in a local-only
directory. `gameplay_music.gdb` checks the natural original-game transition
after an `INGAME=1 PROBES=1` build, including the Pascal/C call stack, all 13
preserved registers, zero result and the exact native resource counts.

## Quit shutdown

The normal original keyboard Quit route calls selector 8 at Core+$1DCC;
Core+$1DC4:$1DD0 is `48780008206df9544e90588f`. Original driver+$54 dispatches
to +$380 and +$3F8A, which closes playback, releases song/effect sample ownership
and clears its storage pointers. Voice configuration remains unchanged. The
game unlocks/disposes the driver entry handle itself after the call returns.

The paired capture returns D0=0, D1=1 and CCR=4, preserving D2–D7/A0–A6 and SP.
Native selector 8 stops the music timer, releases song allocations, stops/frees
effect buffers, quiesces all Paula channels and marks the interface closed.
The native observer checks every preserved register, unchanged configuration,
zero audio DMA and no remaining native song/effect storage, then follows the
original exit through complete OS restoration. Reproduce with the maintained
[keyboard menu pair](menu-manager.md#gameplay-keyboard-route-m32).

## First-room music prerequisite — 2026-10-03

New Game reaches SONG 137 / MIDI 907. `tools/mac_driver137.lua` follows normal
Mac input into Carnby's attic and observes selector zero; its successful log is
`tmp/m3-input/mac-driver137-retry.log`. `check_driver0.py --song 137 --prefix
tmp/m3-input/driver137-reference` checks 237 paired services, preserved registers,
34 newly owned resources, seven instruments and 25 samples. The four modifiers
remain owned from the preceding song. The initial observer failed to reach the
song; that failed log is not acceptance.

The native decoder accepts this additional song with the same six music voices,
three normalized voices and one effect voice. INST 10 adds flag $0400: original
driver +$3292 reuses a voice matching the instrument, note and MIDI channel even
while active. Native playback now releases and restarts that matching channel.
Sample 15000 has a garbage loop-start field with a zero loop end. Original
+$34E4 disables that loop; the bounded parser now does the same, while still
rejecting out-of-bounds enabled loops. Other instrument flags remain rejected.

The host decoder processes all 2,250 song events and prepares the seven
instruments/25 samples; sanitizer fixtures include the new flag and disabled
loop case. The native `INGAME=1` 68030 run enters and renders the attic with
audio enabled. This is first-room startup coverage, not a claim that every
gameplay song or effect now passes M4.

The checkpoint sections below preserve service-level evidence. References to
an intermediate startup stop or a then-pending M2 gate are historical; current
acceptance is recorded in [development.md](development.md), and remaining work
is in [open-work.md](open-work.md). Unsupported contracts remain unsupported
unless a later section explicitly verifies them.

D8 replaces the original software mixer at its driver interface. Native Jnth 11
supplies measured initialization, quality selection, raw one-shot effects and
effect stopping. Original MDRV code never runs on the Amiga. Unimplemented
selectors and playback variants remain named stops.

## Installation seam

Original Core+$10CC first requests `Jnth` with the selected driver ID (11 here)
at +$10E2. A found resource is detached and returned without decryption. Only a
missing Jnth takes the MDRV request at +$1102, decrypt and decompression path.
Core+$1CC6 calls this loader. The original then moves, makes nonpurgeable and
locks the handle; **+$1CF4** stores its body pointer at A5−$6AC. A port-owned
Jnth resource can therefore supply the D8 entry without changing game code.

`check_driver_startup.py` guards the original loader, caller and both argument
setup/call/cleanup sequences by SHA-256. The live, decrypted reference driver
saved before initialization is exactly 29,256 bytes and matches the existing
original unpacked driver, SHA-256
`3880a65dcdf4ece9c5e91712ce0af9866b0dcc435bd09fc5ad536eff2b70b470`.
It is local-only evidence and must never be shipped or committed.

## Measured startup calls

The entry reads selector at 4(SP), argument at 8(SP). It saves D2–D7/A0–A6;
D0 returns the zero-extended 16-bit status, and D1 is scratch. The caller removes
8 argument bytes after RTS. Both reached calls return status zero and preserve
D2–D7/A0–A6 and the pre-JSR SP, verified independently for each call.

| Selector | Original call | Argument | Resulting reference state | D0 / D1 |
| --- | --- | --- | --- | --- |
| 21 ($15) | Core+$1D46 | Pointer to words 6, 2, 2 | Song/normalized/effect limits 6/2/2; quality flag 0; rate fields $0172/1 | 0 / 0 |
| 24 ($18) | Core+$1D60 | $010B | Same voice limits; quality flag 1; rate fields $00B9/0 | 0 / 1 |

The semantic names of the three initialization parameters come from Halestorm's
published [SoundMusicSystem.h](https://raw.githubusercontent.com/Blzut3/Wolf3D-Mac/master/SoundMusicSystem.h).
Internal selector numbers and their effects come from the original bytes and
capture, not that public wrapper header. Selector 21 copies the three words at
driver+$0398 and initializes its state and voice storage. Selector 24 decodes
bits 8/9 as interpolation mode and the low byte as output rate: $0B selects the
11 kHz branch at +$030E. The native implementation must store the interface
configuration and initialize real native state; D8 does not require creating
the Mac software mixer or its hardware buffers. Unimplemented requests remain
named stops. Playback and channel allocation acceptance remain M4.

The driver state base is body+$4200: voice limits at +$11C0/+2/+4, quality byte
at +$30, status word +$08, and the two observed rate words +$60/+68. The Mac's
24-bit locked handle yields a raw entry pointer with bit 31 set. Execution
breakpoints must use the raw address or, as this probe does, the original
call sites; masking the execution address missed both calls in a rejected run.

After exactly these two calls, original Dan1+$0038 returns Times ID 20. The
probe requires both call/return pairs before accepting that endpoint. This
proves the original startup prerequisite, not later selector coverage.

## Reproduce and validate

Use the existing System 7.5.5 reference volume and generated trap map. Clear the
previous dump before starting; the checker requires the new live dump, exact
call order and arguments, register/stack equality, state and original bytes.

```sh
. amiga/env.sh
rm -f tmp/m2-driver-original.bin
SDL_VIDEODRIVER=dummy timeout -k 5 90 mame maciix \
  -rompath ref/mame/roms -nb9 mdc48 -ramsize 8M \
  -hard ref/mame/hd/aitd_755.hd -video none -sound none -window \
  -skip_gameinfo -nothrottle -seconds_to_run 180 \
  -snapshot_directory ref/mame/snap -cfg_directory ref/mame/cfg \
  -nvram_directory ref/mame/nvram -debug -debugger none -oslog \
  -autoboot_script tools/mac_driver_startup.lua \
  >tmp/m2-driver-startup-reference.log 2>&1
run_status=$?
python3 tools/check_driver_startup.py tmp/m2-driver-startup-reference.log \
  --status "$run_status"
```

The probe changes no original instructions, driver state or RNG. It supplies
mouse input for the original size dialog and uses internal debugger reads;
no host window access is involved. A timeout, absent/duplicate call, wrong
state, changed preserved register, missing dump or missing positive completion
fails. Host rejection fixtures run in `make host-tests`.

## Native startup implementation (M2.1c3c2a)

The generated overlay now includes Jnth 11 containing only `$A0F8; RTS`. The
original loader obtains, detaches, moves and locks it, then installs its entry.
MoveHHi flushes the native instruction cache after moving this executable stub.
The native resource boundary requires the exact four port-owned bytes, ID and
overlay provenance. Every call verifies the live handle and entry PC. MDRV
requests retain their unconditional loud stop. No original instructions change.

The private trap runs through the existing user-mode bridge. It reads the
original C arguments, initializes six logical song slots, two effect slots and
four unassigned Paula channels, and stores the measured normalization/quality
configuration. All voices begin inactive with no sample or assigned channel.
Selector 24 selects the requested 11 kHz/interpolation setting. It does not
create a Mac mixer, open audio hardware or claim playback. Unmeasured selectors,
configurations and reinitialization stop by name, reporting the original caller
and selector. M4 extends this interface and supplies playback.

`SoundDriver.h` has sanitizer-backed state and rejection checks. The native
`driver_startup.gdb` uses the shared `menu_lifecycle.gdb` observer, which checks
both original call sites, installed stub, arguments, D0/D1, all thirteen
preserved registers, stack and native state. It then requires the second
original Times lookup to return 20 after exactly two driver calls, the precise
UnionRect endpoint, no MDRV resident and inactive voices/unassigned channels.
`check_native_driver.py LOG --status STATUS` rejects missing/duplicate controls,
wrong ordering, observer errors, incomplete services and nonzero/timeout status.

Integrated acceptance uses `tmp/m2-menu-lifecycle-native-final.log` (exit 0)
and the independent `tmp/m2-driver-startup-reference.log` (exit 0). The original
loader/call bytes and reference state/ABI pass their checker. Native counts are
81 OS handbacks, 143 completed services and 42 original resource reads totaling
208,858 bytes. The same native run passes main/A5 and AGA memory/publication
checks. It does not establish rendered intro or audio acceptance.

Run the native observer with the normal production build, then check its log:

```sh
. amiga/env.sh
make -C amiga
(cd amiga && GDBTAIL=3000 EXTRA_ARGS=--warp_mode=1 \
  GDBSCRIPT=driver_startup.gdb ./diag_run.sh 300) \
  >tmp/m2-native-driver-calls.log 2>&1
run_status=$?
python3 tools/check_native_driver.py tmp/m2-native-driver-calls.log \
  --status "$run_status"
```


## Selector 22: stop effects

Original Core+$1A6C bytes `48780016206df9544e90588f` push selector 22,
call through A5-$6AC at +$1A74 and remove four bytes after RTS. There is no
second argument. The entry still copies the following stack long into D1;
it is ignored by this selector and returned unchanged. D0 is zero and
D2–D7/A0–A6 are preserved, along with the pre-JSR SP.

The original table entry at driver+$008C branches through +$01C2 to +$3606.
It writes $FFFF to the active-state words of effect slots following the six
music voices. Its DBRA also touches the following unused slot: indices 6, 7
and 8 change; the configured effect count is still two. Sample pointers,
other voice state, music slots and output configuration are unchanged.
`mac_driver22.lua` captures the real call and executes an isolated original
CPU fixture with sentinel states, no invented sample pointers and interrupts
masked. Full 12,360-byte state comparison checks exactly those changes plus
the dispatch record's selector/ignored argument/status fields.

`SoundDriver::stopEffects` marks its two logical effect voices inactive,
retaining sample state, music and configuration. Host tests cover active
logical effects, idempotence and music isolation. Ordinary-input active playback
acceptance now covers the hardware path too: `mac_driver22_active.lua` presses
S while a genuine effect is playing with four held music voices. The complete
original state differs only in dispatch fields and the configured effect stop
words; sample pointers and all music state remain unchanged.

`AUDIOSTOPPROBE=1 INTROSKIP=1` queues the same ordinary S key during a genuine
native effect. `driver22_active.gdb` checks the original caller and preserved
ABI, one stop, disabled effect DMA, freed Chip buffer and released channel.
`check_driver22_active.py` independently compares the complete logical driver
state and both music ownership arrays. The accepted fixed 68030 run stops
channel 2 at music tick 6342 while music state is unchanged. Two music release tails retain their DMA channels through the stop. The fixed
68020 capture also passes with held music notes. No original
instructions, registers or guest state are modified by these observers.


`driver22_call.gdb` observes the actual native call read-only, checking D0/D1,
all thirteen preserved registers, stack, the third completed native driver call
and unchanged inactive voice/configuration state. `check_driver22.py` guards
original caller, driver entry/dispatch/implementation bytes and both reference
state transitions, then requires the integrated native startup guard.


Accepted runs: `tmp/m2-driver22-reference.log` and
`tmp/m2-driver22-native-final.log`, both terminal exit zero. Run:

```
python3 tools/check_driver22.py tmp/m2-driver22-reference.log --status 0 --native tmp/m2-driver22-native-final.log --native-status 0
```

Selector 22 is the third completed native driver call. Startup next reaches
selector 17, Core+$17FC, with the Infogrames frame unchanged and original MDRV
absent. At that next stop 480 services have entered and 479 completed; the known
selector-17 $A0F8 service is in progress. Counts are 135 windows, 68 resource
reads / 333,998 bytes and CODE mask $3FFB. Playback acceptance remains open.


## Selector 17: raw one-shot effects

Original Core+$17F0 pushes the packet and selector 17, calls through A5-$6AC
at +$17FC and removes eight argument bytes. The 26-byte packet contains:

| Offset | Field | First actual request |
| --- | --- | --- |
| 0 | unsigned 8-bit PCM pointer | 30,783 captured bytes |
| 4 | sample byte count | 30,783 |
| 8 | 16.16 sample rate | 8,000 Hz |
| 12 / 16 | loop start / end offsets | 0 / 0 (one-shot) |
| 20 | pointer to a signed loop counter | points to zero; unused without a loop |
| 24 | effect identifier | $8000 |

Driver+$3506 selects the first free effect slot following the six music slots.
It stores the identifier separately from its voice-aging priority. The actual
call selects slot 6, returns D0=0 and D1 with the argument's upper word and
$7FFF in its lower word, preserving D2–D7/A0–A6 and the caller's stack.
`mac_driver17.lua` captures the full state transition and natural completion:
230 Mac ticks, cursor exactly at sample end, inactive voice, loop counter
unchanged. The full sample remains local-only.

The native path copies raw PCM into chip memory using Vette's XOR-$80
conversion and DMA protocol. It never applies Vette's optional sample-header
heuristic to this packet. The odd final sample is followed by signed-zero
padding and a silent two-byte reload: 30,786 allocated bytes. PAL period 443
approximates 8 kHz on Paula; volume is 64. D8 compares playback events and pitch,
not the original software mixer's waveform or normalization.

The timer starts after DMA latches, uses the actual Paula period (231 ticks),
and allows one additional tick for VBI phase before reclaiming the buffer.
Safe points, including the named-stop wait, quiesce the assigned hardware
channel before freeing its buffer. Selector 22 and normal exit use the same
cleanup. The logical sample identity is retained on stop, as on the Mac;
no borrowed source pointer is used by DMA. Sample and packet reads are bounded
within the owning Mac zone before copying.

At this checkpoint, loops, fractional rates, oversized samples and multi-effect
allocation remained named stops. The later fractional-rate and two-effect
acceptance sections below supersede those two restrictions. Loops and oversized
samples still stop explicitly rather than becoming one-shot playback or being dropped.
`check_driver17.py` compares the full original transition, request, sample,
converted DMA bytes, native ABI, start event and natural cleanup. The existing
host driver test also covers raw-header ambiguity, odd alignment, silent
reload, rate limits and duration arithmetic against an independent 64-bit
oracle. Native duration uses only 32-bit multiply/divide: this runtime does
not link a 64-bit division helper.


Accepted selector-17 evidence: `tmp/m2-driver17-reference-complete.log` and
`tmp/m2-driver17-native-return-probe.log`, both terminal exit zero. The native
observer stops at the stub's RTS and single-steps to the unchanged caller;
a direct return-address breakpoint was missed in a rejected diagnostic run.
The actual source and all 30,786 DMA bytes compare exactly. DMA changes
$3F1→$3F0, the voice/channel becomes inactive/unassigned, and chip allocation
becomes zero at tick 232. Nine AGA publications and all existing paired startup
checks pass before the stop screen is drawn. Next: selector 20, Core+$17C8.


## Selector 20: effect status

Core+$17BC pushes the packet and selector 20; +$17C8 calls the driver and
+$17CA removes eight bytes. Driver+$36E2 reads the identifier at packet+24,
then returns 0 if the **first matching** effect slot is active, otherwise 1.
An inactive first match ends the search even if a later duplicate is active.
D1 remains the packet argument; D2–D7/A0–A6 and the pre-JSR stack are preserved.
Only dispatch fields (selector/argument/status) change in the full driver state.

`mac_driver20.lua` observes 230 active results followed by completion on the
original route, then isolated active, inactive/stopped-state, missing-ID and
first-inactive-duplicate fixtures. These fixtures inspect status semantics;
explicit stop mutation itself is covered by selector 22's separate fixture.
`SoundDriver::effectStatus` uses retained effect identifiers and actual active
flags; safe-point DMA cleanup runs before the native query. Host tests also
query after logical stop and exercise duplicate-ID ordering.

M2.3g27 is complete. Native `tmp/m2-lineto-native-accept.log` exits zero and
proves 199 active results followed by the game's actual completed query. All
200 call returns preserve the driver ABI. The completed result coincides with
one natural effect stop: active=0, channel=-1, chip allocation=0 and DMA=$3F0,
after 232 native ticks. It is not an injected result or a query made by a test.
The route then reaches PaintRect at Dan2+$0D52 with MDRV absent and 689/689
completed services, none in progress.

The default full-sequence `check_driver20.py` passes against original
`tmp/m2-driver20-reference.log` (exit zero), together with the effect PCM,
cleanup, drawing, palette/AGA and startup regressions (27 integrated checks).
The earlier 23-query prefix remains partial historical evidence and is not the
basis for acceptance. Poll counts need not match across machines; state,
result and event ordering must. At this boundary, startup service expectations
add the observed query count to baseline 489 for existing prefs; baseline 497
and 165 windows for fresh prefs remain derived expectations.

## Selector 13: song-control word

Core+$1374 pushes the argument and selector 13, calls through A5-$6AC at
+$137E and removes eight bytes at +$1380. The original bytes are
`2f004878000d206df9544e90508f`. The reached argument is zero.
Driver dispatch +$0068 branches to +$0348, which copies the argument's low
word into state+$0038. D0 returns zero, D1 retains the full argument, and
D2–D7/A0–A6 and the pre-JSR stack are preserved. This call starts no voice.

`mac_driver13.lua` observes the real call and a separate original-CPU fixture
with argument $12345678. `check_driver13.py` verifies the complete 12,360-byte
state: only the dispatch fields and the control word may change. The fixture
proves low-word truncation to $5678, rather than a Boolean conversion. Both
calls pass in `tmp/m2-driver13-reference.log` with terminal status zero.

The native model retains this value as `songControl`, with host tests for
truncation, reset, initialization and preservation of all other voice/configuration
state. The word is tested by the original song status and end-of-sequence paths;
its use by a native music sequencer remains pending. Unimplemented playback
selectors still stop by name. Native original-call acceptance passes in `tmp/m2-driver13-native-full.log`
(terminal status zero), together with all 36 integrated comparisons. This is the
full saved debugger output; `tmp/m2-driver13-native.log` contains the runner's
truncated display. Original MDRV remains absent and all sixteen effects have
completed with no remaining DMA allocation. The next named stop is selector 0,
argument $87, at Core+$138C (M2.3g38).

Reference validation:

```sh
python3 tools/check_driver13.py tmp/m2-driver13-reference.log --status 0
```

For the accepted native capture, add
`--native tmp/m2-driver13-native-full.log --native-status 0`. Supply the actual
terminal statuses; neither a deadline nor a debugger error counts as success.


## Selector 0: native song start and playback (M2.3g38)

Core+$138C requests SONG 135 ($87). `mac_driver0.lua` and `check_driver0.py`
verify the actual call, 285 nested service pairs, register/stack preservation,
resource ownership and armed MIDI state in `tmp/m2-driver0-reference.log`
(terminal exit zero). D0 is zero; D1 is scratch ($0C on this call). The original
loads MIDI 905, scans its instrument use, and retains seven INST resources
(0, 1, 11, 22, 26, 28, 31), 28 unique samples and four SMOD resources. The total
is 41 detached, nonpurgeable, locked handles. SMOD resources contain executable
Mac code; the native path must implement required behavior without running it.

SONG configuration changes the logical limits to six music voices, three
normalized voices and one effect voice, with flags $2205. The MIDI track is
armed at offset 22 in state $46; the original call has not yet consumed its
first note event at return. The native call now matches that state and its C
calling convention. The 41 detached, locked, nonpurgeable bodies equal the
original resource payloads. Original MDRV remains absent; retained SMOD bodies
are never executed. Resource-release errors are explicit loud stops.

`tmp/m2-song-runtime-discover-full.log` preserves the complete exit-zero
integrated run. Its original caller returns D0=0/D1=$0C with all required
registers and stack preserved; execution advances to selector 15 at Core+$0FC8.
The old stop is passed, not suppressed. All 36 earlier integrated regressions
pass in `tmp/m2-song-runtime-regressions.log`, including intro return, effects,
GetKeys, offscreen/window drawing, AGA publication and the full initial A5 world.

The native sequencer advances in VBI after display publication, using the
existing 60 Hz game clock. PAL fields advance one or two logical ticks; NTSC
fields advance one. A private 8 KiB interrupt stack keeps music work off the
small supervisor stack that may already contain a drawing service. Original
Mac VBL callbacks remain in user mode.

Starting a song identifies every used instrument/note pair, prepares its pitch,
DMA layout and one-shot duration, and converts the required immutable PCM
variants. It uses only the requested song resources, already detached and
locked by the song loader. The interrupt performs no allocation, conversion,
resource access or original-code callback. Main-thread channel ownership changes
exclude music briefly; stop/release disables playback before freeing any data.
If VBI encounters ownership exclusion, it records a pending update. The outer
ownership release services it immediately on a separate 8 KiB stack, rather
than waiting another field. VBI may interrupt this completion safely; both
update paths hold ownership across the complete decoder operation so nested
voice guards cannot re-enter it. No original Mac callbacks run on either stack.
Interrupt errors are reported through the existing named stop at the next
user-mode boundary.

A free Paula channel is preferred; otherwise the oldest music voice is replaced.
Effects have priority. Note-off selects silent reload and quiesces the channel
within five ticks; this release waveform intentionally differs from the original
software mixer tail. Natural one-shots finish using their programmed period.
Shutdown quiesces DMA before releasing chip buffers and owned song handles.

The owner reported uneven note spacing during normal-speed 68030 playback on
2026-10-03. The previous safe-point catch-up policy preserved the logical
sequence but could deliver overdue notes together. The original event trace
alone did not test audible timing. The interrupt fixture adds actual delivery
ticks and a three-second CPU-only interval with no service calls. The focused run
(`tmp/music-vbi-span-song-full.log`, exit 0) delivers 30 events during that
interval and all 3,736 events within one logical tick of their due time, the PAL
quantization allowance. Exact events, all 25 PCM variants, effect priority and
cleanup pass. Run `tools/check_song_playback.py` with `--interrupt` to check
the delivery trace as well as the original logical event sequence.

The integrated normal-speed, audio-enabled 68030 run
`tmp/music-vbi-final-route-full.log` reaches all nine transitions and natural
completion with 3,736 events and a 920-byte minimum original stack margin.
It **fails** the music timing gate: maximum delivery lateness is two ticks,
against the one-tick PAL allowance. After the span-copy revision,
`tmp/music-vbi-busy-route-full.log` (exit 0) completes all nine transitions and
3,736 events with maximum lateness one tick, zero late presentations and the
same 920-byte original stack margin. Eight fields encounter channel-ownership
exclusion, but none produces a greater note delay in this run. The earlier
two-tick outlier is not reproduced or explained by this result. Fresh listening
acceptance and sub-field interrupt-duration measurement remain open.

The subsequent bulk key-release run (`tmp/intro-key-release-route-full.log`)
reproduces and attributes that outlier: a channel-ownership exclusion at tick
9550 precedes maximum lateness two at 9552, during sound-effect activity. All
3,736 events and the natural route complete, but the one-tick music gate fails
(exit 1). This is a deferred VBI at an effect boundary, rather than a long
rendering-safe-point catch-up. Immediate ownership-release servicing now
addresses this cause; fresh listening acceptance remains open.

The forced-deferral fixture (`tmp/music-deferred-forced-song-full.log`, exit 0)
holds nested ownership across a VBI, verifies that the inner release cannot
advance music, then requires the outer release to service that tick before any
further service call. The full-song checker with `--interrupt` passes all 3,736
events, 25 PCM variants, effect priority and cleanup, with maximum lateness one
tick. The normal intro (`tmp/music-deferred-route-full.log`, exit 0) completes
all nine transitions and 3,736 events at tick 20,613. Seven fields encounter
ownership exclusion; maximum lateness remains one tick. It presents 1,046
frames with no late publications and retains the 920-byte minimum observed
game-stack margin. Sub-field interrupt-duration measurement and owner listening
remain separate acceptance requirements.

The full-song diagnostic also brackets the owned music update with read-only
CIAB TOD samples (`tmp/music-duration-song-full.log`, exit 0). This counter
counts horizontal syncs; reading high latches the value and reading low releases
it ([Hardware Reference Manual, appendix F](https://www.amigadev.elowar.com/read/ADCD_2.1/Hardware_Manual_guide/node012E.html)).
Audio ownership prevents nested music reads of that latch. No CIA timer or
counter configuration is changed. Across 7,378 updates, the measured total is
43,395 scanlines and the maximum 87 lines, handling seven events. At roughly
64 microseconds per PAL line, this is about 0.38 ms average and 5.6 ms maximum.
The bracket includes the sequencer/Paula update and diagnostic overhead, but
not the surrounding display/input ISR or stack wrapper. It covers the song
fixture, including forced deferral and an effect, rather than all gameplay.
The event/PCM checker still passes with maximum delivery lateness one tick.
Normal builds omit the counters and CIA reads. Gameplay interrupt budgets and
private-stack headroom remain part of M5.3; owner listening remains pending.

Startup attribution before the span-copy conversion change is recorded in
`tmp/music-vbi-cost-full.log` (exit 0, `INTROSKIP=1 SONGCOST=1`, same 68030,
audio on, no warp). The blank-frame interval is 519 ticks; PCM conversion
accounts for 166 ticks, resource loading 33, movement 92 and locking one.
These are logical 60 Hz ticks, not host time. Moving per-byte bounds/wrap checks
to span boundaries reduces conversion to 92 ticks (1.53 seconds), with the
whole blank-frame interval at 436 ticks (7.27 seconds), in
`tmp/music-vbi-span-cost-full.log` (exit 0, identical build flags and setup).
Resource loading/movement/locking is 26/98/1 ticks in that run. The sanitized
27-stream PCM oracle passes (`tmp/music-vbi-span-host-final.log`), as does full
native verification of all 25 variants and 3,736 events after this revision
(`tmp/music-vbi-span-song-full.log`, exit 0; checker with `--interrupt`).

Ordinary (stride-one) PCM now converts four bytes per iteration using explicit
68020+ `move.l`, `eor.l #$80808080` and `move.l` instructions. Loop boundaries,
remaining bytes and decimated streams retain the bounded byte path. This runs
once while preparing each retained sample variant, never during note playback.
The generated binary confirms longword loads/stores; a compiler-only memcpy
version still emitted byte transfers. On the current bulk-key-release build,
conversion falls from 88 to 32 ticks and the blank-frame interval from 402 to
336 ticks (6.70 to 5.60 seconds). Resource loading/movement/locking is 7/105/0
ticks in both runs (`tmp/intro-key-release-cost-full.log` and
`tmp/intro-pcm-long-cost-full.log`, exit 0, same flags and reference 68030 setup,
audio on, no warp). The sanitized 27-stream host oracle passes in
`tmp/intro-pcm-long-host.log`. Full native verification also passes
(`tmp/intro-pcm-long-song-full.log`, exit 0; checker with `--interrupt`):
all 458,974 bytes across 25 variants, 3,736 exact timed events, effect priority
and cleanup. Thirty events play during the 180-tick CPU-only interval;
maximum delivery lateness is one tick in this focused fixture. This does not
close the integrated effect-boundary timing outlier described above.

The M2 black-interval investigation found that repeatedly converting PCM for
each note starved original game execution. On baseline 68020, conversion used
16,697 of 17,181 music-service ticks before the first demo picture, within a
21,663-tick blank-frame gap (`tmp/m2-black-cost-native-full.log`, exit 0).
Converted samples are now owned by the song and keyed by sample/decimation
stride (1, 2, 4, 8 or 16). Voices borrow immutable buffers; note period and
channel allocation remain independent. Stop/steal quiesces the channel and
drops the voice reference; song release stops all voices before freeing every
retained buffer and then its original resources.

The same baseline diagnostic now measures a 2,976-tick gap and 65 conversion
ticks (`tmp/m2-black-reuse-native-full.log`, exit 0). This is a reduction from
361 to 49.6 emulated seconds, not a claim of instantaneous loading or rendered
acceptance. The complete event stream needs 25 distinct converted variants,
458,974 bytes, rather than converting 36,334,284 bytes repeatedly. Full native
playback now passes (`tmp/m2-song-reuse-native-full.log`, exit 0): all 3,736
original timed events, 1,868 note starts, 25 byte-exact retained PCM variants,
effect priority, natural completion and cleared voice/sample ownership after
release. The independent playback checker verifies every retained byte and
the 458,974-byte total. Subsequent heap movement avoids copying free payload,
reducing the complete blank interval to 474 ticks (7.9 seconds). The owner video
confirms 7.95 seconds and natural demo completion; normal-route and rendered
acceptance are complete. Broader music and perceived audio quality remain M4.
Build `INTROSKIP=1 SONGCOST=1` and use `amiga/song_cost.gdb` to repeat the
consecutive-frame/tick measurement; its counters are absent from normal builds.
The host suite's initial window-geometry run and first retry hit its 30-second
deadline. The identical sanitizer binary then passed in 10.54 seconds under a
120-second diagnostic ceiling; all subsequent suite checks passed. Evidence:
`tmp/m2-song-reuse-host-suite.log`, `tmp/m2-window-geometry-check.log` and
`tmp/m2-song-reuse-host-suite-tail.log`. No geometry code or assertions changed.

`SONGPROBE=1` is a compiled diagnostic fixture. Immediately after the original
quality initialization it starts the native song in user mode, records every
note, injects one short effect when all channels hold music, then checks complete
playback and releases resources. It cannot resume normal gameplay with this
altered startup state. `tmp/m2-song-probe-native-full.log` exits zero:

- All 3,736 note events match the original instrument, note, velocity, channel,
  MIDI position, sequencer pulse and tempo step exactly. MIDI ends at pulse
  8,854; the final note event is at pulse 8,785.
- Both a normal-rate sample and a decimated high note have exact complete native
  chip-buffer bytes, legal programmed periods (253 and 190), loop phase and
  enabled DMA. Period rounding and high-note decimation are D8 adaptations.
- All 1,868 note-ons are issued. Four-channel allocation replaces an older
  music voice 1,099 times; the injected effect takes a music channel once more.
  These documented voice-stealing differences replace the original six-voice
  allocation, which drops eight notes. No software mixing is introduced.
- The effect starts and completes once, music finishes, every chip allocation
  and channel is released, all 41 owned handles are disposed, and both Mac heaps
  pass structural checks. Original MDRV is absent throughout.

Reproduce the two complementary checks (use actual terminal exit statuses):

```sh
python3 tools/check_song_start.py tmp/m2-driver0-reference.log \
  tmp/m2-song-runtime-discover-full.log --reference-status 0 --status 0
python3 tools/check_song_playback.py tmp/m2-song-clock-reference.log \
  tmp/m2-song-probe-native-full.log --reference-status 0 --status 0
```

Build the focused fixture with a clean `make -C amiga SONGPROBE=1`, source
`amiga/env.sh` first, then run `GDBSCRIPT=song_probe.gdb ./diag_run.sh 600` from
`amiga/`. Clean-rebuild without the flag for production. The production build
passes no-float and 83-symbol audits; the fixture passes the 88-symbol audit.
The full host suite and eight evidence-rejection cases pass. Freestanding
64-bit quotient calculation uses bounded integer shifts/subtractions, tested
against 2,000 independent host divisions; no floating-point or unavailable
integer runtime helper is linked.

Only the reached SONG 135 form is enabled. Compressed inputs, replacement,
other song IDs and unimplemented selectors remain named stops. Native playback
acceptance does not claim the M4 all-song/toggle/manual-listening milestone.


## Song input descriptions and preflight (M2.3g38a)

`SongInputs.h` supplies bounded descriptions for the reached SONG, single-track
format-0 MIDI, INST range tables and standard unsigned 8-bit `snd ` samples.
It owns no resources and starts no audio. Unknown flags, formats, commands and
encodings produce named errors; malformed lengths and loops never read beyond
the supplied buffer. Sample data ends at its declared length: twelve of the
28 reached sample resources contain 36 additional bytes, which are preserved
as trailing data rather than played. The instrument trailer is the measured
`0000800000000000`; alternative modifier forms remain unsupported.

The original MIDI preflight was observed at driver+$312E/$30DC, using the raw
execution pointer for breakpoints and its masked 24-bit address for byte reads.
The first observer failed its byte assertion because it read flagged addresses;
that rejected log is `tmp/m2-song-events-reference-unmapped.log`. The corrected
`tmp/m2-song-events-reference.log` completes normally with 3,736 note events.
The captured 82-byte SONG and 15,320-byte MIDI bodies equal the source resources.

All 3,736 decoded note events match the original byte position, instrument,
pitch, velocity, channel and order. The preflight selects INST 0/1/11/22/26/28/31
and 28 unique samples in the same order as the original resource calls.
A first comparison exposed program-change handling: the original tests bit 2
of the **high byte** at state+$11BA. Thus flags $2205 ignore program messages
and retain the SONG channel mapping; the corrected helper and fixture enforce
this behavior. Channel volume still scales note-on velocity by integer division
by 127. Playback scheduling, pitch and voice allocation remain runtime work.

`make host-tests` includes `check_song_inputs.py` with address/undefined-behavior
sanitizers and synthetic volume, running-status, ignored-program, note-order,
tempo/end, truncation, malformed-variable, range, encoding and loop checks.
The original-input comparison is:

```sh
python3 tools/check_song_inputs.py \
  --reference tmp/m2-song-events-reference.log --status 0 \
  --driver tmp/m2-driver0-reference.log --driver-status 0
```

The checker compiles the actual C++ helper, compares its event stream and
resource graph, and checks the original driver's complete ownership capture.
These are parser/preflight checks; they do not establish native music playback.

### Integer playback clock (M2.3g38b)

`SongTimeline.h` reproduces the original quantized tempo and 1/64-MIDI-tick
countdown using integer arithmetic. The first sequencer call reads the initial
delta; later calls subtract `(division << 6) / (tempo / divisor)`, where a zero
SONG divisor selects 16667. A nonzero delta fires on subtraction borrow, so an
exact zero waits one further pulse. Coincident events run in the same pulse.
Out-of-range clocks and unsupported tempo steps fail by name.

`tmp/m2-song-clock-reference.log` exits zero with all 3,736 live note events
through sequencer entry 8,785. Every note, instrument, channel, velocity, MIDI
byte position, sequencer entry and current tempo step matches the portable
helper. `mac_song_clock.lua` counts actual entries at driver+$186E without
changing guest state. Synthetic fixtures also cover the first pulse, tempo
changes, exact-zero boundary and coincident end. Run the paired check with:

```sh
python3 tools/check_song_inputs.py \
  --reference tmp/m2-song-events-reference.log --status 0 \
  --driver tmp/m2-driver0-reference.log --driver-status 0 \
  --clock tmp/m2-song-clock-reference.log --clock-status 0
```

The preliminary live observer found that callbacks execute at masked PC
$007299AA even though the installed entry retains its high handle flag
($807292CC). Raw-address-only capture `tmp/m2-song-live-reference-no-events.log`
failed to complete and is rejected. The corrected live capture records all
3,736 notes and voice snapshots. State+$118C counts mixer work, not sequencer
entries, and is unsuitable as a clock oracle. The direct entry counter resolves
that discrepancy. The runtime integration and its complementary native checks are documented
in the selector-zero section above.

### Sample selection and Paula conversion (M2.3g38c)

`SongVoice.h` implements the plain INST range selection at original driver
+$315E–$3218 and the pitch/loop setup at +$336A–$3502. The adjusted note is the
input note minus a nonzero INST base pitch plus 60. Range lower bounds use an
unsigned byte comparison, upper bounds a signed byte comparison; zero/127 are
open endpoints. A zero alternate sample selects the base sample. A plain
instrument with no matching range drops the note. Unknown pitch indices stop.

The original fixed-point pitch table is represented by twelve measured ratios
and octave shifts, reproducing all 128 entries and the tiny-fraction clearing
at +$3436. It is integer-only. The reached mixer advances at the measured
$56EE8BA3 fixed-point output rate divided by two (185 samples interpolated to
370); the native Paula period uses that actual clock rather than treating the
sample header's nominal 11025 Hz as the mixer output rate. The sample header
must still describe the measured rate. Loops require a nonzero start and a
word-sized length of at least 100 bytes, as at +$34C8.

`mac_song_live.lua` records all six original voice slots after each of 3,736
live note calls. Its completed exit-zero capture is
`tmp/m2-song-live-reference.log`. The portable plan matches all 1,860 allocated
note-ons by sample, initial pointer, pitch step, final PCM byte, loop bounds and
amplitude state. The remaining eight note-ons encounter six occupied voices
and are dropped by the original; all 1,868 note-offs release matching voices.
All 128 pitch ratios match. Add the following to the input/clock checker:

```sh
  --voices tmp/m2-song-live-reference.log --voices-status 0
```

D8 conversion uses unsigned-to-signed PCM and word-aligned attack/reload blocks.
The reached song requests nominal Paula periods 84–451: 219 of its 1,868
note-ons would exceed the standard DMA rate. Those samples are decimated by two
and played at the corresponding recalculated period (at least 124). This is a
Paula waveform adaptation under D8; note identity and pitch remain unchanged
apart from hardware period rounding. Loop phase is retained across attack,
padding and repeated reloads, including odd loop lengths. The converter keeps
no original executable code and performs no mixing. A bounded power-of-two
stride handles the rate; unsupported periods or extents stop by name.

Paired acceptance is `tmp/m2-song-voices-paired.log`; conversion of every
note's original PCM passes an independent byte-stream oracle. The sanitized
host suite also checks 27 guarded odd/even loop and decimation cases. Five
negative checks reject incomplete, errored, wrong-pitch and wrong-loop evidence
in `tmp/m2-song-voices-rejections.log`. A standalone 68020 cross-compilation
passes; its only unresolved arithmetic helper is integer `__udivdi3`.
These helpers supply the runtime implementation documented above; resource
ownership, scheduling and hardware access remain in MacLoader.


## Driver callback clock (M2.3g39)

The next reached query is selector 15, argument zero, at Core+$0FC8. Original
+$0FBE–$0FCB bytes are `42a74878000f206df9544e90508f`. Its dispatch entry at
MDRV+$0070 is `6000012a`; the body at +$019C is
`202c18806000ff0e`: return the longword at state+$1880 directly, bypassing
the ordinary 16-bit status return. D1 receives the full argument; D2–D7/A0–A6
and the pre-JSR stack are preserved. Apart from dispatch selector/argument and
cleared error word, the entire 12,360-byte driver state is unchanged.

`tmp/m2-driver15-reference.log` exits zero with the actual query returning
$27EF and an isolated original-CPU fixture returning $89ABCDEF. The latter
uses argument $12345678 and proves both the full-width result and D1 behavior.
Nine rejection checks cover timeout, missing completion, truncated result,
observer error, callback count, callback path and clock rate. No game instructions are patched.

A separate read-only counter observation, `tmp/m2-driver-clock-reference.log`
(exit zero), runs from quality setup to the first query. The original counter
advances from 5 to $27DC: exactly 10,199 double-buffer callbacks at +$06FE over
10,198 Mac ticks. Neither legacy-hardware +$0824 nor device +$3B16 is used.
The one-count boundary difference is callback/tick phase. The clock runs during
the intro before song start; it is not a MIDI event count or song-relative time.
`mac_driver_clock.lua` preserves this observer.

The original also returns condition codes from the full longword. A short
isolated CPU fixture, `tmp/m2-driver15-flags-reference.log` (exit zero), measures
seven results: 0, 1, $8000, $10000, $80000000, $89ABCDEF and $FFFFFFFF.
Their X/N/Z/V/C values are 4, 0, 0, 0, 8, 8 and 8. The dispatch shift clears X;
the query's MOVE.L sets N/Z and clears V/C. This differs from the normal native
OS-service bridge, which tests D0.W. The native bridge now uses this measured 32-bit flag contract. The integrated
observation precedes the flag correction; the separate native bridge fixture
verifies the corrected code at every boundary.

The native D8 implementation uses elapsed 60 Hz ticks from driver initialization,
with unsigned 32-bit wrap. It is independent of active songs/effects; querying
it does not alter driver state. Host checks cover a nonzero epoch, tick wrap,
high-bit results, reset and quality/effect-stop preservation. No original mixer
callback is executed. The native original-call capture and all 36 prior integrated comparisons pass
at the new selector-4 stop.

```sh
python3 tools/check_driver15.py tmp/m2-driver15-reference.log --status 0 \
  --clock tmp/m2-driver-clock-reference.log --clock-status 0
```


`tmp/m2-driver15-native-full.log` exits zero: the actual query returns $CBCE,
equal to sampled tick $CCD8 minus initialization epoch $010A, preserving D1,
13 registers, stack and the entire native driver state. Music has advanced to
820 events at pulse 1959 by the observed song-start return; that event count and
tempo match the original trace between pulses 1948 and 1983. All 41 retained
resource bodies and their ownership still match. At the final selector-4 stop,
music is at pulse 1961, with 410 starts, 152 steals and no dropped notes.
Playback can advance while the original call completes; a zero-event snapshot
is not a stable return requirement.

`tmp/m2-driver15-flags-native-fixed-full.log` exits zero and matches all seven
original boundary results, D1 and all five flags through the real Jnth trap and
user-service bridge. `DRIVERCLOCKPROBE=1` runs this short fixture before game
startup, briefly holding interrupts around each allocation-free query. The
first fixture attempt stopped at `RESOURCE READ OUTSIDE USER SERVICE`; it is
rejected. Setup now loads Jnth through the actual GetResource trap. No original
MDRV executes. Final production and fixture links pass no-float and 83/87-symbol
audits; the host suite and 36 integrated checks pass.

Active music can defer additional ordinary traps to safe user mode, so service
counts after song start are no longer a fixed baseline plus effect queries.
The endpoint retains exact resource/window checks, a service-count minimum and
one explicitly pending service. Each capture reports its actual totals.


## Song status query (M2.3g40)

Core+$1FC8 calls selector 4 with only the selector pushed. Original
+$1FC0–$1FCB bytes are `48780004206df9544e90588f`; the caller removes four
bytes. The driver still reads the following stack longword into D1 internally,
but this is not a declared argument. Dispatch +$0044 (`6000030e`) reaches
+$0354 (`70ff610012e6394000086000fd4a`) and the status scan at +$163E.

The status scan first tests state+$36 (sequencing enabled). If zero it returns
zero and preserves the following stack longword in D1. If enabled and the
control word at +$38 is nonzero, it returns $FFFF with that same D1. Otherwise
it scans the first byte of each of 24 four-byte track records at +$1A28.
The first nonzero byte returns $FFFF and D1=23−slot; no active track returns
zero and D1=$0000FFFF. The entry zero-extends D0.W. X/V/C are clear, N is set
for $FFFF, and Z is set for zero. D2–D7/A0–A6 and the pre-JSR stack are preserved.
Only the dispatch selector/following-word/error fields change in driver state.

`tmp/m2-driver4-reference.log` exits zero. The real call returns D0=$0000FFFF,
D1=$17 and CCR=$08. Seven isolated original-CPU cases cover disabled sequencing,
nonzero control, first/last/middle active tracks, no active tracks and a nonzero
low byte with a zero high byte. Full 12,360-byte before/after snapshots match
these exact transitions. Five negative checks reject timeout, missing completion,
wrong flags/registers and observer error.

The native model scans a bounded 24-bit active-track mask. The supported
format-0 MIDI supplies bit 0 from the sequencer's active flag. It does not use
remaining Paula voices as a proxy for track status: sample release tails can
outlive the final MIDI event. The real-trap bridge reproduces the measured
16-bit status flags and clears X explicitly. Other selectors remain named stops.
`tmp/m2-driver4-native-full.log` exits zero: the original call returns
D0=$0000FFFF, D1=$17 and CCR=$08, preserving stack, registers and driver
configuration. All 36 prior integrated comparisons pass in
`tmp/m2-driver4-regressions.log`; the song ownership and driver-clock checks
also pass on this capture. The full playback fixture remains valid because
this change only queries sequencer status and does not alter playback.
The next explicit stop is RectRgn at Dark+$3D46, outside a deferred service.
The first native run was interrupted before completion and is retained as
`tmp/m2-driver4-native-interrupted-full.log`; it is not accepted evidence.

```sh
python3 tools/check_driver4.py tmp/m2-driver4-reference.log --status 0 \
  --native tmp/m2-driver4-native-full.log --native-status 0
```

## Occupied effect replacement (M2.3g44a)

The original idle road scene reaches selector 17 while its sole effect slot is
still active. The original Driver+$3506–$3604 scans occupied slots by the word
at voice+$200; with one effect slot it replaces that slot. D1 retains the packet
pointer's upper word and returns the selected slot's age in its lower word.
The original caller is still Core+$17FC; no game instructions change.

`tmp/m2-effectreplace-clock-reference.log` finishes normally. The slot starts at
age $7FFE; Driver+$1FE8 decrements it once per callback. The measured selector-15
clock advances from $2837 to $291D (230 callbacks), leaving age $7F18, exactly
as returned in D1.W. An exploratory check against the unrelated state+$118C
mixer counter failed; the accepted observation uses the verified state+$1880
callback clock. The new request is 31,020 raw PCM bytes at 8 kHz, identifier
$8000, without a loop. The complete driver state matches the independent
replacement model, with unrelated music state unchanged.

The Amiga path allocates/converts the new sample, quiesces the old effect's
Paula channel before freeing its buffer, then reuses that channel. It derives
age from the same native 60 Hz clock used by selector 15. At this checkpoint,
multiple occupied slots and a free second slot remained named stops. The later
[two-effect acceptance](#two-effect-slot-allocation--2026-10-07) replaces those
stops with measured behavior, including the second slot's retained D1.W.
Ages beyond the measured counter range still stop explicitly.

The first complete native capture (`tmp/m2-effectreplace-native-full.log`)
returns past the former stop, with D0=0, original stack/register preservation,
one old effect stopped and one new effect started on channel 2. Its D1.W is
$7F15 for 233 elapsed native ticks. All 31,022 chip bytes match unsigned-to-signed
conversion plus silent reload; music voices are unchanged. All 42 prior startup
comparisons pass in `tmp/m2-effectreplace-regressions.log`; eight invalid original
captures and six invalid native captures are rejected. Complete-song regression
`tmp/m2-effectreplace-song-native.log` exits zero and passes all 3,736 timed note
events, both PCM/DMA variants, effect priority and final resource cleanup.

Maintained observers are `tools/mac_effectreplace.lua`,
`amiga/effectreplace.gdb` / `effectreplace_call.gdb` and
`tools/check_effectreplace.py`. The focused observer follows the normal game
route without input or timer patches. The final production build rejects the
newly identified second-slot case explicitly. Its focused capture
`tmp/m2-effectreplace-native-final.log` exits zero and passes the paired checker:
232 elapsed ticks, D1.W=$7F16, one stop/start, channel 1 retained and exact PCM.
The production no-float and 86-symbol link audits pass.

## Targeted effect stop (M2.3g44d1)

The Enter-skipped native pond route reached selector 18 at Core+$1828.
Original caller bytes at +$1820–$182B are `48780012206df9544e90508f`.
The original dispatch entry at driver+$7C branches to +$1CA, which reads the
packet pointer and calls +$36B0. That routine reads the identifier at packet+24,
scans exactly the configured effect slots, and marks every active matching slot
inactive. It preserves unmatched effects, sample pointers and all music state.
D0 returns zero, D1 returns the packet argument, and D2–D7/A0–A6 are preserved.

The ordinary Mac idle observer did not reach this timing-dependent call and
reported missing completion; `tmp/m2-driver18-reference.log` is not acceptance.
`tools/mac_driver18.lua` instead executes a bounded original-driver fixture:
play an effect normally, then invoke the unchanged Core stop call with that
packet. No original instructions are changed. The fixture exits zero in
`tmp/m2-driver18-fixture-reference.log`; `tools/check_driver18.py` checks live
original instruction bytes, registers/stack and the entire 12,360-byte state
transition. Identifier $8000 stops slot 6; all other state matches exactly.

The native implementation uses the existing DMA-safe `stopNativeEffect` path
for every active matching identifier. This disables the assigned Paula channel
before releasing its chip buffer and leaves music ownership untouched. Invalid
packets and uninitialized driver state remain named stops. The bounded `INTROSKIP=1` observer in `amiga/driver18.gdb` exits zero in
`tmp/m2-driver18-native.log`: active effect $8000 on channel 1 is stopped,
its buffer freed, the unrelated slot and all 48 bytes of music voice state
preserved, and the original caller continues to pond NewRgn at Dark+$33E0.
The paired checker passes D0/D1, stack and every preserved register. Book
batches remain zero. The no-float/88-symbol audits and affected sound-driver,
Paula sample, SONG/MIDI, clock and instrument host regressions pass.

Four corrupt/incomplete reference logs and four corrupt/incomplete native logs
are rejected. This verifies targeted effect cleanup, not perceived audio quality
or perceived quality of the complete intro; sequence completion itself now
passes M2.


## Remaining direct-call inventory — 2026-10-07

`tools/survey_driver_calls.py` scans every original CODE resource for the
unchanged A5-$6AC indirect-call wrapper and decodes its immediate selector
push. It finds 45 wrappers, all in CODE 3, using 25 selectors (0–25 except 3).
This is a static inventory, not a claim that every wrapper is reached during
ordinary gameplay. The selected runtime still rejects unsupported selectors
and unsupported arguments to otherwise implemented selectors.

| Selector | Direct CODE calls (JSR offsets) | Native contract |
| ---: | --- | --- |
| 0 | 3+$138C | Measured subset implemented |
| 1 | 3+$123E | Unmeasured; loud stop |
| 2 | 3+$1352 | Unmeasured; loud stop |
| 4 | 3+$145C, 3+$1FC8 | Measured subset implemented |
| 5 | 3+$1400 | Measured subset implemented |
| 6 | 3+$18CC, 3+$1ED2 | Unmeasured; loud stop |
| 7 | 3+$1292, 3+$140C | Measured subset implemented |
| 8 | 3+$1DCC | Measured subset implemented |
| 9 | 3+$1886 | Unmeasured; loud stop |
| 10 | 3+$1E0C | Unmeasured; loud stop |
| 11 | 3+$1E6E | Unmeasured; loud stop |
| 12 | 3+$18B8 | Unmeasured; loud stop |
| 13 | 3+$1346, 3+$137E, 3+$19CA | Measured subset implemented |
| 14 | 3+$149A | Unmeasured; loud stop |
| 15 | 3+$0FC8 | Measured subset implemented |
| 16 | 3+$0FE0 | Unmeasured; loud stop |
| 17 | 3+$17FC | Measured subset implemented |
| 18 | 3+$1828 | Measured subset implemented |
| 19 | 3+$13A8, 3+$16C2, 3+$16FE, 3+$1EE0, 3+$1F0A, 3+$1F22, 3+$1F72, 3+$1F88 | Measured subset implemented |
| 20 | 3+$17C8 | Measured subset implemented |
| 21 | 3+$1B98, 3+$1D46 | Measured subset implemented |
| 22 | 3+$1A74 | Measured subset implemented |
| 23 | 3+$1854 | Unmeasured; loud stop |
| 24 | 3+$15F4, 3+$1606, 3+$1618, 3+$162A, 3+$163C, 3+$164E, 3+$1660, 3+$1D60 | Measured subset implemented |
| 25 | 3+$1594 | Unmeasured; loud stop |
45 direct wrappers, 25 selector values; static presence is not gameplay reachability.


The remaining unmeasured wrapper contracts are 1, 2, 6, 9, 10, 11, 12, 14,
16, 23 and 25. Determine their ordinary-game reachability and measure any
reached contract before enabling it. Selector 24 also has several static
quality arguments beyond the measured $010B configuration; their presence
alone does not authorize silently accepting them. Original MDRV code remains
absent from the native runtime.


## SysBeep duration-1 contract — 2026-10-07

The original trap census contains two SysBeep ($A9C8) instructions:

- CODE 7 (Engine)+$4F48: a wrapper entered at +$4F40 pushes its caller's
  word argument with `move.w 8(a6),-(sp)`, calls SysBeep, then returns.
- CODE 13 (Dan2)+$3428: the routine at +$340A requests dialog 1000 through
  GetNewDialog. Only a null dialog result takes the beep branch, which pushes
  duration 1 before SysBeep and then returns zero. Successful creation skips it.

The owner-authorized `tools/mac_sysbeep_fixture.lua` redirects one original
indirect call through guest RAM to the unchanged Engine wrapper. It changes no
instructions, resources or CPU registers. This isolated contract fixture is not
ordinary gameplay evidence. Live wrapper bytes match the original resource.
Duration 1 consumes one stack word, returns D0=0 after three Mac ticks and
preserves D1–D7/A1–A6; A0 is volatile.

The native handler implements that duration as a short decaying Paula click,
independent of game sound/music gain. It uses a free channel or steals the oldest
music voice, retains game effect slots and buffers, and reserves its channel
until the three-tick synchronous call returns. Interrupts remain enabled. It
then disables DMA and frees the click; other durations retain `SYSBEEP DURATION`.
The original system alert waveform is not reproduced.

`amiga/sysbeep.gdb` with `BEEPPROBE=1 M5AUDIT=1 SONGPROBEID=135 PROBES=`
exercises the actual Line-A trap on the fixed 68030 with music and a genuine
active game effect. All measured preserved registers and stack consumption
pass. Music advances, one music voice is stolen, the game effect survives, and
Chip memory returns from its temporary 136-byte rounded allocation to exactly
599,704 bytes with zero accounting errors. `tools/check_sysbeep.py` pairs the
original and native captures, validates the click data and silence tail, and
requires normal exits plus all ownership/cleanup checks. Evidence is under
`tmp/m4/sysbeep/`; this establishes the contract, not listening acceptance.


## Fractional raw-effect rates — 2026-10-07

Selector 17 accepts a 16.16 sample rate. The authorized original 8,000.5 Hz
packet fixture returns the same ABI and initializes the full voice state with
step `((rate >> 5) / 11127) << 5`. Its 4,096-byte sample completes in 30 Mac
ticks. Native Paula uses the nearest hardware period at the requested pitch,
consistent with the existing integer-rate policy: period 443 PAL, 31 ticks of
DMA, cleanup at tick 32. The paired fixture compares the entire original state,
identical PCM conversion, natural sample end, native call ABI and freed DMA.
The fixture sources and checker are `tools/mac_effect_fixture.lua`,
`tools/check_effect_packet.py` and `amiga/effect_fraction.gdb`; native builds use
`EFFECTFRACTIONPROBE=1 PROBES=`. Evidence is `tmp/m4/effects/fraction/`.
Unsupported loop/segment/allocation variants remain named stops.


## Two-effect slot allocation — 2026-10-07

The authorized RAM-only `mac_effect_slots.lua` invokes the unchanged selector-17
call four times, changes only its packet ID and explicit age words, and uses
owned sample memory throughout. Original instructions/resources and CPU
registers remain untouched. The full original state and preserved ABI confirm:

- First free slot 6: D1.W=$7FFF.
- Free slot 7 after active slot 6: D1.W retains the earlier slot's age $7FFE.
- Both occupied, ages $7FF0/$7FF5: replace slot 6, return $7FF0.
- Both occupied with age $7FF0: replace the later slot 7, return $7FF0.

Native selection now follows those rules. On the fixed 68030, all four sample
buffers exactly match the original fixture PCM plus a silent word. Two active
effects use separate channels; replacements retain their channel and preserve
the unselected buffer. DMA is stopped before old buffers are freed. The ledger
holds exactly two 4,104-byte rounded allocations, then returns from 140,856 to
132,648 Chip bytes with zero errors after both effects stop.
`EFFECTSLOTSPROBE=1 M5AUDIT=1 PROBES=`, `amiga/effect_slots.gdb` and
`tools/check_effect_slots.py` reproduce this isolated acceptance. Evidence is
`tmp/m4/effects/slots/`. One emulator startup stall is excluded. Starting a song
uses the existing measured 6/3/1 configuration (one effect slot); the attempted
two-effect music fixture correctly failed its configuration positive control
and is not acceptance. Existing song fixtures cover effect priority there.

The original loop-count-3 fixture also completes: its shared counter advances
3→2→1→0. Driver+$2264–$226E decrements before deciding to repeat, so count 3
means two extra repeats, followed by the sample tail. This is measured original
behavior only. The subsequent zero/one/negative fixtures also pass (see the
[stream-boundary evidence](development.md#m4-loop-counters-and-dma-stream-boundary-evidence--2026-10-07));
native looping and long DMA segments remain open.


## Interrupt-driven effect loop playback — 2026-10-07

Selector 17 now accepts the measured live-counter loop contract through
`EffectDmaStream`. Conversion and allocation happen before DMA starts. The
Paula audio interrupt copies at most 128 converted bytes into alternating Chip
buffers and schedules the next fragment; user-mode service owns cleanup.
Counts zero/one consume the attack and complete tail, positive counts decrement
at boundaries, and negative counts repeat until the shared word is cleared.
Stop 18 and occupied-slot replacement 17 preserve that shared counter and
restore the previous interrupt vector/enable state when disposing the stream.

The paired six-case fixed-68030 suite checks exact PCM, counter progression,
original ABI, same-channel replacement, and zero Fast/Chip buffer leaks. See
[development evidence](development.md#m4-interrupt-driven-effect-loops--2026-10-07)
for timing, captures and isolated-fixture limits. Null-counter/zero-start loops,
samples over 131,070 bytes, and unsupported very old effect ages remain explicit
stops pending original measurements. This does not establish listening or
ordinary-gameplay acceptance for those isolated fixtures.
