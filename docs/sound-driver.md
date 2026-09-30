# Native SoundMusicSys driver

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
logical effects, idempotence and music isolation. No physical channel has been
assigned on the reached route. The runtime now quiesces/frees assigned Paula channels before changing the
logical state, using the same path verified by selector 17 natural completion.
The model rejects callers that bypass hardware cleanup. An actual active
selector-22 call and music isolation remain part of M4.3 acceptance. This call produces no audio event on the measured route.

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

Loops, fractional rates, oversized samples and voice/channel stealing remain
named stops. They are not replaced by one-shot playback or silently dropped.
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
