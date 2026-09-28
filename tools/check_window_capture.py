#!/usr/bin/env python3
"""Generate/check local window-core fixtures. This is not rendered-video acceptance."""
import argparse
import hashlib
from pathlib import Path
import re
p=argparse.ArgumentParser(description=__doc__)
p.add_argument("--prepare",action="store_true")
p.add_argument("--status",type=int,default=0)
a=p.parse_args()
root=Path(__file__).resolve().parent.parent
work=root/"tmp"
drive=root/"amiga/.run/dh1"
if a.prepare:
    work.mkdir(exist_ok=True)
    drive.mkdir(parents=True,exist_ok=True)
    (drive/"WindowProbe.bin").write_bytes(bytes((i*17+(i>>8)*29+(i>>16)*71)&255 for i in range(1048576)))
    for name in ("WindowProbe.missing","WindowProbe.saved"):
        (drive/name).unlink(missing_ok=True)
    for stage in ("before","during","after"):
        (work/f"window-{stage}.bin").unlink(missing_ok=True)
else:
    log=(root/"amiga/.run/gdb-out.log").read_text()
    if a.status or re.search(r"FAIL|Error in sourced command file|Program received signal",log):
        raise SystemExit(f"FAIL window-core: runner status={a.status} or observer failure")
    if log.count("PASS window-read: bytes=1048576 chunks=16 checksum=59bc1dc5")!=1:
        raise SystemExit("FAIL window-core: missing/duplicate positive completion")
    expected=bytearray(98304)
    for y in range(384):
        for x in range(64):
            for plane in range(4):
                expected[y*256+plane*64+x]=255 if ((x//2+y//16)&15)&(1<<plane) else 0
    for stage in ("before","during","after"):
        if (work/f"window-{stage}.bin").read_bytes()!=expected:
            raise SystemExit(f"FAIL window-core: {stage} bitplanes differ")
    if (drive/"WindowProbe.saved").read_bytes()!=bytes(i^0xa5 for i in range(32)):
        raise SystemExit("FAIL window-core: host save readback differs")
    print("PASS window-core: native ABI, 1MiB checksum, clock, Paula, DOS errors/save, bitplane snapshots")
    print("Bitplane SHA256="+hashlib.sha256(expected).hexdigest())
    print("Rendered video acceptance remains separate; memory snapshots do not prove hardware output.")
