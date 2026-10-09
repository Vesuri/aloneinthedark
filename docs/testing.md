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

`amiga/regression.sh` exposes `boot`, `stack`, `quit`, `stairs`, `intro`,
`resource-read`, `file-read`, `file-write`, `resource-exit`, `window-core` and `audio`.
It isolates existing saves/preferences, restores them on either success or failure, and
keeps fixture output in ignored emulator directories. Build and debugger logs are
`amiga/.run/regression-build.log` and `amiga/.run/gdb-out.log`. An early checkpoint is
evidence only for that endpoint.

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

## Installer and WHDLoad

Build a production archive before testing its installation:

```sh
. amiga/env.sh
make release
python3 tools/install-data/test_installer_script.py --release=dist/AloneInTheDark-0.90.lha --fresh
python3 tools/install-data/test_installer_script.py --release=dist/AloneInTheDark-0.90.lha
python3 tools/install-data/test_amiga.py
python3 tools/test_whdload.py --mode timed --ticks 6000 --seconds 180
```

The Installer fixture supplies deterministic requester answers to the real Installer,
checks all extracted hashes and installed icons, and verifies preservation of saves and
unrelated drawers during an update. It uses a slave-copy fixture unless `--release`
supplies the actual release. Executing the slave is the separate WHDLoad suite.
`--reinstall` checks replacing damaged data; `--remove` checks the explicit removal
branch.

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

For endurance and profiling, use the ordinary first-floor save with `FIRSTFLOORLOAD=1
INTROSKIP=1`; enable `FIRSTFLOORCIRCUIT=1` or `M5AUDIT=1` only when required by the
observer. `gameplay_sample.gdb`, `sample_gameplay.py` and
`summarize_gameplay_profile.py` provide sampled profiles; `m5_circuit.gdb` and
`check_m5_audit.py` check memory, interrupts and completion. See
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
