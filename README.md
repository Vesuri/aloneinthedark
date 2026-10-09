# Alone in the Dark — Amiga

An unofficial Amiga port of the 1994 Macintosh **Alone in the Dark 1.0** by
Infogrames and Interplay. Explore the mansion of Derceto as Edward Carnby or
Emily Hartwood, solving puzzles and surviving its creatures.

The port runs the original 68k game code with an Amiga implementation of the
Macintosh services it uses. Graphics use AGA bitplanes; music and effects use Paula.
The game runs through the ending and
returns to the title sequence. See the [coverage and limits](docs/testing.md#gameplay-coverage)
and [open work](docs/open-work.md) for the remaining investigations.

Current Amiga release: **0.90 (09.10.2026)**.

## Requirements and installation

- AGA Amiga, 68020 or better; **68040 or better strongly recommended**.
- **2 MB Chip RAM and 8 MB Fast RAM**; more Fast RAM permits more PRELOAD caching.
- WHDLoad 17+, Installer 43+, and a supported Kickstart 3.1 image with its RTB.
- 8 MB destination space and 24 MB temporary disk space.

Extract `AloneInTheDark-0.90.lha`, open its **Alone in the Dark Install** drawer
and run **Install**. Select the destination, temporary drawer and the
[AloneInTheDark.img_.sit StuffIt archive](https://www.macintoshrepository.org/download.php?id=5338).
Leave it compressed: the included helper extracts and verifies all 74 files.
Use a disk temporary drawer on an 8 MB machine.

Start the installed **AloneInTheDark** icon. The opening starts with Infogrames;
the standalone MACPLAY splash is omitted, while the book credits remain. Saved games live in `Saved Games`
and survive an in-place update. The installer's explicit **Remove** option
also deletes saved games. The game uses the normal **4 KB process stack**.

No original game code/data, Kickstart image or WHDLoad binary is distributed.
See [the release ReadMe](release/ReadMe) for supported ROM filenames and full
installation instructions.

## Controls

| Key | Action |
| --- | --- |
| Arrow keys | Move and turn |
| Shift + movement | Run |
| Enter | Action/inventory menu |
| Escape | Back/cancel where supported by the game |
| Space + direction | Perform the selected action |
| S / M | Toggle effects / music |
| Right-Amiga + S / O / Q | Save / Load / Quit normally |
| F10 | Immediate WHDLoad exit, bypassing normal game cleanup |

The port displays the 320×200 game viewport. The Mac menu bar and screen-size
chooser are suppressed; keyboard commands and the original engine interfaces
provide the reached game actions. In FS-UAE, disable keyboard joystick
emulation if it consumes the arrow keys; the supplied launchers do this.

## Building

The game uses `m68k-amiga-elf-gcc`, `elf2hunk` and vasm. The WHDLoad slave also
needs external WHDLoad SDK and Amiga NDK includes. Release packaging needs
Python 3, an LH5-capable LHa encoder and Lhasa's `lha` for independent validation.

```sh
. amiga/env.sh
make release
```

This builds `dist/AloneInTheDark-0.90.lha` without original game data. For a
standalone executable, use `make -C amiga`. Tool paths, environment overrides,
local data and emulator setup are in [development.md](docs/development.md).
The [testing guide](docs/testing.md) covers regression and release checks.
The [documentation index](docs/README.md) covers architecture and data formats.

## Credits and licensing

Alone in the Dark and its original assets belong to their respective copyright
holders. This is an unofficial fan port, not affiliated with or endorsed by them.
The compatibility runtime follows the Vette! port; framework and C2P provenance
are recorded with their source.

The standalone extraction helper is LGPL-2.1-or-later; see
[its license and provenance](tools/install-data/README.md).
That license applies to the helper only, not to the original game.
