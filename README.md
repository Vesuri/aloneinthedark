# Alone in the Dark — Amiga

An unofficial, **in-progress** Amiga port of the 1994 Macintosh **Alone In The
Dark 1.0** by Infogrames and Interplay.

The port follows the approach of the completed Vette! port: run the original
68k game code with an Amiga implementation of the Macintosh services it uses,
using native bitplanes, a hardware mouse pointer and Paula sound. The runtime
and Toolbox layer are carried over from Vette!; see
[docs/open-work.md](docs/open-work.md) for the remaining work.

## Current state

**M5 performance acceptance is complete.** Fixed-clock 68020/68030 checks,
phase profiling, interrupt timing and measured memory requirements are recorded
in [the M5 acceptance notes](docs/development.md#m5-cpu-full-profile-interrupt-and-memory-acceptance--2026-10-07).
A heap resource-movement fix reduces cold fight-music preparation from
24.47 to 7.13 seconds on the fixed-68020 diagnostic route; death music falls
9.48 to 3.11 seconds. This addresses loading pauses separately from frame rates.

The M5.2 rendering changes
raise fixed-clock idle rates from 10.01→10.42 FPS on 68020 and 11.29→12.23 on
68030, with timing scopes disabled. Across the full performance pass, the
five-leg walking route improves 2.75→3.47 FPS on 68020 and 2.94→3.84 on 68030.

| PAL configuration | Idle, timing scopes disabled | Walking, route diagnostic |
| --- | ---: | ---: |
| A1200, 68020 at 14.18758 MHz | 10.42 FPS | 3.47 FPS |
| A4000, 68030 at 15.6672 MHz | 12.23 FPS | 3.84 FPS |

Idle counts cover 3,000 emulated fields after ordinary Load; walking counts
cover five coordinate-gated legs in rooms 1, 4 and 5. These are different
diagnostic builds, not shipping-build rates. Walking poses vary slightly between
runs; the preceding 68030 route measured 3.95 FPS, so the latest changes do not
establish a gain on every walking leg. Warp accelerates the host run;
all results use fixed emulated CPU clocks. Intro frames match the Mac exactly,
and PAL/NTSC cursor checks and the independent scene-end audit pass.
[Methods, profile and evidence](docs/development.md#gameplay-frame-profile-and-first-optimisations--2026-10-07).

**M3.4 is complete.** Launch Apple Event delivery calls the original handler
in user mode, and all five implemented SANE operations pass integrated checks.
The reached `MONSTER`, `FIGHT` and `BDISK2` music tracks pass paired note-event
and complete native interrupt-playback checks. Natural MONSTER/FIGHT/BDISK2 calls
also pass the gameplay ABI checks. Scripted combat, death and a fresh Carnby
restart pass on both the reference 68030 and baseline A1200/68020.
Autonomous attic descent, oil-lamp pickup and empty-lamp Use pass paired
original/native state checks. A combined session reaches first-floor room 0
through the stair entrance; the extended 68020/68030 session opens the west door
and reaches the hallway. The 68020/68030 extension also enters the bedroom and
takes its key. The paired 68020/68030 cabinet extension uses that key, takes the saber
and equips it. Book Take, first-page Read and Escape return also pass paired
state and original artwork/text checks on both CPUs. Full book navigation and
normal completion also pass on both CPUs. Natural room 5 combat, enemy removal
and restored living manual control pass paired Mac/68020/68030 checks.
Post-combat wardrobe Search and hallway return also pass on the fixed 68030;
a room 5 → room 4 → western hallway bypass also passes paired Mac and fixed
68030 checks. An ordinary-Load first-floor circuit passes over ten minutes of active gameplay
on both acceptance CPUs. The continuous new-game route also passes on both CPUs; additional knockback
experiments are not acceptance gates.
The action-menu preview now runs at 2.07 updates/sec on the reference 68030
versus 1.65 on Mac; keyboard choices, hover, clicks and cancellation pass paired checks.
A later item-menu profile improves the rotating record preview from 2.74 to
4.00 updates/sec on the fixed 68030 (original Mac: 2.09), with identical
fixed-angle frame and palette bytes. This is a separate item/scene measurement.
[Profile and limits](docs/development.md#enemy-room-and-item-menu-profiling--2026-10-08).

**M3.3 (game interfaces) is complete for the reached routes.** New game and
save/load use the original engine UI inside 320×200. New-game and character-story
frames match the Mac exactly; save overwrite invokes no Mac warning. The size
chooser stays hidden and no menu bar is drawn. [Coverage and evidence](docs/game-interfaces.md).

**M3.2 (keyboard menus) is complete.** Right-Amiga+S/O/Q reaches Save, Load and
Quit; S/M toggles sound effects and music. The save-name prompt accepts text,
Quit restores the OS and audio hardware, and no menu bar is drawn. Paired Mac
checks verify menu results, visible feedback and viewport bounds.

**M3.1 (first-room controls) is complete.** On the 68030, New Game reaches
Carnby's attic; walking, Shift-running and fighting match the original Mac's
animation states. Held keys survive disk access. `INGAME=1` skips boot scenes
for testing; broader gameplay remains open.

**M2 (startup to intro) is complete.** On the baseline A1200/68020, the original
startup, full intro, menu and automatic demo run successfully. All nine demo
room/camera transitions and original PAK reads pass. The owner video confirms
the visible demo completes; the menu-to-landscape black interval is now about
eight seconds after fixing repeated sound conversion and memory movement.

The full intro passes all 956 frame conversions, including 840 book-animation
batches. State-matched Mac comparisons verify logos, title, credits, car and
frog; title/credits used placeholder artwork in that acceptance. Times/14 now uses
bundled original Mac bitmaps; its caption passes an exact pixel comparison. Normal Enter reaches the portraits and all eight letter pages.

PAL and NTSC pass native display, palette, pointer and audio-clock checks.
Owner screenshots verify the rendered colour ramp, test pattern and pointer
in both standards. Music passes all 3,736 timed events, sample bytes, effect
priority and cleanup. The full host suite and six baseline native regression
cases pass. Original game instructions and timers remain intact.

The fixed-clock 68030 intro-performance goal is complete. Compared with the
same-clock Mac IIx, most scene frame times are 1.1–1.9×; the worst measured
visit is 2.12× with explained cold preparation cost. Mansion entry takes
8.82 seconds versus 8.05 on Mac, and no current camera transition takes
15 seconds. Music uses a dedicated CIA timer with measured onset phase range
below 1 ms. Occasional captured audio gaps are FS-UAE host-buffer underruns;
four-channel voice stealing remains a documented Paula limitation.
See the current [scene timings and comparison limits](docs/intro-comparison.md).

**M4 audio is in progress.** All eight songs pass complete original/native
event, timing and allocation comparisons. SysBeep, fractional effect rates and
two-effect allocation/replacement, interrupt-driven loops and long effect
samples have paired contract checks. The [audio regression](docs/audio-regression.md)
collects these checks in one command. Audible all-song acceptance, remaining
driver paths and ordinary first-room effect comparisons remain open.
The deferred M1 system-window fixture still needs its specific rendered
acceptance; M2 screenshots do not substitute for it. See [open work](docs/open-work.md)
for the remaining scope and [development](docs/development.md) for evidence.

## Measured requirements

The verified configuration is an **AGA Amiga with a 68020 or better, 2 MB
Chip RAM and 8 MB Fast RAM**. Both fixed-clock 68020 and 68030 configurations
pass; 4 MB Fast RAM fails during startup even without diagnostic instrumentation.
Eight megabytes is the smallest verified standard expansion, based on a full
intro and first-floor endurance session, rather than an endgame guarantee.
Peak port allocations are 591,696 Chip bytes and 3,596,256 Fast bytes, excluding
the executable and OS; the game zones are already included in the Fast total.
[Memory measurements and limits](docs/amiga-arch.md#cpu-acceptance-and-memory-requirement).
The port supports only the 320×200 low-resolution mode. Mac dialogs and the menu bar are not drawn on the verified route;
new-game and save/load reuse the original engine interfaces. Newly reached
Mac dialogs must receive an in-game replacement.

No original game code or data, Kickstart image or WHDLoad binary is
distributed. You need your own copy of the original release.

## Building

The game uses `m68k-amiga-elf-gcc`, `elf2hunk` and vasm.

```sh
. amiga/env.sh
make -C amiga
```

For testing directly in Carnby's first room, use a clean build with
`make -C amiga clean` followed by `make -C amiga INGAME=1`. This skips all boot
scenes, menus and story; initialization and loading still run. Clean-build
without the option to restore the full startup. `SAVELOAD=1` automates save → move → load and Quit; paired Mac/A1200/68020 checks verify actual file IO and restored actor/room state. Use `DIAG_RUN_DIR=.run-saveload` to keep diagnostic saves separate. `EXPLOREROUTE=1` descends the attic stairs through ordinary controls and waits
for first-floor manual control; paired Mac/68020/68030 checks pass.
`SABERBREAK=1` extends the cabinet route through weapon attacks, actual breakage
and blade recovery; its 115-phase paired regression passes on both CPUs.
`SOUTHROOMS=1` exercises the hallway’s southern room entrance and released manual
gameplay; its paired 52-phase regression also passes on both CPUs.
`BOOKROUTE=1` continues lamp Take through bookcase Search, Book Take and the
first reading page, then returns to manual gameplay. `BOOKPAGES=1` extends that
route through all four pages, previous-page navigation and normal completion.
`COMBATROUTE=1` extends the bedroom key route through the naturally spawned
enemy, Close/Fight selection, door reopening, turning, attacks and victory;
its original Mac, baseline 68020 and fixed-clock 68030 checks pass.
`ROOM5COMBAT=1` extends the southern-room route through natural enemy activation,
Fight, aiming, kicks, damage and victory; its paired checks pass on both CPUs.
`ROOM4ROUTE=1` continues victory through room 4 into the western hallway;
its Mac/fixed-68030 checks pass, while baseline combat-knockback recovery remains
open.
`DEATHROUTE=1` runs ordinary
controls, returns toward the starting area, follows death and starts a fresh
Carnby game autonomously; its paired regression is documented in
[development.md](docs/development.md).

Unattended `amiga/diag_run.sh` uses maximum-speed `a4000-030` with warp by default.
On this ARM Mac it also prefers the verified local native emulator bundle when
available: the identical-binary pilot takes 32 versus 56 host seconds.
Explicit `FSUAE` overrides and fixed-clock acceptance retain their emulator.
See [development evidence](docs/development.md#emulator-speed-pilots--2026-10-06).
A checkout without that ignored bundle uses the installed emulator.
`AMIGA_CONFIG=a4000-060` selects an optional maximum-speed 68060 pilot;
full 68060 compatibility remains unverified.
Select `AMIGA_CONFIG=a1200-020` or `a4000-030-reference` explicitly for
baseline acceptance or timed comparisons, with `EXTRA_ARGS=--warp_mode=0`
for real-time runs. Normal interactive launch retains
the fixed-clock 68030 setup.

This builds `amiga/out/Alone.exe` without original game data. Extracting your
original archive, running under FS-UAE and debugging are covered in
[development.md](docs/development.md). The [documentation index](docs/README.md)
covers architecture and data formats.

## Credits and licensing

Alone in the Dark and its original assets belong to their respective copyright
holders. This is an unofficial fan port, not affiliated with or endorsed by them.
