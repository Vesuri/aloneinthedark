#!/usr/bin/env python3
"""Generate the port-owned resource fork. No original game resources are copied.

The M2.2 overlay is deliberately empty. Font and dialog layouts will be added
with their measured definitions at M2.9 and M3.3; there are no placeholder IDs.
"""
import argparse
from pathlib import Path
import struct
from resource_fork import parse_resource_fork

OUTPUT=Path(__file__).resolve().parents[1]/'resources/overlay.rsrc'
def build():
    header=struct.pack('>IIII',256,256,0,30)
    resource_map=header+bytes(8)+struct.pack('>HHH',28,30,0xffff)
    return header+bytes(240)+resource_map

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--check',action='store_true');a=p.parse_args()
    data=build()
    if parse_resource_fork(data):raise SystemExit('OVERLAY / EXPECTED EMPTY MAP')
    if a.check:
        if OUTPUT.read_bytes()!=data:raise SystemExit('OVERLAY / GENERATED FILE DIFFERS')
        print('PASS overlay: deterministic port-owned empty map, 286 bytes')
    else:
        OUTPUT.parent.mkdir(parents=True,exist_ok=True);OUTPUT.write_bytes(data)
