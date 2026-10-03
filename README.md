# Alone in the Dark — Amiga

An unofficial, **in-progress** Amiga port of the 1994 Macintosh **Alone In The
Dark 1.0** by Infogrames and Interplay.

The port follows the approach of the completed Vette! port: run the original
68k game code with an Amiga implementation of the Macintosh services it uses,
using native bitplanes, a hardware mouse pointer and Paula sound. The runtime
and Toolbox layer are carried over from Vette!; see
[docs/open-work.md](docs/open-work.md) for the remaining work.

## Current state

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

Intro performance is the current priority before M3, using a fixed-clock 68030
and the original Mac IIx as reference. Scene preparation has improved, but car
animation and the first frog frame still lag behind the Mac. See the current
[timings and comparison limits](docs/amiga-arch.md#intro-performance-comparison-2026-10-03).

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

This builds `amiga/out/Alone.exe` without original game data. Extracting your
original archive, running under FS-UAE and debugging are covered in
[development.md](docs/development.md). The [documentation index](docs/README.md)
covers architecture and data formats.

## Credits and licensing

Alone in the Dark and its original assets belong to their respective copyright
holders. This is an unofficial fan port, not affiliated with or endorsed by them.
