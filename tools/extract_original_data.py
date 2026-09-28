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
  ListBod2.PAK, Quick Reference, Register Triple A Pack: original root files
  *.rsrc              raw resource companions for ordinary files
  *.finfo             validated Finder records and original Mac timestamps

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
from installed_metadata import archive_entries, metadata_for

APPLICATION = "Alone In The Dark"
DATA_FOLDER = "Alone Data"
ROOT_FILES = ("ListBod2.PAK", "Quick Reference", "Register Triple A Pack")
INSTALLER = "Alone in the Dark Installer"
# Measured from the one known release (Alone In The Dark 1.0, vers 1.0).
APPLICATION_SHA256 = "b5848c063652b7223e3e350905b3a9054247b8536942753f435b1051a6352db2"


def run(*command: str, cwd: Path | None = None) -> None:
    subprocess.run(command, cwd=cwd, check=True, stdout=subprocess.DEVNULL)


def apple_double_resource_fork(path: Path) -> bytes:
    """Return entry 2 (resource fork) of an AppleDouble file written by unar."""
    raw = path.read_bytes()
    if len(raw) < 26 or raw[:8] != bytes.fromhex('0005160700020000'):
        raise ValueError(f"{path}: not an AppleDouble v2 file")
    count = struct.unpack_from('>H', raw, 24)[0]
    table_end = 26+12*count
    if table_end > len(raw):
        raise ValueError(f"{path}: truncated AppleDouble table")
    forks = []
    for index in range(count):
        entry, offset, length = struct.unpack_from(">III", raw, 26 + 12 * index)
        if offset < table_end or offset+length > len(raw):
            raise ValueError(f"{path}: invalid AppleDouble extent")
        if entry == 2:
            forks.append(raw[offset:offset + length])
    if len(forks) != 1:
        raise ValueError(f"{path}: missing or duplicate resource fork entry")
    return forks[0]


def unpack_payload(archive: Path, scratch: Path, visible: bool) -> Path:
    """Unpack the installer payload into scratch and return its root folder.

    visible=True writes resource forks as AppleDouble `*.rsrc` files; False
    writes native macOS forks and Finder info (what tools/macbin.py reads).
    """
    for tool in ("unar", "lsar", "xattr", "hmount", "hcopy", "humount"):
        if not shutil.which(tool):
            raise SystemExit(f"{tool} is required on PATH")
    fork_mode = ("-k", "visible") if visible else ()
    run("unar", "-q", "-k", "visible", "-o", str(scratch / "sit"), str(archive.resolve()))
    images = list((scratch / "sit").rglob("*.img"))
    if len(images) != 1:
        raise SystemExit(f"expected one HFS image in {archive}, found {len(images)}")
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
    run("unar", "-q", *fork_mode, "-o", str(scratch / "payload"), str(patched))
    return next((scratch / "payload").iterdir())


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("archive", type=Path, help="AloneInTheDark.img_.sit")
    parser.add_argument("destination", type=Path)
    args = parser.parse_args()

    with tempfile.TemporaryDirectory(prefix="aitd-extract-") as scratch_name:
        scratch = Path(scratch_name)
        root = unpack_payload(args.archive, scratch, visible=True)
        fork = apple_double_resource_fork(root / f"{APPLICATION}.rsrc")
        parse_resource_fork(fork, APPLICATION)
        digest = hashlib.sha256(fork).hexdigest()
        if digest != APPLICATION_SHA256:
            print(f"warning: {APPLICATION} resource fork sha256 {digest} "
                  "is not the known 1.0 release", file=sys.stderr)

        entries,archive=archive_entries(scratch / "payload.sit")
        app_metadata=metadata_for(archive,entries,APPLICATION,root / APPLICATION)
        args.destination.mkdir(parents=True, exist_ok=True)
        (args.destination / APPLICATION).write_bytes(fork)
        (args.destination / (APPLICATION+".finfo")).write_bytes(app_metadata)
        for name in ROOT_FILES:
            source = root / name
            info = metadata_for(archive, entries, name, source)
            records = [e for e in entries if e['XADFileName'] == name]
            sizes = {bool(e.get('XADIsResourceFork')): e['XADFileSize'] for e in records}
            data = source.read_bytes() if source.exists() else b''
            resource = (apple_double_resource_fork(Path(str(source)+'.rsrc'))
                        if sizes.get(True, 0) else b'')
            if len(data) != sizes.get(False, 0) or len(resource) != sizes.get(True, 0):
                raise ValueError('EXTRACT / FORK SIZE: '+name)
            (args.destination / name).write_bytes(data)
            if resource:
                (args.destination / (name+'.rsrc')).write_bytes(resource)
            elif (args.destination / (name+'.rsrc')).exists():
                raise ValueError('EXTRACT / UNEXPECTED RESOURCE COMPANION: '+name)
            (args.destination / (name+'.finfo')).write_bytes(info)
        target = args.destination / DATA_FOLDER
        if target.exists():
            shutil.rmtree(target)
        target.mkdir()
        count = 0
        for source in sorted((root / DATA_FOLDER).iterdir()):
            if source.suffix == ".rsrc" or not source.is_file():
                continue
            info=metadata_for(archive,entries,DATA_FOLDER+"/"+source.name,source)
            shutil.copyfile(source, target / source.name)
            (target / (source.name+".finfo")).write_bytes(info)
            count += 1
    print(f"{args.destination / APPLICATION}: {len(fork)} bytes; {count} files in {target}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
