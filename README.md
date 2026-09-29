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
`FONT MANAGER / GETFNUM`, Dan1+$0012, after directory initialization and
the original General resource lookup. The game is not playable yet.
Other processors and performance work remain deferred.

The M0 tools checkpoint includes the trap census, original Mac runtime/frame
evidence and a regression harness. Host checks, native Line-A/stack/trap-patch
probes and link audits pass. `make regression` now passes `boot` on `a1200-020`,
ending at the original main entry before initialization. All 58 census low-memory accesses
now use private shadows. The 3 MB application heap and separate system heap
serve memory and resource handles. System identity and all eleven derived
capability flags match the Mac reference. The user-mode service bridge passes
its native ABI probe. OS windows and DOS/resload adapters pass the native/host
core probes; rendered-picture acceptance is owner-deferred (M1.7b2). The next
implementation item is the remaining Resource Manager services (M2.2).
Resource bodies now stream from disk into zone handles; startup retains the
4,998-byte map instead of the 1,424,934-byte application fork. The `resource-read`
regression verifies original bytes and 16 runtime read windows before the current
GetFNum stop. Named/ID/indexed lookup, resource counts and metadata, purge/reload and release now
pass paired Mac/native checks. Native resource staging now passes exact publication,
abort, rollback and stale-file checks. Resource-file open/create/update/close,
AddResource, multi-fork search, noncurrent close and invalid update pass a
64-call native fixture paired with Mac contracts. Resource mutations, isolated
writes, pending map edits and dirty release/detach pass 130 additional paired
calls and six native rollback cases. Permissions 0–4, creation errors and read-only
mutation/close behavior pass a further 59-step fixture. Remaining lifecycle
variants are next. The metadata model preserves duplicate
type/ID entries within one file and resolves the first surviving insertion.
The metadata-only catalog and application-fork identity are verified (M2.1b1):
32 data files, 5,315,994 bytes; no data payload preloading. SetVol, the three
startup working directories, Preferences lookup and the optional movies error
are verified against the Mac (M2.1b2a). Read-only data forks now use persistent
DOS handles and per-fork 64 KiB caches. The native `file-read` regression verifies
bytes, seek/EOF/errors, window counts and shutdown cleanup (M2.1b2b); these are
synthetic fixture reads, not original-game PAK acceptance. Synchronous GetVol
now preserves SetVol working-directory identity and passes native/Mac round-trip
checks. Indexed open-file queries and hierarchical default-directory
state also pass native and Mac-reference checks. Working-directory queries,
closure and System-folder identity now use the same catalog. Synchronous
writable data forks, Write, SetEOF and FlushVol now use sparse
64 KiB buffers and pass Mac/native fixtures, including close and dirty-shutdown
disk readback. Permissions 0–4, protected files, shared writes with independent
positions, and FlushVol name/reference forms now pass Mac/native checks.
Named Create/Delete and Finder-info calls now pass Mac/native fixtures, with
checksummed metadata companions and durable close. Installed-file metadata now comes from validated original archive fields;
indexed queries now use measured HFS ordering in complete directories.
The dedicated application namespace, synchronous volume-parameter query and
OpenDF dispatch forms, HGetVInfo and the async census variants are complete.
Async completion preserves the measured Mac callback behavior at safe user-mode
return points, including nested file-service calls. Data and resource forks now use independent streams;
companion creation/reload/deletion and application resource preservation pass
Mac/native/host checks.
Final startup requirements acceptance awaits the file/resource services.

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
