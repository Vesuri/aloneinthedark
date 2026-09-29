#!/usr/bin/env python3
"""Install the original game onto a classic-Mac HFS hard-disk image for MAME.

The extracted installer payload (see extract_original_data.py) is installed
into a top-level folder of the volume's Desktop Folder (so it shows on the System 7 desktop, or the root
if the volume has none): the application with its resource fork, `Alone Data`,
the empty `Alone Saved Games` folder and the extras.  Every file travels as MacBinary
through `hcopy -m`, the only hfsutils path that keeps both forks together with
type, creator and Finder flags.  Nothing here is committed: the image lives in
ignored ref/.

The verified original installer moves ListBod2.PAK from the payload root into
Alone Data. This tool applies that same path change, preserving both forks.

    python3 tools/install_reference_volume.py tmp/AloneInTheDark.img_.sit \\
        ref/mame/hd/aitd_755.hd
"""

from __future__ import annotations

import argparse
import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from extract_original_data import unpack_payload  # noqa: E402
from macbin import encode  # noqa: E402
from install_layout import installed_path

FOLDER = "Alone in the Dark"


def hfs(*command: str) -> str:
    return subprocess.run(command, check=True, capture_output=True, text=True).stdout


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("archive", type=Path, help="AloneInTheDark.img_.sit")
    parser.add_argument("volume", type=Path, help="HFS hard-disk image (Apple partition map)")
    parser.add_argument("--folder", default=FOLDER, help=f"destination folder (default: {FOLDER})")
    args = parser.parse_args()

    with tempfile.TemporaryDirectory(prefix="aitd-volume-") as scratch_name:
        scratch = Path(scratch_name)
        root = unpack_payload(args.archive, scratch, visible=False)
        macbinary = scratch / "macbinary"
        macbinary.mkdir()

        hfs("hmount", str(args.volume))
        try:
            parent = ":Desktop Folder" if "Desktop Folder" in hfs("hls", "-1a", ":").splitlines() else ""
            if args.folder in hfs("hls", "-1a", parent + ":").splitlines():
                raise SystemExit(f"{parent}:{args.folder} already exists on {args.volume}; "
                                 "remove it (hdel/hrmdir) or use --folder")
            base = parent + ":" + args.folder
            count = 0
            for source in sorted(root.rglob("*")):
                relative = installed_path(source.relative_to(root))
                target = base + ":" + ":".join(relative.parts)
                if source.is_dir():
                    continue
                for depth in range(len(relative.parts)):
                    folder = base + "".join(":" + p for p in relative.parts[:depth])
                    subprocess.run(["hmkdir", folder], capture_output=True)
                blob = macbinary / f"{count}.bin"
                blob.write_bytes(encode(str(source), require_rsrc=False))
                hfs("hcopy", "-m", str(blob), target)
                count += 1
            # Empty folders (Alone Saved Games) have no file to create them above.
            for source in sorted(root.rglob("*")):
                if source.is_dir():
                    relative = installed_path(source.relative_to(root))
                    subprocess.run(["hmkdir", base + "".join(
                        ":" + p for p in relative.parts)], capture_output=True)
            listing = hfs("hls", "-laR", base)
        finally:
            subprocess.run(["humount"], capture_output=True)
    print(listing)
    print(f"installed {count} files into {base} on {args.volume}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
