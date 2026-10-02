# Alone in the Dark — Amiga

An unofficial, **in-progress** Amiga port of the 1994 Macintosh **Alone In The
Dark 1.0** by Infogrames and Interplay.

The port follows the approach of the completed Vette! port: run the original
68k game code with an Amiga implementation of the Macintosh services it uses,
using native bitplanes, a hardware mouse pointer and Paula sound. The runtime
and Toolbox layer are carried over from Vette!; see
[docs/open-work.md](docs/open-work.md) for what works today.

## Current state

The original 68020 game code completes startup and the ordinary idle demo on
the baseline A1200 configuration. The demo passes all nine Macintosh room/camera
transitions and exits naturally without demo input. Both original PAK payloads
and the intervening palette reactivation match the installed data and Mac
reference; service/window accounting is balanced.

Frame acceptance covers the two logos, title and credits, plus the car and frog
with their actual model/transform inputs replayed in the original Mac renderer.
The model frames match all 64,000 pixels, all 256 colours and native AGA
publication. Title/credits retain only verified differences in the owned
placeholder glyph artwork. The latest uninterrupted-intro regression verifies all 956 frames, including
944 partial updates and all 840 book-animation batches, with zero conversion
mismatches. Remaining acceptance is tracked in [open work](docs/open-work.md).

Production output uses Kalms eight-plane conversion and explicit dirty
rectangles. Book drawing publishes completed animation steps; back-buffer
synchronization skips pixels about to be replaced by conversion. Baseline PAL
and NTSC fixtures verify every pixel and colour, pointer motion and inversion,
partial updates and cleanup. Actual rendered-window acceptance, including the
reported black interval, remains owner-deferred.

Normal Enter reaches portraits and the story. All eight Carnby letter pages
pass their text layout, artwork, palette and AGA checks, with the documented
owned-font differences. GetKeys passes held/released-key and calling-contract
checks. Routine diagnostic builds use `INTROSKIP=1` to send normal Enter and
skip the book; uninterrupted-intro acceptance uses no injected input.

The native song fixture matches all 3,736 timed note events. Original effect
playback, replacement, completion, DMA ownership and cleanup are verified;
PAL/NTSC effect clocks and the original driver's 32-bit clock/status contracts
also pass. Original MDRV code remains unloaded. Gameplay, save/load and broader
music support remain later milestones.

Detailed contracts and evidence are in [development](docs/development.md),
[picture drawing](docs/picture-drawing.md), [palettes](docs/palette.md),
[bitmap copies](docs/copybits.md) and [cursor display](docs/cursor.md).

The sole active target is 68020 without an FPU. Tests temporarily default to
an A4000 model running a 68030 at maximum emulator speed; the explicit A1200
configuration retains the 14 MHz cycle-exact baseline. No Mac dialog, menu bar or
window chrome is drawn; hidden compatibility records support the original
startup. The executable remains 68020 code; 68040/68060 support remains deferred.

The M0 tools checkpoint includes the trap census, original Mac runtime/frame
evidence and a regression harness. Host checks, native Line-A/stack/trap-patch
probes and link audits pass. `make regression` now passes `boot` on `a1200-020`,
ending at the original main entry before initialization. All 58 census low-memory accesses
now use private shadows. The 3 MB application heap and separate system heap
serve memory and resource handles. System identity and all eleven derived
capability flags match the Mac reference. The user-mode service bridge passes
its native ABI probe. OS windows and DOS/resload adapters pass the native/host
core probes; rendered-picture acceptance is owner-deferred (M1.7b2). The next
items are intro visibility/progression and original PAK-read acceptance. Both original
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
current verified endpoint is the CopyBits return at Dark+$1E4C; original MDRV loading stays forbidden. Named/ID/indexed lookup, resource counts and metadata, purge/reload and release now
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
Final startup requirements acceptance now passes the original Core+$0460
success branch with result zero, neither failure alert, all eight Gestalt
queries and all eleven Engine capability flags.

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
