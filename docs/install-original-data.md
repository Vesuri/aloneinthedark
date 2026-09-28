# Original-data extraction

The port reads the original files; nothing from the release is embedded in the
executable or the repository. The known release is `AloneInTheDark.img_.sit`
(sha256 `92a5c1f9…6352db2`), nested four deep:

| Layer | Format | Opened with |
| --- | --- | --- |
| `AloneInTheDark.img_.sit` | StuffIt 5, Arsenic | `unar` |
| `Alone In The Dark.img` | raw HFS volume, type/creator `rohd`/`ddsk`, 7.99 MB | `hfsutils` |
| `Alone in the Dark Installer` | StuffIt InstallerMaker application (`APPL`/`STi0`) | `hcopy -m` |
| its data fork (6,050,022 bytes) | classic StuffIt 1.x archive with magic `STi2` | `unar`, after patching |

The installer's data fork is a classic StuffIt archive in every respect except
its first four bytes: the 22-byte header carries the total length (equal to the
fork size) and the `rLau` marker at offset 10, and entries use the classic
112-byte header with methods 0 (stored), 13 (LZ+Huffman) and 32/33 (folder
start/end). Replacing `STi2` with `SIT!` lets `unar` extract all 39 entries with
every CRC verified. The installer's own code (the InstallerMaker engine in its
resource fork) is never run.

`tools/extract_original_data.py` performs the whole chain and writes:

- `Alone In The Dark`: the application's raw resource fork, 1,424,934 bytes,
  sha256 `b5848c06…a6352db2`. `unar -k visible` writes forks as AppleDouble;
  the tool unwraps entry 2. Its data fork is empty.
- `Alone Data/`: 32 data-fork files: `Camera00-07.PAK`, `Etage00-07.PAK`,
  `List*.PAK`, `ITD_Ress.PAK`, `Present.PAK`, `EndSeq.PAK`, `USA.PAK`,
  `Test.PAK`, and the `Defines`, `Objets`, `Priority` and `Vars` `.ITD` tables.

The payload also holds `ListBod2.PAK` at its root, an empty `Alone Saved Games`
folder, `Quick Reference` and a registration application. Whether the installer
places `ListBod2.PAK` in the data folder is unknown; the tool does not copy it.

The HFS volume also holds the manual (PDF), `Quick Reference` and a "Stair Bug
Fix" folder: G3Throttle, with a note that the storeroom stairs fail on a fast
Mac after collecting the loft items. That is a timing-sensitive original bug for
the port to reproduce or pace around, not a reason to change game logic.

A release installer will need the same chain without `unar`/`hfsutils`. Vette's
standalone helper (`~/Documents/Vette/tools/install-data`) already decodes
StuffIt method 13 and is the intended starting point.
