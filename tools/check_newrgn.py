#!/usr/bin/env python3
"""Pair the original NewRgn allocation with the native owned heap handle."""
import argparse
import hashlib
from pathlib import Path
from check_choice_services import one
from check_getgworld import fields
from resource_fork import read_resource_fork


def check(reference,native,reference_status,native_status,resource,folder):
    code=next(r.body for r in read_resource_fork(resource) if r.kind==b'CODE' and r.rid==10)[0x1d9c:0x1daa]
    assert hashlib.sha256(code).hexdigest()=='fb490c8d89ec18e2450bab69eff1861a43f579444050b9850a75e26b8c3390b7','original NewRgn instructions'
    for side,text,status in [('reference',reference,reference_status),('native',native,native_status)]:
        assert status==0 and not any(x in text for x in ('FAIL','Error in','LUA ERROR','TIMEOUT','Program received signal')),side+' run'
        marker='PASS original NewRgn' if side=='reference' else 'PASS native NewRgn next-stop original-MDRV=absent'
        ending='Exited via the debugger' if side=='reference' else '[Inferior 1 (Remote target) detached]'
        assert text.count(marker)==text.count(ending)==1,side+' normal completion'
        e=fields(one(text,r'RGN_ENTER (.*)'));r=fields(one(text,r'RGN_RETURN (.*)'))
        assert bytes.fromhex(one(text,r'RGN_BYTES data=([0-9A-F]+)'))==code,side+' live instructions'
        assert e['result']==0 and r['sp']==e['sp'] and r['handle'] and r['body'] and r['handle']!=r['body'],side+' allocated stack result'
        assert e['zone']==r['zone'] and e['memerr']==r['memerr']==0,side+' zone and successful allocation'
        assert r['a0']==r['body']+10 and all(r[k]==e[k] for k in ['d0','d1','d2','d3','d4','d5','d6','d7','a1','a2','a3','a4','a5','a6']),side+' register contract'
        assert (folder/f'newrgn-{side}.bin').read_bytes()==bytes.fromhex('000a0000000000000000'),side+' empty region'
    size=fields(one(reference,r'RGN_SIZE (.*)'));flags=fields(one(reference,r'RGN_FLAGS (.*)'));owner=fields(one(reference,r'RGN_OWNER (.*)'))
    assert size=={'size':10,'memerr':0} and flags=={'flags':0,'memerr':0} and owner['owner']==owner['zone'] and owner['memerr']==0,'Mac Memory Manager ownership queries'
    assert reference.count('PASS NewRgn ownership queries')==1,'reference query completion'
    n=fields(one(native,r'RGN_NATIVE (.*)'))
    assert n['size']==10 and n['flags']==0 and n['owner']==n['zone'] and n['memerr']==0,'native heap owner/extent/flags'
    print('PASS paired NewRgn: original/live bytes, stack/register contract, real owned 10-byte unlocked empty region; '+one(native,r'RGN_NEXT (state=3 trap=AA14 selector=FFFFFFFF segment=13 offset=2BE manager=COLOR QUICKDRAW routine=RGBFORECOLOR windows=(?:101|127) services=(?:163/163|171/171))'))


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('reference',type=Path);p.add_argument('native',type=Path)
    p.add_argument('--reference-status',type=int,required=True);p.add_argument('--native-status',type=int,required=True)
    p.add_argument('--resource',type=Path,default=Path('tmp/runtime-data/Alone In The Dark'))
    p.add_argument('--folder',type=Path,default=Path('tmp'))
    a=p.parse_args();check(a.reference.read_text(),a.native.read_text(),a.reference_status,a.native_status,a.resource,a.folder)
