#!/usr/bin/env python3
"""Generate the port-owned resource fork. No original game resources are copied."""
import argparse
from pathlib import Path
import struct
from resource_fork import parse_resource_fork
from placeholder_font import build as font_definition, FAMILY, BITMAP

OUTPUT=Path(__file__).resolve().parents[1]/'resources/overlay.rsrc'
def build():
    fond,nfnt=font_definition()
    driver=bytes.fromhex('a0f84e75') # private native driver trap; RTS
    bodies=struct.pack('>I',len(fond))+fond+struct.pack('>I',len(nfnt))+nfnt+struct.pack('>I',len(driver))+driver
    # Three types, one resource each. Reference offsets are relative to type list.
    types=struct.pack('>H4sHH4sHH4sHH',2,b'FOND',0,26,b'NFNT',0,38,b'Jnth',0,50)
    refs=struct.pack('>hHII',FAMILY,0,0,0)+struct.pack('>hHII',BITMAP,0xffff,len(fond)+4,0)+struct.pack('>hHII',11,0xffff,len(fond)+len(nfnt)+8,0)
    names=b'\x05Times';map_length=28+len(types)+len(refs)+len(names)
    header=struct.pack('>IIII',256,256+len(bodies),len(bodies),map_length)
    resource_map=header+bytes(8)+struct.pack('>HH',28,28+len(types)+len(refs))+types+refs+names
    return header+bytes(240)+bodies+resource_map

def check(data):
    rows=parse_resource_fork(data)
    fond,nfnt=font_definition()
    if [(r.kind,r.rid,r.name,r.attrs,r.body) for r in rows]!=[(b'FOND',FAMILY,'Times',0,fond),(b'NFNT',BITMAP,'',0,nfnt),(b'Jnth',11,'',0,bytes.fromhex('a0f84e75'))]:
        raise ValueError('OVERLAY / RESOURCE DEFINITION')

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--check',action='store_true');a=p.parse_args()
    data=build();check(data)
    if a.check:
        if OUTPUT.read_bytes()!=data:raise SystemExit('OVERLAY / GENERATED FILE DIFFERS')
        print(f'PASS overlay: deterministic port-owned FOND/NFNT/Jnth, {len(data)} bytes')
    else:
        OUTPUT.parent.mkdir(parents=True,exist_ok=True);OUTPUT.write_bytes(data)
