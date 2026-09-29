#!/usr/bin/env python3
"""Generate the port-owned resource fork. No original game resources are copied."""
import argparse
from pathlib import Path
import struct
from resource_fork import parse_resource_fork
from placeholder_font import build as font_definition, FAMILY, BITMAP

OUTPUT=Path(__file__).resolve().parents[1]/'resources/overlay.rsrc'
def definitions():
    from startup_fonts import resources
    fond,nfnt=font_definition();families,bitmaps=resources()
    return [(b'FOND',FAMILY,'Times',fond)]+families+[(b'NFNT',BITMAP,'',nfnt)]+bitmaps+[(b'Jnth',11,'',bytes.fromhex('a0f84e75'))]
def build():
    rows=definitions();kinds=list(dict.fromkeys(row[0] for row in rows))
    bodies=bytearray();names=bytearray();refs=bytearray();types=bytearray(struct.pack('>H',len(kinds)-1))
    for kind in kinds:
        entries=[r for r in rows if r[0]==kind]
        types+=struct.pack('>4sHH',kind,len(entries)-1,2+len(kinds)*8+len(refs))
        for _,rid,name,body in entries:
            name_offset=len(names) if name else 65535
            if name:
                encoded=name.encode('mac_roman');names+=bytes((len(encoded),))+encoded
            refs+=struct.pack('>hHII',rid,name_offset,len(bodies),0)
            bodies+=struct.pack('>I',len(body))+body
    map_length=28+len(types)+len(refs)+len(names)
    header=struct.pack('>IIII',256,256+len(bodies),len(bodies),map_length)
    resource_map=header+bytes(8)+struct.pack('>HH',28,28+len(types)+len(refs))+types+refs+names
    return header+bytes(240)+bodies+resource_map

def check(data):
    rows=parse_resource_fork(data)
    if [(r.kind,r.rid,r.name,r.attrs,r.body) for r in rows]!=[(kind,rid,name,0,body) for kind,rid,name,body in definitions()]:
        raise ValueError('OVERLAY / RESOURCE DEFINITION')

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--check',action='store_true');a=p.parse_args()
    data=build();check(data)
    if a.check:
        if OUTPUT.read_bytes()!=data:raise SystemExit('OVERLAY / GENERATED FILE DIFFERS')
        print(f'PASS overlay: deterministic port-owned FOND/NFNT/Jnth, {len(data)} bytes')
    else:
        OUTPUT.parent.mkdir(parents=True,exist_ok=True);OUTPUT.write_bytes(data)
