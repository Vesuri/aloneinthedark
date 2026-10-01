#!/usr/bin/env python3
"""Pair the original portrait wait with native pixels and AGA publication."""
import argparse
import hashlib
from pathlib import Path
import re

from check_aga_capture import check_frame, read, require


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("reference_log", type=Path)
    parser.add_argument("native_log", type=Path)
    parser.add_argument("--reference-status", type=int, required=True)
    parser.add_argument("--native-status", type=int, required=True)
    parser.add_argument("--folder", type=Path, default=Path("tmp"))
    args = parser.parse_args()
    require(args.reference_status == args.native_status == 0, "process completion")
    reference, native = args.reference_log.read_text(), args.native_log.read_text()
    # MAME's optional floppy-mechanism samples are absent in this headless setup.
    reference_checked = "\n".join(line for line in reference.splitlines()
        if not re.fullmatch(r"\[:fdc:[01]:35hd:flopsnd\] Error opening sample '35_[a-z0-9_]+' "
                            r"\(generic:2 No such file or directory\)", line))
    for text in (reference_checked, native):
        require(not re.search(r"FAIL|[Tt]imeout|[Tt]imed out|Error|Protocol error", text),
                "clean diagnostic completion")
    require("PASS original portraits wait capture" in reference
            and "Exited via the debugger" in reference, "reference endpoint")
    require("PASS native portraits wait capture" in native
            and "[Inferior 1 (Remote target) detached]" in native, "native endpoint")
    require(re.search(r"PORTRAITS_REFERENCE pc=[0-9A-F]+ choice=0 ticks=\d+ input=0", reference),
            "original Carnby selection with released input")
    require("PASS original menu selects new game with normal Enter and releases key" in native,
            "original native menu branch and released input")
    match = re.search(r"PORTRAITS_STABLE ticks=\d+ choice=0 queued=(\d+) presented=(\d+)", native)
    require(match and int(match[1]) > 0 and match[1] == match[2], "native publication")
    storage = re.search(r"PORTRAITS_STORAGE front=([0-9A-F]+) left=160 top=150 pending=0", native)
    require(storage, "native display storage")
    folder = args.folder
    original = read(folder, "portraits-reference-screen.bin", 307200)
    pixels = read(folder, "portraits-native-screen.bin", 307200)
    for y in range(150, 350):
        require(original[y*640+160:y*640+480] == pixels[y*640+160:y*640+480],
                f"client row {y-150}")
    original_clut = read(folder, "portraits-reference-clut.bin", 2056)
    clut = read(folder, "portraits-native-clut.bin", 2056)
    for i in range(256):
        require(original_clut[10+i*8:16+i*8] == clut[10+i*8:16+i*8], f"RGB16 colour {i}")
    transfer = read(folder, "video-transfer-lut16.bin", 65536)
    require(hashlib.sha256(transfer).hexdigest() ==
            "bf0a6433c155a61989e5dc0571bae1357066ab476a24d0afaf2e2aa7094fe2aa", "video transfer")
    check_frame(folder, "portraits-native", pixels, clut, 160, 150, int(storage[1], 16), transfer)
    print("PASS portraits: 64000 Mac/native pixels, 256 colours, AGA planes/palette/publication")
    print("Rendered host-window verification remains pending.")


if __name__ == "__main__":
    main()
