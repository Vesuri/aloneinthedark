# File Manager reference contract

M2.1a adds full 80-byte parameter blocks to the existing byte-checked MAME
logger and corrects the initial diagnostic. The File Manager implementation
is still M2.1b; none of these observations is a fabricated runtime response.

## First call: application file control block

Core+$4142 is `7008` (`MOVEQ #8,D0`), followed by `$A260` at +$4144.
Selector 8 is **PBGetFCBInfo**; selector 7 is PBGetWDInfo. The census already
had the correct mapping. The old runtime diagnostic and current-state docs
incorrectly called selector 8 GetWDInfo; those names are corrected.

The parameter layout follows Apple's [File Manager C/assembly summary](https://dev.os9.ca/techpubs/mac/Files/Files-301A.html),
under FCBPBRec. The System 7.5.5 reference returns the following at that site:

| Field | Byte offset | Observed value |
| --- | ---: | ---: |
| ioResult | 16 | 0 |
| ioRefNum (input and output) | 24 | $05E2 |
| ioFCBIndx (input) | 28 | 0 |
| ioFCBFlNm | 32 | 1705 |
| ioFCBFlags | 36 | $0300 |
| ioFCBStBlk | 38 | $0D4F |
| ioFCBEOF | 40 | 1,424,934 |
| ioFCBPLen | 44 | 1,449,984 |
| ioFCBCrPs | 48 | 1,407,018 |
| ioFCBVRefNum | 52 | -1 |
| ioFCBClpSiz | 54 | $0001D800 |
| ioFCBParID | 58 | 1671 |

The logical length equals the original application's resource fork. Allocation
blocks, current position, file IDs and references are observations of this
reference run, not constants to paste into the port. The catalog must model
identities and the file table must model open forks. The subsequent OpenWD
of `:Alone Data:` succeeds with working-directory reference $8063; the optional
`:Alone Movies:` lookup returns fnfErr (-43). Preserve ordinary missing-file
errors for known optional paths; unknown/unimplemented path handling stays loud.

The native observer captures the same caller's request with **ioRefNum=0,
ioFCBIndx=0**. `CurResFile` currently exposes `s_currentResourceFork`, an internal
array index. M2.1b must assign an actual pre-opened application-fork identity
and make Resource Manager references consistent with that File Manager table.
Returning fixed folder numbers at the current stop would hide this mismatch.
The resource data can remain buffered until M2.2 changes its loading policy.

## Reproducible evidence

Run the existing headless reference route in `mac-reference-loop.md`, using
`tools/mac_traps.lua`, then:

```sh
python3 tools/check_file_reference.py tmp/m2-file-full-reference.log
```

The checker attributes each input via live jump-table addresses and original
trap bytes, pairs returns by resume PC and parameter-block address, requires
all 80 bytes and equal ioResult/D0.W, and rejects missing completion or pending
calls. It ignores unrelated system calls and untaken alternate-glue return
sites. It requires positive application-FCB, data-directory, missing-movies
and ITD_RESS.PAK read evidence. `--require-file present.pak` additionally requires
that file; a missing read fails. Its negative fixtures run in `make host-tests`.
This verifies calls and returned counts, not read-payload checksums.

Local full-route evidence: 1,279 paired direct File Manager calls; play, save,
load and Finder checkpoints complete in 181 emulated seconds, with normal
termination. It reads 108,928 bytes cumulatively from ITD_RESS.PAK, plus the
world tables, room/actor PAKs and SAVE0.ITD. **No PRESENT.PAK open/read occurs on
this route.** A shorter startup capture similarly omits it. M2.1b retains the
original acceptance requirement while identifying a real path that reaches
that file, or documenting why the file is unused; do not synthesize a game read
to make an acceptance line pass.

Native validation: clean `window-core` and production `boot` pass on 68020.
`original_startup.gdb` checks the original bytes, records the request, then
reports the corrected `FILE MANAGER / GETFCBINFO`, Core+$4144 stop. A5 $00787240
and STRS $004442C8 give zero mismatches in 75,616 bytes. Heap accounting retains
zero unexplained bytes. This is a diagnostic/reference checkpoint, not progress
past the File Manager stop or a successful game launch.
