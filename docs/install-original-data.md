# Original-data extraction

For the Amiga release, run `Install` from the release archive. The bundled
`AitdInstallData` helper reads this archive directly, checks the known original
payload and verifies all 74 output files. It needs neither `unar`, `hfsutils`,
Python nor xadmaster on the Amiga. Its source, bounds, license and native tests
are documented in [tools/install-data](../tools/install-data/README.md).
The following host workflow is the independent development/reference extractor.

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
- `Alone Data/`: 33 data-fork files: `Camera00-07.PAK`, `Etage00-07.PAK`,
  `List*.PAK`, `ITD_Ress.PAK`, `Present.PAK`, `EndSeq.PAK`, `USA.PAK`,
  `Test.PAK`, and the `Defines`, `Objets`, `Priority` and `Vars` `.ITD` tables.

The payload holds `ListBod2.PAK` at its root, but the **original installer moves
it into `Alone Data`**. This was verified by running its unchanged data/resource
forks on an isolated System 7.5.5 volume: the installer displays successful
completion and the resulting ListBod2 is 268,430 bytes, SHA-256
`5c552161db462f80e82346494a304d133ca502c92ab299a77b82ca988fd1893e`.
The installed layout contains 33 data files / 5,584,424 bytes, three root files
(application, Quick Reference, registration application), and the empty saves
folder. Extraction, native staging and reference-volume population now apply
that path mapping. The former root placement made the original idle demo receive
fnfErr for `:Alone Data:ListBod2.PAK` and show its missing-file alert.

All 36 installed data forks match extraction exactly. Resource-fork headers,
maps and payloads also match outside reserved bytes [16,256): the application
has 21 changed bytes at offsets 68–117; Quick Reference has 27 at 68–121; the
registration application has 21 at 71–117. Resource data/map offsets are at or
beyond 256, and independent parsing finds identical application resources.
Keep the known original extracted application fork and its existing byte guards;
do not replace it with installer-written reserved metadata.

Local evidence: `tmp/m2-installer-progress.log` terminates normally (status 0);
`ref/mame/snap/m2-installer-progress-06.png` and later internal frames show
"Installation was successful". `tmp/m2-installer-forks.log` records all 36
fork comparisons and the installed ListBod2 location. The test volume is
`tmp/m2-installer-reference.hd`; the established reference volume was unchanged.
For the known Finder launch location only, the installer file was renamed on
that isolated copy and its icon position copied from the game. Its complete
data/resource fork bytes were checked unchanged before execution. The first
short observation ended at file 4/36 and was rejected; it is not completion
evidence. The accepted run installed into a fresh `Installer Result` folder.

The HFS volume also holds the manual (PDF), `Quick Reference` and a "Stair Bug
Fix" folder: G3Throttle, with a note that the storeroom stairs fail on a fast
Mac after collecting the loft items. That is a timing-sensitive original bug for
the port to reproduce or pace around, not a reason to change game logic.

A release installer will need the same chain without `unar`/`hfsutils`. Vette's
standalone helper (`~/Documents/Vette/tools/install-data`) already decodes
StuffIt method 13 and is the intended starting point.

Fresh and repeated extraction preserve the original fork bytes and archive-derived
Finder metadata. Migration removes an old root ListBod2 file and its `.finfo`
only when both match the verified source exactly. A conflicting file, symlink
or unexpected resource companion causes a named failure; it is not removed.
Native staging applies the same guarded migration. Reference population refuses
an existing destination folder; use a fresh folder for independent comparisons.
