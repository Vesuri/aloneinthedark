#!/usr/bin/env python3
"""Synthetic native file fixture; never an original-game read acceptance."""
import argparse
from pathlib import Path
import re
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--write',action='store_true');p.add_argument('--prepare',action='store_true');p.add_argument('--status',type=int,default=0)
a=p.parse_args();root=Path(__file__).resolve().parent.parent;drive=root/'amiga/.run/dh1'
if a.prepare:
    drive.mkdir(parents=True,exist_ok=True)
    (drive/'read-probe.bin').write_bytes(bytes((i*37+(i>>8))&255 for i in range(200003)))
    (drive/'absent-probe.bin').unlink(missing_ok=True)
    if a.write:(drive/'write-probe.bin').write_bytes(bytes((i*37+(i>>8))&255 for i in range(200003)))
else:
    log=(root/'amiga/.run/gdb-out.log').read_text()
    marker='PASS file-read: Line-A open/read/seek/EOF/position/close bytes=exact CCR=checked windows=10 DOS-reads=6 max=65536 cleanup=1 GetVol=WD/root/null-name FCB=index/exact/errors HVol=directory/state/errors WD=query/close/filter'
    if a.write:marker='PASS file-write: backend bytes=exact windows=20 writes=8 max=65536 flushes=3 EOF=17 cleanup=1'
    if a.status or re.search(r'FAIL|Error in sourced command file|Program received signal',log) or log.count(marker)!=1:
        raise SystemExit('FAIL file-read: missing completion or runner/observer failure')
    if a.write and (drive/'write-probe.bin').read_bytes()!=bytes((i*37+(i>>8))&255 for i in range(17)):
        raise SystemExit('FAIL file-write: host file length/bytes after close')
    print(marker)
