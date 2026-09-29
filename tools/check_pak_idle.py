#!/usr/bin/env python3
"""Require a natural menu timeout, all presentation images and real PAK reads."""
import argparse
import hashlib
from pathlib import Path
import re
import struct
import unittest
from resource_fork import read_resource_fork
from check_file_reference import capture,validate

GUARDS=((12,0x1336,0x1404,'261baba99e45abb70fb6bc03464ee798bc3d0d2b729d2cee2007dafef990d7a4'),
        (4,0x5224,0x52b6,'f94d1eccceda24d0ccc26684acc6f024acea7bb0b7c9483a068dadd5a4acd842'),
        (13,0x2d16,0x2e0e,'8542a8cf101e9b493e0d78cc48c9317163ecb8647f22683354d9d50e7857c580'))
COMPLETE='PASS file-reference captured; natural idle presentation images=15'
def check_original(path):
    rows={(r.kind,r.rid):r.body for r in read_resource_fork(path)}
    for seg,start,end,digest in GUARDS:
        if hashlib.sha256(rows[b'CODE',seg][start:end]).hexdigest()!=digest:raise ValueError('original timeout/caller/presentation bytes')
    if rows[b'STRS',0][0x64:0x70]!=b'present.pak\0':raise ValueError('original PRESENT filename')
    refs=[]
    for (kind,seg),body in rows.items():
        if kind==b'CREL':
            for (offset,) in struct.iter_unpack('>H',body):
                if offset&1 and struct.unpack_from('>I',rows[b'CODE',seg],offset&~1)[0]==0x64:refs.append((seg,offset&~1))
    if refs!=[(13,0x2d46)]:raise ValueError('original direct PRESENT string relocation')
    if rows[b'CODE',0][16+101*8:24+101*8]!=bytes.fromhex('2d123f3c000da9f0'):raise ValueError('original presentation jump entry')

def check_route(lines,status):
    if status!=0:raise ValueError('reference runner did not exit normally')
    text='\n'.join(lines)
    if any(x in text for x in ('FAIL ', 'LUA ERROR', 'Error in breakpoint')) or text.count(COMPLETE)!=1:raise ValueError('positive presentation completion missing or duplicated')
    for seg in (4,12,13):
        if text.count(f'ARM PAK_IDLE CODE={seg} original bytes verified')!=1:raise ValueError('live original-byte guards')
    for marker in ('PAK_IDLE timeout Dan1+13FA','PAK_IDLE caller Dark+52AC timeout=1','PAK_IDLE presentation Dan2+2D16'):
        if text.count(marker)!=1:raise ValueError('natural route checkpoint missing or duplicated')
    rows=[(int(a,16),int(b,16)) for a,b in re.findall(r'^PAK_IDLE image index=([0-9A-F]+) body=([0-9A-F]+)$',text,re.M)]
    if [n for n,p in rows]!=list(range(15)) or not all(p for n,p in rows):raise ValueError('all fifteen original image loads must succeed')
    positions=[text.index(s) for s in ('PAK_IDLE timeout Dan1+13FA','PAK_IDLE caller Dark+52AC','PAK_IDLE presentation Dan2+2D16','PAK_IDLE image index=0 ',COMPLETE)]
    if positions!=sorted(positions):raise ValueError('route checkpoint order')

class RouteChecks(unittest.TestCase):
    def test_rejects_missing_and_timeout(self):
        rows=[f'ARM PAK_IDLE CODE={s} original bytes verified' for s in (4,12,13)]+[
            'PAK_IDLE timeout Dan1+13FA ticks=1234','PAK_IDLE caller Dark+52AC timeout=1','PAK_IDLE presentation Dan2+2D16']+[
            f'PAK_IDLE image index={n:X} body=123456' for n in range(15)]+[COMPLETE]
        check_route(rows,0)
        for bad,status in ((rows,124),(rows,None),(rows[:-1],0),(rows+[COMPLETE],0),(rows+['LUA ERROR failure'],0),(rows+['Error in breakpoint'],0),(rows[1:],0),
                           ([x.replace('body=123456','body=0') for x in rows],0),
                           ([x for x in rows if 'index=E ' not in x],0),
                           ([x.replace('timeout=1','timeout=0') for x in rows],0)):
            with self.assertRaises(ValueError):check_route(bad,status)

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('log',nargs='?',type=Path)
    p.add_argument('--status',type=int);p.add_argument('--original',type=Path,default=Path('tmp/runtime-data/Alone In The Dark'))
    p.add_argument('--original-only',action='store_true')
    p.add_argument('--selftest',action='store_true');a=p.parse_args()
    if a.selftest:raise SystemExit(not unittest.TextTestRunner().run(unittest.defaultTestLoader.loadTestsFromTestCase(RouteChecks)).wasSuccessful())
    try:
        check_original(a.original)
        if a.original_only:
            print('PASS original PAK route bytes: menu timeout, caller, fifteen-image loop and sole direct PRESENT string reference')
            raise SystemExit(0)
        with a.log.open() as f:check_route([line.rstrip() for line in f if line.startswith(('ARM PAK_IDLE','PAK_IDLE','PASS file-reference','FAIL ','LUA ERROR','Error in breakpoint'))],a.status)
        with a.log.open() as f:pairs=capture(f,str(a.original))
        _,reads=validate(pairs,a.original.stat().st_size,('itd_ress.pak','present.pak'))
        print('PASS original PAK idle route: natural 900-tick timeout, 15 image loads, paired ITD_RESS/PRESENT reads')
        for name,count in sorted(reads.items()):print(f'read {name}: {count} bytes')
    except (ValueError,OSError,AttributeError,KeyError) as error:raise SystemExit('FAIL original PAK idle route: '+str(error))
