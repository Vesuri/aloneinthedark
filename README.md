# Alone in the Dark — Amiga

An unofficial, **in-progress** Amiga port of the 1994 Macintosh **Alone In The
Dark 1.0** by Infogrames and Interplay.

The port follows the approach of the completed Vette! port: run the original
68k game code with an Amiga implementation of the Macintosh services it uses,
using native bitplanes, a hardware mouse pointer and Paula sound. The runtime
and Toolbox layer are carried over from Vette!; see
[docs/open-work.md](docs/open-work.md) for the remaining work.

## Current state

**M3.1 (first-room controls) is complete.** On the 68030, New Game reaches
Carnby's attic; walking, Shift-running and fighting match the original Mac's
animation states. Held keys survive disk access. `INGAME=1` skips boot scenes
for testing; menus, dialogs and broader gameplay remain open.

**M2 (startup to intro) is complete.** On the baseline A1200/68020, the original
startup, full intro, menu and automatic demo run successfully. All nine demo
room/camera transitions and original PAK reads pass. The owner video confirms
the visible demo completes; the menu-to-landscape black interval is now about
eight seconds after fixing repeated sound conversion and memory movement.

The full intro passes all 956 frame conversions, including 840 book-animation
batches. State-matched Mac comparisons verify logos, title, credits, car and
frog; title/credits retain documented differences in the owned placeholder
font artwork. Normal Enter reaches the portraits and all eight letter pages.

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

Gameplay, save/load and broader music support remain later milestones. The
separately deferred M1 system-window fixture still needs its specific rendered
acceptance; M2 screenshots do not substitute for it. See [open work](docs/open-work.md)
for the remaining scope and [development](docs/development.md) for evidence.

## Requirements (provisional)

The original code uses 68020 instructions and 256-color graphics, so the target
is an AGA Amiga with a 68020 or better and, provisionally, 4 MB of fast RAM (the
original asks for 3 MB). The port supports only the 320×200 low-resolution
mode. Mac dialogs and the menu bar will not be drawn; game choices such as
new-game and save/load use replacement in-game interfaces.

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
without the option to restore the full startup.

This builds `amiga/out/Alone.exe` without original game data. Extracting your
original archive, running under FS-UAE and debugging are covered in
[development.md](docs/development.md). The [documentation index](docs/README.md)
covers architecture and data formats.

## Credits and licensing

Alone in the Dark and its original assets belong to their respective copyright
holders. This is an unofficial fan port, not affiliated with or endorsed by them.
