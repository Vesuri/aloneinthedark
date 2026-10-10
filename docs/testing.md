# Testing

Source `amiga/env.sh` before native builds and runs. Shared file defaults and overrides
are listed in [development.md](testing.md#gameplay-routes). Never distribute the
original inputs, ROMs, reference captures or test saves.

## Host and native regression

```sh
. amiga/env.sh
make host-tests
make installer-test
AMIGA_CONFIG=a4000-030 amiga/regression.sh boot
AMIGA_CONFIG=a4000-030 amiga/regression.sh file-read
AMIGA_CONFIG=a4000-030 amiga/regression.sh file-write
AMIGA_CONFIG=a4000-030 amiga/regression.sh resource-exit
```

`make host-tests` checks pure helpers, static analysis, configuration and rejection
cases. Some original-byte checks additionally require extracted game data. `make
installer-test` requires the StuffIt archive in `tmp/`. `make regression` runs the
resource-exit, file-write/read, system-window, boot and resource-read fixtures. Each
native case clean-builds its flags, requires positive completion and rejects loud stops,
debugger failures and timeouts.

`amiga/regression.sh` exposes `boot`, `startup`, `stack`, `quit`, `stairs`, `intro`,
`resource-read`, `file-read`, `file-write`, `resource-exit`, `window-core` and `audio`.
It isolates existing saves/preferences, restores them on either success or failure, and
keeps fixture output in ignored emulator directories. Build and debugger logs are
`amiga/.run/regression-build.log` and `amiga/.run/gdb-out.log`. An early checkpoint is
evidence only for that endpoint.

The combined `startup` case uses the default `.run` directory, builds with
`PROBES=1`, and follows the original
font, menu, graphics and sound calls through the post-intro CopyBits return.
Its isolated directory receives the measured saved-preferences fixture: the first-run
path can omit the sound-effect calls that this observer pairs. Owner preferences and
saves are restored afterward; ordinary boot checks still cover missing preferences.
It deliberately runs the book because its text/line calls are part of the fixture.
Read-only observations at `aitd_line_a_trap_entry` include direct and general traps.
`trap_args.gdb` provides `mac-trap-args` for the shared register, exception-frame and
Pascal-stack view; `diag_run.sh` loads it automatically. User-mode service checks
retain their separate dispatcher boundary. Capture validation
checks RGB mutations/registers, font resources, text stacks/ports, and decoded AGA
pixels/palettes. Publication checks follow queued generations and require no visible
pointer or standalone MACPLAY frame. No historical splash frame numbers are assumed.

```sh
AMIGA_CONFIG=a4000-030 amiga/regression.sh startup
```

Owner-confirmed real hardware: A1200 with a 68040 at 40 MHz, MMU enabled and
32 MB Fast RAM. The corrected 0.91 build runs on this configuration.

Use `AMIGA_CONFIG=a1200-020` and `a4000-030-reference` for fixed-clock acceptance. The
full intro observer verifies original state and then waits for the exact queued frame
generation to reach the VBI. It must not assume a Toolbox return means a queued frame is
already on screen.

```sh
AMIGA_CONFIG=a4000-030-reference amiga/regression.sh intro
AMIGA_CONFIG=a1200-060 AMIGA_VIDEO=PAL amiga/regression.sh stairs
AMIGA_CONFIG=a4000-030-reference AMIGA_VIDEO=NTSC amiga/regression.sh quit
DIAG_LAUNCH=workbench AMIGA_CONFIG=a4000-030 amiga/regression.sh quit
AMIGA_CONFIG=a4000-030 amiga/regression.sh stack
```

The stairs and quit fixtures cover the eight non-JIT CPU configurations in PAL and NTSC.
The stairs fixture defaults to Carnby; set `EMILY=1` to select Emily through
normal menu input. Character identity is checked at every route checkpoint.
Acceptance requires three seconds of continuous idle/manual control after
descent with the movement keys released.
Quit also has Shell and Workbench startup/reply coverage. The Workbench fixture runs
under real Workbench but is a protocol fixture, not an icon double-click. The stack
fixture verifies a 4096-byte game-process stack; it does not change the separate
internal Mac or music stacks.

## CopyBits masks

`make host-tests` exercises cached and uncached CopyBits with every-byte region
mutations, handle-storage relocation, truncated capacity, cache eviction and larger
regions. Rejected copies must preserve the entire destination, including padding.
`tools/check_maskcopy.py` also models the original Mac captures. Its native check pairs
the original pose by default; `--native-unpaired` uses the native capture's own source,
mask and rectangle when CPU speed changes the pose, while retaining full destination,
ABI, source/record and publication checks.

For native checks, clean-build with `INTROSKIP=1 FIXEDRNG=1`. Run `maskcopy.gdb`,
`corridor_mask.gdb` and `scene_batches.gdb` through `amiga/diag_run.sh`; validate their
captures with `tools/check_maskcopy.py`, `tools/check_corridor_masks.py` and
`tools/check_scene_batches.py`. The corridor check pairs polygon geometry and exact
region bytes with the Mac; the scene check decodes every captured AGA back buffer.

The disposable negative fixture `mask_rejection.gdb` requires a clean build with
`INTROSKIP=1 FIXEDRNG=1 MASKREJECTPROBE=1`. This diagnostic-only hook warms the cache
with a real mask, then corrupts its terminating marker using guest instructions; the
shared debugger does not implement memory writes. The observer verifies the mutation
and requires a named CopyBits loud stop at `(Dark, $346C)` before any destination change:

```sh
GDBSCRIPT=mask_rejection.gdb DIAG_RUN_DIR=.run-mask-rejection amiga/diag_run.sh 600
python3 tools/check_mask_rejection.py amiga/.run-mask-rejection/gdb-out.log tmp --status "$?"
```

Use disposable preferences/saves for diagnostic runs; never run the negative fixture
in a live owner session. A timeout or interrupted run is a failure.

## Installer and WHDLoad

Build a production archive before testing its installation:

```sh
. amiga/env.sh
make release
python3 tools/install-data/test_installer_script.py --release=dist/AloneInTheDark-0.91.lha --fresh
python3 tools/install-data/test_installer_script.py --release=dist/AloneInTheDark-0.91.lha
python3 tools/install-data/test_amiga.py
python3 tools/test_whdload.py --mode timed --ticks 6000 --seconds 180
python3 tools/test_whdload.py --mode timed --cpu 68040 --mmu --ticks 6000 --seconds 180
```

The `--mmu` test requires a 68040 or 68060 without JIT or a custom machine
configuration. It verifies that WHDLoad actually enabled MMU translation;
a non-MMU run cannot check protection of WHDLoad's own exception table.
For startup and normal vector restoration, clean-build with `QUITPROBE=1`
and run `--mode quit --cpu 68040 --mmu --ticks 6000 --seconds 180`.

The Installer fixture supplies deterministic requester answers to the real Installer,
checks all extracted hashes and installed icons, and verifies preservation of saves and
unrelated drawers during an update. It uses a slave-copy fixture unless `--release`
supplies the actual release. Executing the slave is the separate WHDLoad suite.
`--reinstall` checks replacing damaged data; `--remove` checks the explicit removal
branch.

The `intro` regression also checks that the omitted MACPLAY picture and delay
are never entered, Infogrames is the first published frame, and palette slots
1, 15 and 191 retain the original splash palette colours at the book title.
These slots are deliberately inherited by subsequent palettes.

`test_amiga.py` runs the extraction helper with a real 4 KB stack and checks its
watermark. `test_whdload.py --mode timed` uses production code, requires the expected
WHDLoad timeout core, and verifies original resource reads, the embedded overlay and
the resload ABI. This is an explicit bounded startup test, not normal game exit. The `stairs`, `walking` and `escape` modes also inspect timeout cores; other modes require
a normal return:

| WHDLoad mode | Required executable / meaning |
| --- | --- |
| `smoke`, `boot`, `load` | Separate slave fixtures for resload, Kickstart and process startup |
| `stairs` | `EXPLOREROUTE=1 INTROSKIP=1`; fresh Carnby descent to manual floor 1 room 6 |
| `walking` | `STAIRSSAVE=1 INTROSKIP=1`; load the supplied automatic-descent save and observe 31 seconds with movement keys released |
| `escape` | `ESCAPEPROBE=1`; short and held Escape menu/resume cycles |
| `quit` | `QUITPROBE=1 INTROSKIP=1`; original Quit and OS/resource cleanup |
| `file-read` | `FILEPROBE=1`; exact read/seek/EOF/cache and bounded transfers |
| `save-load` | `SAVELOAD=1`; original Save, walk, Load and restored coordinates |
| `load-save` | `LOADONLY=1`; use `--save-source` from the prior run and `--no-preload` |

For unlimited 68040 reproduction use `--cpu 68040-NOMMU`, optionally `--jit`
and `--no-warp`. `--z3-memory-mb 32` adds 32 MB Zorro III RAM.
`--no-filelog` disables diagnostic FILELOG disk traffic when counting OS switches.
Allow `--ticks 15000 --seconds 240` for the full save/load route.
`--machine-config tmp/machine.fs-uae` instead imports the supplied hardware
settings (CPU, model, memory, RTG and video timing), retaining isolated test
disks, ROM overrides and output paths. `FSUAE` selects the emulator executable.
Use the official emulator and warp off for the high-speed stairs case: warp
changes the number of instructions executed per emulated field.
Stairs/walking/Escape fixtures
disable FILELOG to avoid its overhead and inject ordinary raw key states; they
do not cover the physical keyboard handshake. A missing core is inconclusive.

To reproduce the supplied automatic-descent case, keep the save and machine
configuration local and run:

```sh
. amiga/env.sh
make -C amiga clean
make -C amiga -j4 STAIRSSAVE=1 INTROSKIP=1
python3 tools/test_whdload.py --mode walking \
  --save-source 'tmp/walking/Saved Games' --machine-config tmp/machine.fs-uae \
  --no-warp --ticks 3500 --seconds 180
```

The fixture uses the original Load interface; it never rewrites actor state.
Its trace records ticks, completed scenes, character, coordinates, heading,
animation, floor, room, track mode/position, vertical step and held cursor keys.
It requires a loaded automatic stair state, zero movement input throughout and
five final idle/manual samples downstairs. Consecutive samples must also show
scene progression bounded by the video rate. Zero OS returns is valid when the
whole game fits WHDLoad's PRELOAD cache.

Clean-build between flag sets. `--check-stack` additionally needs `STACKPROBE=1`. Use a
diagnostic executable with a matching observer, not the production build for a
probe-only completion check. WHDLoad tests keep their own volumes and core dumps under
`tmp/whdload-test-*` and terminate only their emulator process.

`make release-check` runs host/extractor tests, native and WHDLoad production startup,
two clean executable builds, independent LHA CRC/member/icon/version validation and
deterministic repackaging. `tools/test_release.py` rejects corrupt packages and
diagnostic build receipts. Runtime payloads are never bundled; `tools/check_release.py`
enforces the exact package contents.

## Gameplay routes

For focused tests, clean-build with the relevant option and use the matching
`amiga/*.gdb` observer. The route probes drive original controls and require actual
game-state transitions. Inspect the observer and `tools/check_*.py` checker for
input-save/reference prerequisites before starting a run.

| Build flag | Observer | Coverage |
| --- | --- | --- |
| `INGAME=1` | `ingame.gdb` | Direct startup into the attic |
| `SAVELOAD=1` | `saveload.gdb` | Save, move, Load, restored state and Quit |
| `DEATHROUTE=1` | `death_route.gdb` | Death and new-game restart |
| `EXPLOREROUTE=1` | `explore_route.gdb` | Attic descent to living first-floor manual control |
| `LAMPROUTE=1` | `lamp_route.gdb` | Lamp pickup through ordinary interaction |
| `LAMPUSE=1` | `lamp_use.gdb` | Empty-lamp Use and feedback |
| `BOOKROUTE=1`, `BOOKPAGES=1` | `book_route.gdb`, `book_pages.gdb` | Book pickup, all reading pages and return |
| `COMBATROUTE=1` | `combat_route.gdb` | Bedroom enemy activation, aiming, attacks and victory |
| `ROOM5COMBAT=1` | `room5_combat.gdb` | Southern-room enemy fight and damage |
| `SABERBREAK=1` | `saber_break.gdb` | Saber attacks, breakage and blade recovery |
| `FIRSTFLOORLOAD=1` | `firstfloor_load.gdb` | Ordinary Load of the first-floor save |
| `FIRSTFLOORCIRCUIT=1` | `newgame_circuit.gdb` | Continuous new-game first-floor route |
| `FULLPLAY=1` | `fullplay.gdb` | Diagnostic checkpoint/command interface for assisted full-route testing |

For action-menu behavior use `ACTIONCLICK=1` / `action_clicks.gdb` and `ACTIONNAV=1` /
`action_navigation.gdb`. The keyboard click path preserves a held action while tracking
a released Enter; released input and matching focus are necessary when comparing menu
frames. The game's preview pane can be at the same angle while labels differ because a
different control has focus.

`LINEAPROBE=1` with `quick_traps.gdb` checks direct MoveTo, PenSize and PenMode
against all 15 input registers, CCR and Pascal stack cleanup, then installs a PenMode
patch, calls through its original, and restores the direct entry. GetZone additionally
checks patch installation through an OS alias and its A0 result. The fixture exits
before the older `line_a.gdb` bring-up sequence.

For endurance and profiling, use the ordinary first-floor save with `FIRSTFLOORLOAD=1
INTROSKIP=1`; enable `FIRSTFLOORCIRCUIT=1` or `M5AUDIT=1` only when required by the
observer. `vbl_latency.gdb` uses `INGAME=1` and the reference 68030 to compare callback
lateness over the same first-room scenes 60–160; it reads the callback's virtual Ticks
shadow against the live clock. `gameplay_sample.gdb`, `sample_gameplay.py` and
`summarize_gameplay_profile.py` provide sampled profiles; `amiga/aprof.sh` gives exact
cycle profiles of book and first-room intervals. `m5_circuit.gdb` and
`check_m5_audit.py` check memory, interrupts and completion. Use the saved-preferences
fixture from `check_startup_prefs.py` so the session includes music and effects;
protect existing preferences and saves with `regression_preferences.py`. See
[performance](performance.md) for measurement interpretation.

## Display, cursor and audio

The display/cursor fixture clean-builds with `AGAPROBE=1 CURSORPROBE=1 C2PVERIFY=1`. Run
`GDB_ENTRY=aitdRunAgaProbe GDBSCRIPT=cursor_probe.gdb amiga/diag_run.sh 120` in PAL and
NTSC, then run `tools/check_cursor_capture.py` with `--inversion`, `--video PAL|NTSC`,
`--status` and the captured folder. The checker verifies all palette entries, pixels,
pointer clipping and inversion, movement without a new game frame, and release. Keep
original/native capture pairs separate.

[Audio regression](audio-regression.md) documents fresh song capture, sample fixtures
and retained-reference prerequisites. `CIAMUSIC=1` is the default; `CIAMUSIC=0` is a VBI
scheduling diagnostic. `effect_loop_matrix.sh` covers zero/finite/infinite loop counters
and native DMA boundary behavior. Fixtures that write guest RAM establish driver
contracts, not ordinary gameplay coverage.

## Gameplay coverage

The completed whole-game route covers all eight engine floors, representative rooms,
combat, inventory, reading, maze lamp, ending and return to the title/ intro loop on the
Mac and Amiga. State-paired comparisons cover complete 320×200 viewports and palettes,
including active actor poses. Original Times 14 and 36 glyphs cover reached visible
text, including pause and resume.

This is assisted autonomous coverage, not an unassisted solution of every puzzle or a
comparison of every frame. Assistance includes health/position changes, selected enemy
removals, granted items and navigation shortcuts. The native tree sequence used a
private life-script fixture; the later original Mac trace also verified ordinary
talisman Put and lamp Throw. No such assistance is present in production builds or
release data. Death/restart and post-ending return have separate positive checkpoints
and no accepted loud stop.

The full Mac trap audit found 152 trap words at 564 byte-attributed original sites, all
inside the maintained census. The general M0 UI reporter did not pass its differently
scoped seven-marker gate; full-route evidence was reviewed separately, including
recovered controller timeouts. Do not reinterpret that reporter failure as a passing M0
regression or weaken its gate.

The remaining return-to-attic and version-specific glitch questions are in [open
work](open-work.md). Initial stair observations are in [mac-stairs.md](mac-stairs.md).
Original Macintosh.js is excluded from that work.

## Solid drawing and buffer synchronization

`make host-tests` includes span/rectangle guard bytes for all alignments, aligned and
odd strides, plus signed line clipping and dirty bounds. To compare the span rasterizer
with the original Mac, capture `tools/mac_lineto.lua` using the documented headless
reference command, then run `tools/check_line8.py --reference LOG --status STATUS`.
The fixture covers 80 slope, clipping and reversal cases.

`BOOKPAGES=1` with `book_pages.gdb` covers the ordinary book pickup/Read route and all
pages in both directions; `tools/check_book_pages.py` compares complete Mac page
artwork and text. `BOOKPROFILE=1` with `book_profile.gdb` captures a fixed opening-fold
position for `tools/check_book_profile.py`, which compares an unchanged native build,
the candidate, the original Mac and the decoded AGA publication. Use separate capture
folders and retain the actual runner status for every check.

## Opening frame boundaries and dirty-area audit

Use a clean ordinary build with `GDBSCRIPT=frame_pacing.gdb` and the bounded
`amiga/diag_run.sh 600` runner, then validate its full log:

```sh
python3 tools/check_frame_pacing.py --log amiga/.run/gdb-out.log
```

For native display cadence on the reference 68030, clean-build `FRAMEAUDIT=1`
and run the lightweight observer (only startup/end breakpoints):

```sh
AMIGA_CONFIG=a4000-030-reference GDBSCRIPT=book_cadence.gdb amiga/diag_run.sh 600
python3 tools/check_frame_pacing.py --core tmp/book-cadence.bin
```

Require a successful runner exit and `PASS complete book audit` before checking the
capture. The report records all 840 steps at their actual VBI publication; the checker
validates coordinate-derived conversion bounds and separates folds from reading gaps.
Warp accelerates host execution; the reported intervals use emulated fields.

For actual display cadence on a fast emulator without GDB, clean-build
`FRAMEAUDIT=1` and run `tools/test_whdload.py --mode timed --no-warp --ticks 6500
--seconds 300 --machine-config tmp/test-machine.fs-uae`. Select the intended emulator
with `FSUAE`; the machine configuration supplies hardware settings only. The report
contains the first 1,024 publications and each one's actual VBI field, book/scene step,
dirty and converted bounds, rectangle count and converted area. Check the emitted
fixture's `game/.whdl_expmem` with:

```sh
python3 tools/check_frame_pacing.py --core tmp/fixture/game/.whdl_expmem --require-field-rate
```

`--require-field-rate` is for unlimited-speed acceptance, not fixed-clock machines.
It requires every within-animation display interval to be one field. Page-reading
holds are reported separately. Use `amiga/regression.sh intro` for the independent
full-frame C2P correctness check. For phase costs at one original fold step, clean-build
`BOOKPROFILE=1` (without `PROFILEFRAME`) and use `GDBSCRIPT=book_profile.gdb`.
Clean-build again without diagnostics before packaging a release.
