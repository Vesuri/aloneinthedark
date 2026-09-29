# Native SoundMusicSys driver

D8 replaces the original software mixer at its driver interface. The native
startup implementation supplies Jnth 11 and the two measured initialization
calls. Production stops later before screen-size selection without loading any MDRV body.
Integrated acceptance through the second Times lookup remains pending; neither
this startup subset nor its reference capture proves audio acceptance.

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
`driver_startup.gdb` checks both original call sites, the installed stub, packet,
D0/D1, all thirteen preserved registers, stack and real native state. It also
requires the next exact Engine+$4782 screen-size-selection stop with no MDRV resident.
`check_native_driver.py LOG --status STATUS` rejects missing or duplicated
controls, wrong ordering, observer errors and nonzero/timeout status.

The first attempt to require the second Times call stopped at CountMItems and
was rejected. The original M0.2 trace likewise has menu initialization between
the driver and second font call. The full second-call acceptance is retained in
M2.1c3c2/M2.1c3 after intervening startup services. Menu-record initialization
now passes; the current stop is screen-size selection. No render,
audio or full startup success is claimed by this subset.

Run the native observer with the normal production build, then check its log:

```sh
. amiga/env.sh
make -C amiga
(cd amiga && GDBTAIL=110 EXTRA_ARGS=--warp_mode=1 \
  GDBSCRIPT=driver_startup.gdb ./diag_run.sh 60) \
  >tmp/m2-native-driver-calls.log 2>&1
run_status=$?
python3 tools/check_native_driver.py tmp/m2-native-driver-calls.log \
  --status "$run_status"
```
