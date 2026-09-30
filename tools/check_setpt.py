#!/usr/bin/env python3
"""Pair original SetPt's point write, surrounding bytes and native ABI."""
import argparse
import hashlib
from pathlib import Path
from check_choice_services import one
from check_getgworld import fields
from resource_fork import read_resource_fork


def check(reference,native,reference_status,native_status,resource,folder):
    code=next(r.body for r in read_resource_fork(resource) if r.kind==b'CODE' and r.rid==4)[0x4f7a:0x4f8a]
    assert hashlib.sha256(code).hexdigest()=='6e383555df80d58e37af9cd2bfa00fa3592060e1864a5782a2b4fde84d5bd102','original SetPt instructions'
    for side,text,status in [('reference',reference,reference_status),('native',native,native_status)]:
        assert status==0 and not any(x in text for x in ('FAIL','Error in','LUA ERROR','TIMEOUT','Program received signal')),side+' run'
        marker='PASS original SetPt' if side=='reference' else 'PASS native SetPt next-stop original-MDRV=absent'
        ending='Exited via the debugger' if side=='reference' else '[Inferior 1 (Remote target) detached]'
        assert text.count(marker)==text.count(ending)==1,side+' normal completion'
        e=fields(one(text,r'POINT_ENTER (.*)'));r=fields(one(text,r'POINT_RETURN (.*)'))
        assert bytes.fromhex(one(text,r'POINT_BYTES data=([0-9A-F]+)'))==code,side+' live bytes'
        args=bytes.fromhex(one(text,r'POINT_ENTER .*args=([0-9A-F]+) .*'))
        assert int.from_bytes(args[4:8],'big')==e['point'] and args[:4]==bytes(4),side+' original point arguments'
        assert r['sp']==e['sp']+8 and r['value']==int.from_bytes(args[:4],'big'),side+' stack and point result'
        assert all(r[k]==e[k] for k in ['d0','d1','d2','d3','d4','d5','d6','d7','a1','a2','a3','a4','a5','a6']),side+' preserved registers'
        before=(folder/f'point-{side}-before.bin').read_bytes();after=(folder/f'point-{side}-after.bin').read_bytes()
        assert len(before)==len(after)==12 and after==before[:4]+args[:4]+before[8:],side+' exact four-byte write and preserved neighbours'
    print('PASS paired SetPt: original/live bytes, arguments, point write, surrounding bytes, stack/register contract; '+one(native,r'POINT_NEXT (state=3 trap=A976 selector=FFFFFFFF segment=12 offset=583A manager=UNKNOWN MANAGER routine=UNKNOWN TRAP windows=(?:194|220) services=\d+/\d+)'))


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('reference',type=Path);p.add_argument('native',type=Path)
    p.add_argument('--reference-status',type=int,required=True);p.add_argument('--native-status',type=int,required=True)
    p.add_argument('--resource',type=Path,default=Path('tmp/runtime-data/Alone In The Dark'))
    p.add_argument('--folder',type=Path,default=Path('tmp'))
    a=p.parse_args();check(a.reference.read_text(),a.native.read_text(),a.reference_status,a.native_status,a.resource,a.folder)
