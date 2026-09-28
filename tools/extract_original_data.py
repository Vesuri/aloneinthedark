#!/usr/bin/env python3
"""Extract the original Alone in the Dark 1.0 files from the user's own archive.

The release is nested four deep:

  AloneInTheDark.img_.sit          StuffIt 5 archive (unar)
    Alone In The Dark.img          raw HFS volume, type rohd/ddsk (hfsutils)
      Alone in the Dark Installer  StuffIt InstallerMaker application
        data fork                  classic StuffIt 1.x archive whose magic is
                                   "STi2" instead of "SIT!" -- otherwise the
                                   same 22-byte header, rLau marker and
                                   112-byte entries (method 13 / none)

Patching the four magic bytes lets unar read the payload; every entry's CRC
then verifies.  The output directory receives:

  Alone In The Dark   the application's raw resource fork (not AppleDouble)
  Alone Data/         the .PAK/.ITD data-fork files, unchanged

Development/diagnostic helper for a local checkout only.  Requires `unar` and
`hfsutils` (hmount/hcopy/humount) on PATH.  Nothing extracted here may be
committed; see .gitignore.

    python3 tools/extract_original_data.py tmp/AloneInTheDark.img_.sit tmp/runtime-data
"""

from __future__ import annotations

import argparse
import hashlib
import shutil
import struct
import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from resource_fork import parse_resource_fork  # noqa: E402

APPLICATION = "Alone In The Dark"
DATA_FOLDER = "Alone Data"
INSTALLER = "Alone in the Dark Installer"
# Measured from the one known release (Alone In The Dark 1.0, vers 1.0).
APPLICATION_SHA256 = "b5848c063652b7223e3e350905b3a9054247b8536942753f435b1051a6352db2"


def run(*command: str, cwd: Path | None = None) -> None:
    subprocess.run(command, cwd=cwd, check=True, stdout=subprocess.DEVNULL)


def apple_double_resource_fork(path: Path) -> bytes:
    """Return entry 2 (resource fork) of an AppleDouble file written by unar."""
    raw = path.read_bytes()
    if raw[:4] != b"\x00\x05\x16\x07":
        raise ValueError(f"{path}: not an AppleDouble file")
    for index in range(struct.unpack_from(">H", raw, 24)[0]):
        entry, offset, length = struct.unpack_from(">III", raw, 26 + 12 * index)
        if entry == 2:
            return raw[offset:offset + length]
    raise ValueError(f"{path}: no resource fork entry")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("archive", type=Path, help="AloneInTheDark.img_.sit")
    parser.add_argument("destination", type=Path)
    args = parser.parse_args()

    for tool in ("unar", "hmount", "hcopy", "humount"):
        if not shutil.which(tool):
            parser.error(f"{tool} is required on PATH")

    with tempfile.TemporaryDirectory(prefix="aitd-extract-") as scratch_name:
        scratch = Path(scratch_name)
        run("unar", "-q", "-k", "visible", "-o", str(scratch / "sit"), str(args.archive.resolve()))
        images = list((scratch / "sit").rglob("*.img"))
        if len(images) != 1:
            raise SystemExit(f"expected one HFS image in {args.archive}, found {len(images)}")
        volume = scratch / "volume.hfs"
        shutil.copyfile(images[0], volume)
        if volume.read_bytes()[1024:1026] != b"BD":
            raise SystemExit(f"{images[0].name}: no HFS master directory block")

        installer = scratch / "installer.bin"
        run("hmount", str(volume))
        try:
            run("hcopy", "-m", f":{INSTALLER}", str(installer))
        finally:
            run("humount")

        run("unar", "-q", "-k", "visible", "-o", str(scratch / "installer"), str(installer))
        payload = scratch / "installer" / INSTALLER
        data = bytearray(payload.read_bytes())
        if data[:4] != b"STi2" or data[10:14] != b"rLau":
            raise SystemExit(f"{INSTALLER}: data fork is not an STi2 StuffIt payload")
        if struct.unpack_from(">I", data, 6)[0] != len(data):
            raise SystemExit(f"{INSTALLER}: payload length does not match its header")
        data[:4] = b"SIT!"
        patched = scratch / "payload.sit"
        patched.write_bytes(data)
        run("unar", "-q", "-k", "visible", "-o", str(scratch / "payload"), str(patched))

        root = next((scratch / "payload").iterdir())
        fork = apple_double_resource_fork(root / f"{APPLICATION}.rsrc")
        parse_resource_fork(fork, APPLICATION)
        digest = hashlib.sha256(fork).hexdigest()
        if digest != APPLICATION_SHA256:
            print(f"warning: {APPLICATION} resource fork sha256 {digest} "
                  "is not the known 1.0 release", file=sys.stderr)

        args.destination.mkdir(parents=True, exist_ok=True)
        (args.destination / APPLICATION).write_bytes(fork)
        target = args.destination / DATA_FOLDER
        if target.exists():
            shutil.rmtree(target)
        target.mkdir()
        count = 0
        for source in sorted((root / DATA_FOLDER).iterdir()):
            if source.suffix == ".rsrc" or not source.is_file():
                continue
            shutil.copyfile(source, target / source.name)
            count += 1
    print(f"{args.destination / APPLICATION}: {len(fork)} bytes; {count} files in {target}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
