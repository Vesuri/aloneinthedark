# Alone in the Dark — Amiga

An unofficial, **in-progress** Amiga port of the 1994 Macintosh **Alone In The
Dark 1.0** by Infogrames and Interplay.

The port follows the approach of the completed Vette! port: run the original
68k game code with an Amiga implementation of the Macintosh services it uses,
using native bitplanes, a hardware mouse pointer and Paula sound. The runtime
and Toolbox layer are carried over from Vette!; see
[docs/open-work.md](docs/open-work.md) for what works today.

## Current state

The executable builds and runs the original CODE 1 startup on the 68020. Its
75,616-byte A5 globals match the host model exactly. The original segment loader
relocates Core and reaches `main`; initialization then stops explicitly at
`MEMORY MANAGER / NEWHANDLECLEAR`, Engine+$004A. The game is not playable yet.
Other processors and performance work remain deferred.

The M0 tools checkpoint includes the trap census, original Mac runtime/frame
evidence and a regression harness. Host checks, native Line-A/stack/trap-patch
probes and link audits pass. Adapting the `boot` regression observer to Core's
on-demand loading is the next queue item, M1.3a.

## Requirements (provisional)

The original code uses 68020 instructions and 256-color graphics, so the target
is an AGA Amiga with a 68020 or better and, provisionally, 4 MB of fast RAM (the
original asks for 3 MB). The port supports only the 320×200 low-resolution
mode.

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
