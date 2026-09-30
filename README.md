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
relocates Core and reaches `main`; initialization passes directory setup, the General resource lookup and the
first Times font lookup and the two native sound-driver startup calls (D8).
Menu-record initialization and the original eight-bit device selection, SetDepth, GetGWorld, hidden dialog construction and GetMainDevice also pass.
All ten original positioning calls also pass using integer-only SANE arithmetic
(no FPU), followed by hidden positioning, automatic low-resolution selection and cleanup. All 75 startup font-metrics
calls now match the Mac using installed placeholder definitions. All four Apple Event
handler registrations retain their measured callback/refCon state. The original colour
table now loads with measured detachment, seed and mutation behavior. Native palette
construction copies all 256 entries and owns its measured private allocation. Default
palette binding now matches the Mac without changing device or display colours.
Hidden window-title state now matches the Mac through owned title handles and
measured system-font advances. Startup realizes all 256 device colours and clears the 320×200 game client
area. The eight-plane display publishes that clear and its complete 256-colour
palette during vertical blank. Window palette binding now matches the Mac;
the already-realized ActivatePalette call also passes without changing colours.
Colour-window constructors and movement now use the measured local coordinates,
per-window pixel maps and independent regions. The first client frame still
matches the reference and publishes through all eight AGA planes; no Mac chrome is drawn.
ShowHide now reveals the background with exact clipping and leaves the game
viewport unchanged. SetGWorld binds the game drawing port and startup loads
Dark. TickCount reads the existing 60 Hz integer clock with the measured Mac
calling convention. The following size/origin requests preserve the already-correct
320×200 window. SetPt initializes the drawing point; startup then stops explicitly
at `TESTDEVICEATTRIBUTE` (Misc1+$0E3A), after allocating the original empty
region and real eight-bit GWorlds, binding and clipping them, locking and clearing
their pixels, unlocking them and restoring the game drawing port. Pixel-address
access then lets the original copy its first 512×56 image into a real buffer.
The following 20-call image rectangle loop now matches the Mac exactly.
The already-detached table call returns the measured resource error without
changing the table. Its subsequent 138×542 world allocation also matches the
Mac, preserving the supplied device colour table. RGB foreground/background
selection now updates the offscreen port using its real inverse colour table.
All twenty preparation pictures now draw into the 138×542 world, with exact
reference colour mapping and preserved pixels outside each destination.
All 220 startup text measurements now match the Mac, including fractional
advance accumulation performed entirely with integers. The subsequent binding
of the existing background window now preserves all records, pixels and palette.
Both original conversions of its corner points to global coordinates also match.
Startup also clears and rebuilds the four game menus as hidden records; no menu
bar is drawn. Native driver initialization is accepted through the second Times
lookup, which returns family 20. The original mixer
is never loaded. The game is not playable yet.
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
items are drawing-device attribute queries and original PAK-read acceptance. Both original
Times lookups now pass register, stack, error-state and installed-font checks. Fresh and existing preferences now request WIND 128
through the original instructions, with only the size byte changed.
The logical device has real 640×480×8 storage; its four selection calls match
the Mac. Broader drawing, palette activation and rendered intro acceptance remain pending.
Extraction and staging now
match the original installer: ListBod2.PAK belongs under Alone Data. The original
Mac idle presentation now completes all 15 images and reads both PAKs. Native
read acceptance still needs the intervening drawing services and payload checks.
Resource bodies now stream from disk into zone handles; startup retains the
4,998-byte map instead of the 1,424,934-byte application fork. The `resource-read`
regression verifies original bytes and bounded runtime resource reads; the
current stop is drawing-device attribute querying (TestDeviceAttribute); original MDRV loading stays forbidden. Named/ID/indexed lookup, resource counts and metadata, purge/reload and release now
pass paired Mac/native checks. Native resource staging now passes exact publication,
abort, rollback and stale-file checks. Resource-file open/create/update/close,
AddResource, multi-fork search, noncurrent close and invalid update pass a
64-call native fixture paired with Mac contracts. Resource mutations, isolated
writes, pending map edits and the full dirty-handle lifecycle pass 175 additional paired
calls and six native rollback cases. Permissions 0–4, creation errors and read-only
mutation/close behavior pass a further 59-step fixture. Dirty-resource exit
persistence passes the original runtime exit, fresh-launch readback and failed
publication checks under both saves and preferences. The port overlay contains the port-owned Times FOND/NFNT and native Jnth driver stub and is
open below the application; dialog overrides have a tested search route. The
metadata model preserves duplicate type/ID entries within one file and resolves the first surviving insertion.
The metadata-only catalog and application-fork identity are verified (M2.1b1):
33 data files, 5,584,424 bytes; no data payload preloading. SetVol, the three
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
Final startup requirements acceptance remains pending beyond the graphics-device stop.

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
