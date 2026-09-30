#!/usr/bin/env python3
"""Verify original already-detached resource errors and ownership preservation."""
import argparse
import hashlib
from pathlib import Path
import re
from resource_fork import read_resource_fork
ROOT=Path(__file__).resolve().parents[1]
LABELS=['original','repeat','lock','locked','unlock','empty','empty-detach','nil']

def pairs(text,labels):
    rows=[line for line in text.splitlines() if line.startswith(('DET_ENTER ','DET_RETURN '))]
    if len(rows)!=2*len(labels):raise ValueError('call count')
    result=[]
    for i,label in enumerate(labels):
        e,r=rows[2*i:2*i+2]
        if not e.startswith('DET_ENTER ') or not r.startswith('DET_RETURN '):raise ValueError('call order')
        e,r=[dict(re.findall(r'(\w+)=([^ ]+)',row)) for row in (e,r)]
        if e['label']!=label or r['label']!=label:raise ValueError('call label')
        result.append((e,r))
    return result

def run(text,status,marker,ending):
    if status!=0 or any(s in text for s in ('FAIL','LUA ERROR','Error in sourced command file','Program received signal','timeout')):
        raise ValueError('runner/observer completion')
    if text.count(marker)!=1 or text.count(ending)!=1:raise ValueError('missing/duplicate completion')

def original(text,entry):
    code=next(r.body for r in read_resource_fork(ROOT/'tmp/runtime-data/Alone In The Dark') if r.kind==b'CODE' and r.rid==13)[0x20e:0x222]
    if hashlib.sha256(code).hexdigest()!='74a62a301aac1f07bfe314a37a641f5ca737b48496971e47c257bce361fbf101':raise ValueError('original Dan2 bytes')
    live=re.findall(r'^DET_BYTES data=([0-9A-F]+)$',text,re.M)
    relocated=bytearray(code)
    relocated[12:16]=((int.from_bytes(code[12:16],'big')+int(entry['a5'],16))&0xffffffff).to_bytes(4,'big')
    if live!=[relocated.hex().upper()]:raise ValueError('live bytes/A5 relocation')

def detached(e,r):
    if int(r['sp'],16)!=int(e['sp'],16)+4 or r['handle']!=e['handle'] or r['master']!=e['master']:
        raise ValueError('detached handle/stack preservation')
    if int(r['res'],16)!=0xff40 or int(r['d0'],16)!=0xff40 or int(r['a0'],16)!=0 or r['mem']!=e['mem']:
        raise ValueError('detached error result/MemErr')
    for reg in ['d'+str(i) for i in range(1,8)]+['a'+str(i) for i in range(1,7)]:
        if e[reg]!=r[reg]:raise ValueError('preserved register '+reg)

def bodies(side):
    before=(ROOT/f'tmp/detached-{side}-before.bin').read_bytes()
    after=(ROOT/f'tmp/detached-{side}-after.bin').read_bytes()
    if len(before)!=2056 or after!=before:raise ValueError('owned table preservation')
    return before

def reference(text,status):
    run(text,status,'PASS original detached resource and seven fixtures','Exited via the debugger')
    rows=pairs(text,LABELS);original(text,rows[0][0]);bodies('reference')
    for label,(e,r) in zip(LABELS,rows):
        if label in ('lock','unlock','empty'):
            expected=(int(e['master'],16)|0x80000000) if label=='lock' else (int(e['master'],16)&0xffffff) if label=='unlock' else 0
            if int(r['master'],16)!=expected or r['sp']!=e['sp'] or int(r['d0'],16)!=0 or int(r['mem'],16)!=0 or r['res']!=e['res']:
                raise ValueError('fixture setup '+label)
        else:detached(e,r)
    return 'PASS detached reference: original call and repeat/locked/empty/nil errors, body, ABI and original bytes'

def native(text,status):
    from check_native_driver import check
    check(text,status)
    if text.count('PASS native detached resource original call')!=1:raise ValueError('native completion')
    e,r=pairs(text,['original'])[0];original(text,e);detached(e,r)
    # The independently generated colour-table seed is platform-specific.
    if bodies('native')[4:]!=bodies('reference')[4:]:raise ValueError('native/reference table contents')
    return 'PASS detached native: original error/ABI, owned table preserved, driver/MDRV guard and next stop'

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('reference',type=Path);p.add_argument('--status',type=int,required=True);p.add_argument('--native',type=Path);p.add_argument('--native-status',type=int);a=p.parse_args()
    try:
        print(reference(a.reference.read_text(),a.status))
        if a.native:print(native(a.native.read_text(),a.native_status))
    except (ValueError,OSError,KeyError) as error:raise SystemExit('FAIL detached resource: '+str(error))
