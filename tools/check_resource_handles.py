#!/usr/bin/env python3
"""Validate a completed Mac metadata/lazy resource-handle capture and original bytes."""
import argparse
import hashlib
from pathlib import Path
import re
from resource_fork import read_resource_fork

LABELS='info-general info-nil load-off lookup-unloaded named-unloaded info-unloaded load-explicit info-loaded empty info-emptied reload load-on empty-again lookup-enabled detach info-detached load-detached release-nil'.split()
EMPTY={'lookup-unloaded','named-unloaded','info-unloaded','empty','info-emptied','empty-again'}
ERROR={'info-nil','info-detached','release-nil'}
SEEDED={'load-off','load-on','empty','empty-again'}
PRESERVE={'load-off','load-on','named-unloaded','load-explicit','reload','load-detached','release-nil'}

def validate(text,status):
    if status or any(x in text for x in ('FAIL ','LUA ERROR','Error in breakpoint')) or text.count('PASS resource handle capture complete')!=1 or 'ARM resource-handles Engine+$3CDC bytes=a820245f' not in text:
        raise ValueError('runner, byte check or completion')
    rows=[{k:v if k=='label' else int(v,16) for k,v in re.findall(r'(\w+)=(\S+)',line)} for line in text.splitlines() if line.startswith('RHANDLE label=')]
    if len(rows)!=len(LABELS):raise ValueError('stage count')
    general=rows[0]['handle'];other=rows[3]['handle']
    if not general or not other or general==other:raise ValueError('distinct handles')
    for n,(r,label) in enumerate(zip(rows,LABELS),1):
        error=0xff40 if label in ERROR else 0x8888 if label in SEEDED else 0
        d0=0x12345678 if label in PRESERVE else 0xff40 if label in ('info-nil','info-detached') else 0
        resload=0xff if n<=2 else 0 if n<12 else 1
        if (r['stage'],r['label'],r['error'],r['d0'],r['resload'])!=(n,label,error,d0,resload):raise ValueError(label+' stage/error/D0/ResLoad')
        if r['sp']!=r['expectedsp'] or r['handle']!=(general if n<=3 else other):raise ValueError(label+' stack/handle')
        if bool(r['data'])==(label in EMPTY):raise ValueError(label+' empty/resident state')
        expected=[0xcccc,0xcccccccc,0xcccccccc,0xcccccccc,0xcccccccc,0xcccccccc]
        if label=='info-general':expected=[128,0x53545223,0x0747656e,0x6572616c,0xcccccccc,0xcccccccc]
        elif label in ('info-unloaded','info-loaded','info-emptied'):expected=[2001,0x53545223,0x0e457272,0x6f72204d,0x65737361,0x676573cc]
        elif label in ('info-nil','info-detached'):expected=[0xffff,0,0x00cccccc,0xcccccccc,0xcccccccc,0xcccccccc]
        if [r[k] for k in ('id','type','name0','name1','name2','name3')]!=expected:raise ValueError(label+' metadata/output canaries')
    reuse=re.findall(r'RHANDLE LOOKUP result=([0-9A-F]+) expected=([0-9A-F]+)',text)
    if len(reuse)!=2 or any(int(a,16)!=other or int(b,16)!=other for a,b in reuse):raise ValueError('named/enabled lookup identity')
    # Detach and subsequent calls retain the already loaded caller-owned body.
    data=rows[13]['data']
    if any(r['data']!=data for r in rows[14:]):raise ValueError('detached body preservation')
    return 'PASS resource handle reference: 18 calls; metadata, lazy named/ID lookup, empty/reload, detach, errors, D0 and stack'

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('log',type=Path);p.add_argument('--status',type=int,required=True);p.add_argument('--original',type=Path,required=True);p.add_argument('--dump',type=Path,default=Path('tmp/mac-loaded-resource.bin'));a=p.parse_args()
    try:
        print(validate(a.log.read_text(),a.status))
        resources=read_resource_fork(a.original)
        gloss=next(r.body for r in resources if r.kind==b'CODE' and r.rid==8)
        for offset,wanted in ((0x3cc,'a99b42a7'),(0x3e0,'a99b200c'),(0x3f4,'a9a8302e')):
            if gloss[offset:offset+4]!=bytes.fromhex(wanted):raise ValueError('Gloss original call bytes')
        original=next(r.body for r in resources if r.kind==b'STR#' and r.rid==2001)
        actual=a.dump.read_bytes()
        if actual!=original:raise ValueError('reloaded resource body')
        print(f'PASS Error Messages reloaded Mac resource: bytes={len(actual)} SHA256={hashlib.sha256(actual).hexdigest()} Gloss call bytes=exact')
    except (ValueError,KeyError,OSError,StopIteration) as e:raise SystemExit('FAIL resource handle reference: '+str(e))
