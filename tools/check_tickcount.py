#!/usr/bin/env python3
"""Verify TickCount's original ABI and the native VBI-backed clock result."""
import argparse
import hashlib
from pathlib import Path
from check_choice_services import one
from check_getgworld import fields
from resource_fork import read_resource_fork


def require(ok,message):
    if not ok:
        raise ValueError(message)


def between(start,value,end):
    span=(end-start)&0xffffffff
    return span<0x80000000 and ((value-start)&0xffffffff)<=span


def check(reference,native,reference_status,native_status,resource):
    code=next(r.body for r in read_resource_fork(resource) if r.kind==b'CODE' and r.rid==4)[0x41ec:0x41f8]
    require(hashlib.sha256(code).hexdigest()=='5e243de4915947497349652df6eab9bad8c9017ada06ca40f852a143ac6e82d1','original TickCount instructions')
    for side,text,status in [('reference',reference,reference_status),('native',native,native_status)]:
        require(status==0 and all(s not in text for s in ('FAIL','Error in','LUA ERROR','TIMEOUT','Program received signal')),side+' run')
        marker='PASS original TickCount\n' if side=='reference' else 'PASS native TickCount\n'
        ending='Exited via the debugger' if side=='reference' else '[Inferior 1 (Remote target) detached]'
        require(text.count(marker)==text.count(ending)==1,side+' normal completion')
        e=fields(one(text,r'TICK_ENTER (.*)'));r=fields(one(text,r'TICK_RETURN (.*)'))
        require(bytes.fromhex(one(text,r'TICK_ENTER .*bytes=([0-9A-F]+) .*'))==code,side+' live bytes')
        require(e['result']==0 and e['ticks']!=0 and r['sp']==e['sp'],side+' result slot and stack')
        require(r['d1']==0 and r['a1']==e['sp'],side+' volatile result registers')
        require(all(e[k]==r[k] for k in ['d0','d2','d3','d4','d5','d6','d7','a0','a2','a3','a4','a5','a6']),side+' preserved registers')
        require(between(e['ticks'],r['result'],r['ticks']),side+' observed clock result')
    fixture=fields(one(reference,r'TICK_FIXTURE (.*)'))
    require(fixture['result']==fixture['ticks']==0xfedcba98 and fixture['d1']==0 and fixture['a1']==fixture['sp'],'full-width source/result and full D1 clear')
    require(reference.count('PASS TickCount full-word fixture')==1,'reference CPU fixture completion')
    a=fields(one(native,r'TICK_CLOCK phase=before (.*)'));b=fields(one(native,r'TICK_CLOCK phase=after (.*)'))
    require(a['ticks']==a['shadow'] and b['ticks']==b['shadow'],'native shadow mirrors VBI counter at this call')
    elapsed_fields=(b['fields']-a['fields'])&65535;elapsed_ticks=(b['ticks']-a['ticks'])&0xffffffff
    require(elapsed_fields*6//5<=elapsed_ticks<=elapsed_fields*6//5+1,'PAL fields to 60 Hz clock')
    require(native.count('PASS native TickCount next-stop original-MDRV=absent')==1,'progression and MDRV guard')
    print('PASS paired TickCount: original bytes/ABI, full-width result, native clock source and field accounting; '+one(native,r'TICK_NEXT (state=3 trap=A856 selector=FFFFFFFF segment=7 offset=FF6 manager=QUICKDRAW routine=OBSCURECURSOR windows=(?:113|139) services=(?:431/431|439/439))'))


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('reference',type=Path);p.add_argument('native',type=Path)
    p.add_argument('--reference-status',type=int,required=True);p.add_argument('--native-status',type=int,required=True)
    p.add_argument('--resource',type=Path,default=Path('tmp/runtime-data/Alone In The Dark'))
    a=p.parse_args();check(a.reference.read_text(),a.native.read_text(),a.reference_status,a.native_status,a.resource)
