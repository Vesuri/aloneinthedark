# AitdInstallData

Standalone C99 installer for the known Macintosh Alone in the Dark 1.0 archive.
Download [AloneInTheDark.img_.sit](https://www.macintoshrepository.org/download.php?id=5338) and leave it compressed.
The executable needs no Python, archive libraries, host resource forks or
xadmaster. Its Amiga build uses dos.library and exec.library directly.

```
make -C tools/install-data
build/install-data/AitdInstallData tmp/AloneInTheDark.img_.sit destination [scratch]
. amiga/env.sh
make -C tools/install-data amiga
make -C tools/install-data test
python3 tools/install-data/test_amiga.py
```

The outer StuffIt 5 archive contains a raw HFS image compressed with Arsenic
(method 15). The HFS root contains `Alone in the Dark Installer`; its data fork
is an InstallerMaker `STi2` archive. After checking that complete payload's
SHA-256, the installer extracts the exact known fork offsets from `originals.h`
using methods 0 and 13. That manifest contains only names, offsets, sizes,
checksums and hashes, never original game bytes. The final 74 files total
7,103,622 bytes, including raw resource companions and `AFI1` Finder records.
`ListBod2.PAK` is placed under `Alone Data`, matching the original installation.

All outputs are extracted and verified before publication. An existing file is
accepted only when its hash matches and is never overwritten. Missing files
can be added to a partial installation. Failure removes files published by the
current run and its private staging/scratch directories. Ctrl-C cancels at the
next buffered I/O operation. Scratch and destination may be on different volumes.
The Installer script can reinstall into a fresh staging drawer before copying
verified originals over an existing installation; saved games are preserved.

Allow 24 MB free in scratch and 8 MB in the destination for Installer operation,
excluding the downloaded archive. Omitting scratch selects the destination.
Do not use RAM: for scratch unless that space is available in addition to decoder
working memory. The helper caps image forks at 32 MiB and Arsenic blocks at
1 MiB (at most 5 MiB allocated for the byte block and inverse-BWT indices).
It uses a shared 64 KiB history window and 4 KiB buffered I/O. Large buffers are
static or explicitly allocated, never placed on the process stack. There is
no recursion, variable-length stack array, hidden stack enlargement or libc
in the Amiga binary. The build emits stack reports and rejects unresolved
runtime helpers.

Measured native acceptance on a 68030 with 2 MiB Chip and 8 MiB Fast RAM:
all 74 output hashes match; a 4096-byte stack retains 3272 untouched bytes
(824 bytes used including the measured OS-call path). The known archive uses
512 KiB Arsenic blocks, allocating 2,621,440 bytes for its block and transform.
The helper's BSS is 109,708 bytes. Host AddressSanitizer/UndefinedBehaviorSanitizer
checks and native fresh-install/update icon tests also pass.

HFS catalog and overflow leaf chains are iterative and bounded. Fragmentation
of the extents-overflow file itself is unsupported. The original image omits
unused allocation blocks at its end; every actual fork read must still fit the
physical image. Encryption, unsupported methods, duplicate images, unsupported
payloads, bad bounds and checksum failures are explicit errors.

`test_install.py` checks exact hashes, compares the independent Python extractor's
installed files when available, and covers idempotency, partial repair, preserving
unsupported existing files, damaged inputs, cancellation and cleanup.
`test_amiga.py` runs the helper on a 68030 with an actual 4096-byte process stack,
checks its watermark and verifies every output across separate guest volumes.
`test_installer_script.py` drives the real Commodore Installer with deterministic
requester answers. It checks copy operations and icons using a clearly marked
slave-copy fixture; executing the real slave belongs to the WHDLoad suite.
Tests use local original data under ignored `tmp/`; none is distributed.

## License and provenance

The standalone helper's C, headers and startup assembly are LGPL-2.1-or-later;
see COPYING.LIB. It is separate from the game executable. Complete source and
build files are available at https://github.com/Vesuri/aloneinthedark under
`tools/install-data`. The release carries the helper binary and license.

The bounded StuffIt 5/method 13 and HFS reader, platform I/O adapters and SHA-256
implementation were adapted from https://github.com/Vesuri/vette. The NDIF layer
used by Vette is unnecessary for this raw HFS image and is not included.

Arsenic arithmetic/MTF/BWT decoding and its randomization table are adapted from
[MacPaw XADMaster's Arsenic decoder](https://github.com/MacPaw/XADMaster/blob/master/XADStuffItArsenicHandle.m),
copyright 2017-present MacPaw Way Ltd., LGPL-2.1-or-later. Its Objective-C runtime
was replaced by bounded C99 buffers and the helper's checked I/O.
`sit13_tables.h` retains the same license and provenance from
[XADStuffIt13Handle.m](https://github.com/MacPaw/XADMaster/blob/master/XADStuffIt13Handle.m).
