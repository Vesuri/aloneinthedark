#!/usr/bin/env python3
"""Compare all letter-page text calls, artwork, palettes and AGA publication."""
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
    for log in (reference, native):
        require(not re.search(r"FAIL|[Tt]imeout|[Tt]imed out|Error in sourced|Protocol error", log), "clean completion")
    require("PASS original story pages=8" in reference and "Exited via the debugger" in reference, "Mac return")
    require("PASS original story pages=8 returned normally with released keys" in native
            and "[Inferior 1 (Remote target) detached]" in native, "native return and release")
    ref_pages = re.findall(r"STORY_PAGE_END page=(\d+) last=(true|false)", reference)
    require(ref_pages == [(str(i), "true" if i == 7 else "false") for i in range(8)], "Mac page order/end flag")
    pages = re.findall(r"STORY_PAGE page=(\d+) last=(\d+) ticks=(\d+) queued=(\d+) presented=(\d+) front=([0-9A-F]+) readstate=(\d+) count=(\d+)", native)
    require(len(pages) == 8, "eight native pages")
    ref_text = re.findall(r"^STORY_TEXT .+$", reference, re.M)
    native_text = re.findall(r"^STORY_TEXT .+$", native, re.M)
    require(len(ref_text) == 257 and ref_text == native_text, "all text bytes/positions/font settings")
    folder = args.folder
    transfer = read(folder, "video-transfer-lut16.bin", 65536)
    require(hashlib.sha256(transfer).hexdigest() == "bf0a6433c155a61989e5dc0571bae1357066ab476a24d0afaf2e2aa7094fe2aa", "transfer identity")
    previous = 0
    for i, page in enumerate(pages):
        number, last, tick, queued, presented, front, state, count = page
        require(int(number) == i and bool(int(last)) == (i == 7) and int(count) == i, "page/input state")
        require(int(queued) > previous and queued == presented, "new complete publication")
        previous = int(queued)
        prefix = f"story-pages-native-{i}"
        pixels = read(folder, prefix+"-screen.bin", 307200)
        clut = read(folder, prefix+"-clut.bin", 2056)
        original = read(folder, f"story-pages-reference-{i}-screen.bin", 307200)
        original_clut = read(folder, f"story-pages-reference-{i}-clut.bin", 2056)
        for y in range(200):
            for x in range(320):
                at = (y+150)*640+x+160
                require(pixels[at] == original[at], f"page {i} pixel difference at {x},{y}")
        for pen in range(256):
            require(clut[10+pen*8:16+pen*8] == original_clut[10+pen*8:16+pen*8], f"page {i} RGB16 {pen}")
        check_frame(folder, prefix, pixels, clut, 160, 150, int(front, 16), transfer)
        print(f"PASS page {i}: artwork/background/arrow/palette/publication; exact viewport pixels")
    print("PASS all eight letter pages: 257 identical text calls and normal input/return")


if __name__ == "__main__":
    main()
