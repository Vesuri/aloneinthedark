# Alone in the Dark — Amiga

An unofficial Amiga port of the 1994 Macintosh **Alone In The
Dark 1.0** by Infogrames and Interplay.

The port follows the approach of the completed Vette! port: run the original
68k game code with an Amiga implementation of the Macintosh services it uses,
using native bitplanes, a hardware mouse pointer and Paula sound. The runtime
and Toolbox layer are carried over from Vette!; see
[docs/open-work.md](docs/open-work.md) for the remaining work.

## Current state

The full-game acceptance reaches the ending and returns to the title/intro
loop on both the original Mac and Amiga. The authorized test cheats, comparison
limits and exact coverage are recorded in the
[final M6 audit](docs/development.md#m6-final-completion-audit--2026-10-08).
Music runs from a CIA interrupt; the hardware mouse pointer follows the VBI.
The [performance measurements](docs/intro-comparison.md) distinguish rendering,
scene loading and emulator audio buffering.

The original-data installer, WHDLoad launcher and release package are based on
Vette. Native and WHDLoad read/seek/EOF/cache checks pass; WHDLoad also passes
original Save/Load, a fresh-process reload without PRELOAD, and clean quit.
The [open-work queue](docs/open-work.md) lists only unresolved work.

## Installation

Extract `AloneInTheDark-1.0.lha` and open `Install` using Amiga Installer 43 or
newer. Install WHDLoad 17 or newer and provide a matching Kickstart 3.1 image
and RTB first. The installer accepts `kick40068.A1200`, `kick40068.A4000` or
`kick40063.A600` in `Devs:Kickstarts` or `WHDCOMMON:`.

Supply your original, unmodified Macintosh `AloneInTheDark.img_.sit` archive
when prompted. The helper verifies the archive and all 74 extracted files;
you do not need to unpack it first. Allow 24 MB free in the temporary drawer
and 8 MB at the destination. Use a disk temporary drawer on an 8 MB machine.
The helper needs about 2.7 MB of working allocations in addition to its code
and the OS. No original game data, ROMs or WHDLoad binary are included.

Launch the installed `AloneInTheDark` icon. Saved games live in `Saved Games`
and survive an in-place update. The installer's explicit **Remove** option
deletes the existing installation, including saves.

## Controls

- Arrow keys: move and turn; hold Shift to run.
- Enter: action/inventory menu; Escape: back/cancel where supported by the game.
- Hold Space with a direction to perform the selected action.
- S/M: toggle sound effects/music.
- Right-Amiga+S/O/Q: Save, Load, Quit.
- F10: exit WHDLoad.

## Measured requirements

The verified configuration is an **AGA Amiga with a 68020 or better, 2 MB
Chip RAM and 8 MB Fast RAM**. Both fixed-clock 68020 and 68030 configurations
pass; 4 MB Fast RAM fails during startup even without diagnostic instrumentation.
Eight megabytes is the smallest verified standard expansion, based on a full
intro and first-floor endurance session, with acceptance limits documented below.
Peak port allocations are 591,696 Chip bytes and 3,596,256 Fast bytes, excluding
the executable and OS; the game zones are already included in the Fast total.
[Memory measurements and limits](docs/amiga-arch.md#cpu-acceptance-and-memory-requirement).
WHDLoad startup, attic gameplay and Save/Load also pass on a 68030 with that
physical memory configuration; additional Fast RAM permits more PRELOAD caching.
The game needs a normal **4 KB process stack**. Shell, Workbench and WHDLoad
measure about 2.1 KB through gameplay, Save/Load and exit. Private Mac/audio
stacks are allocated internally; no Shell `Stack` increase is required.
The port supports only the 320×200 low-resolution mode. Mac dialogs and the menu bar are not drawn on the verified route;
new-game and save/load reuse the original engine interfaces. Newly reached
Mac dialogs must receive an in-game replacement.

No original game code or data, Kickstart image or WHDLoad binary is
distributed. You need your own copy of the original release.

## Building

The game uses `m68k-amiga-elf-gcc`, `elf2hunk` and vasm.
The slave additionally uses the WHDLoad SDK and Amiga NDK headers. Packaging
uses LHa for UNIX for LH5 encoding and Lhasa's `lha` for independent decoding.
Set `LHA` to the encoder's path if it is not installed as `lha-compress`.

```sh
. amiga/env.sh
make -C amiga
```

`make release` clean-builds and produces `dist/AloneInTheDark-1.0.lha`.
`make release-check` runs host and extractor tests, two clean production builds,
native and WHDLoad startup checks, and two byte-identical archive builds.
It verifies exact package contents, headers, CRCs, version strings and icons,
rejects diagnostic build flags, and includes only port-owned release files.
Local original data, ROMs, the emulator and Workbench are needed for native tests.
See [extractor dependencies and licensing](tools/install-data/README.md).

For testing directly in Carnby's first room, use a clean build with
`make -C amiga clean` followed by `make -C amiga INGAME=1`. This skips all boot
scenes, menus and story; initialization and loading still run. Clean-build
without the option to restore the full startup. `SAVELOAD=1` automates save → move → load and Quit; paired Mac/A1200/68020 checks verify actual file IO and restored actor/room state. Use `DIAG_RUN_DIR=.run-saveload` to keep diagnostic saves separate. `EXPLOREROUTE=1` descends the attic stairs through ordinary controls and waits
for first-floor manual control; paired Mac/68020/68030 checks pass.
Run `AMIGA_CONFIG=a1200-060 AMIGA_VIDEO=PAL amiga/regression.sh stairs` for
the maintained descent check. It passes all eight named CPU configurations
in PAL and NTSC, with uncapped pacing and measured guest-time FPS.
Run `AMIGA_CONFIG=a4000-030-reference AMIGA_VIDEO=PAL amiga/regression.sh quit`
for the quit/cleanup check. Set `DIAG_LAUNCH=workbench` to test the Workbench
startup-message protocol with real Workbench loaded; `WORKBENCH_ADF` selects
the external OS disk. This is a protocol fixture, not an icon double-click.
Both launch paths pass on all eight configurations in PAL and NTSC.
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
its Mac/fixed-68030 checks pass. See the later M6 audit for full-play coverage.
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

The independent installer/extractor helper is LGPL-2.1-or-later; its license
is included as `LICENSE.LGPL.txt` in the release. Source and build instructions
are in [tools/install-data](tools/install-data/README.md).
