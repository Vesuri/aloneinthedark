#!/usr/bin/env python3
"""Create the minimal deterministic Amiga LHA distribution (LH5)."""
import argparse
import re
import tempfile
from pathlib import Path
import _amigaxdev  # noqa: F401
from amigaxdev import release

ROOT = Path(__file__).resolve().parents[1]
ICONS = ROOT/'release/icons'
ORIGINAL_HASHES = set(re.findall(r'"([0-9a-f]{64})"', (ROOT/'tools/install-data/originals.h').read_text()))
PREFIX = "Alone in the Dark Install"
STAMP = release.dos_stamp(2026, 10, 10)
crc16 = release.crc16

def installer_icon(game=False):
    # AloneInTheDark.inf is renamed and configured by Installer, exactly as RoF.inf in the
    # reference package. No synthetic replacement artwork.
    return release.installer_icon(ICONS, 'Alone in the Dark', game=game)

def drawer_icon():
    return release.template_icon(ICONS, 'drawer.info.b64')

def readme_icon():
    return release.template_icon(ICONS, 'readme.info.b64')

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("executable", type=Path)
    parser.add_argument("output_directory", type=Path)
    args = parser.parse_args()
    version = (ROOT / "VERSION").read_text().strip()
    files = {
        "AloneInTheDark": args.executable.read_bytes(),
        "AloneInTheDark.slave": (ROOT / "build/whdload/AloneInTheDark.slave").read_bytes(),
        "AloneInTheDark.inf": installer_icon(game=True),
        "AitdInstallData": (ROOT / "build/install-data/AitdInstallData.exe").read_bytes(),
        "Install": (ROOT / "release/Install").read_bytes(),
        "Install.info": installer_icon(),
        "ReadMe.info": readme_icon(),
        "ReadMe": (ROOT / "release/ReadMe").read_bytes(),
        "LICENSE.LGPL.txt": (ROOT / "tools/install-data/COPYING.LIB").read_bytes(),
    }
    release.refuse_originals(files, ORIGINAL_HASHES)
    # A diagnostic build is never accepted merely because it has a version string.
    from build_receipt import require_production
    require_production(args.executable)
    # The LH5 encoder's scratch stays in the ignored repository tmp directory.
    tempfile.tempdir = str(ROOT/'tmp')
    (ROOT/'tmp').mkdir(exist_ok=True)
    archive = release.write(args.output_directory / f"AloneInTheDark-{version}.lha",
                            release.archive(PREFIX, files, drawer_icon(), STAMP))
    print(f"{archive}: {len(files)} drawer contents plus drawer icon, {archive.stat().st_size} bytes")

if __name__ == "__main__":
    main()
