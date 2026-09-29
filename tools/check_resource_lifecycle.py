#!/usr/bin/env python3
"""Require the completed Mac purge/release lifecycle capture and exact reload bytes."""
import argparse
import hashlib
from pathlib import Path
import re
from resource_fork import read_resource_fork

LABELS='lookup state-loaded purge state-purged reload state-reloaded lock purge-locked state-locked release-locked lookup-after-locked-release unlock release lookup-after-release empty state-empty lock-empty hpurge-empty unlock-empty setstate-empty release-empty lookup-after-empty-release empty-for-detach detach-empty load-empty-detached release-detached load-nil detach-nil'.split()
OS={'state-loaded','purge','state-purged','state-reloaded','lock','purge-locked','state-locked','unlock','empty','state-empty','lock-empty','hpurge-empty','unlock-empty','setstate-empty','empty-for-detach'}
NIL_STATE={'state-purged','state-empty','lock-empty','hpurge-empty','unlock-empty','setstate-empty'}
RELEASE={'release-locked','release','release-empty'}
PRESERVE=RELEASE|{'reload','load-empty-detached','release-detached','load-nil'}
EMPTY={'purge','state-purged','empty','state-empty','lock-empty','hpurge-empty','unlock-empty','setstate-empty','empty-for-detach','detach-empty','load-empty-detached','release-detached','load-nil','detach-nil'}

def validate(text,status):
    if status or any(x in text for x in ('FAIL ','LUA ERROR','Error in breakpoint')) or text.count('PASS resource lifecycle capture complete')!=1 or 'ARM resource-lifecycle Engine+$3CDC bytes=a820245f' not in text:
        raise ValueError('runner, original bytes or completion')
    rows=[{k:v if k=='label' else int(v,16) for k,v in re.findall(r'(\w+)=(\S+)',line)} for line in text.splitlines() if line.startswith('RLIFE ')]
    if len(rows)!=len(LABELS):raise ValueError('stage count')
    previous=None
    for n,(r,label) in enumerate(zip(rows,LABELS),1):
        err=0x8888 if label in OS else 0xff40 if label in ('load-empty-detached','release-detached','detach-nil') else 0
        mem=0xff94 if label in ('purge','purge-locked') else 0xff93 if label in NIL_STATE|{'detach-empty'} else 0x7777 if label in ('load-empty-detached','release-detached','load-nil','detach-nil') else 0
        d0=0x12345678 if label in PRESERVE else 0xffffff94 if label in ('purge','purge-locked') else 0xffffff93 if label in NIL_STATE else 0x60 if label in ('state-loaded','state-reloaded') else 0xe0 if label=='state-locked' else 0xff40 if label=='detach-nil' else 0
        if (r['label'],r['stage'],r['error'],r['memerror'],r['d0'])!=(label,n,err,mem,d0):raise ValueError(label+' result/registers')
        if not r['handle'] or r['sp']!=r['expectedsp']:raise ValueError(label+' handle/stack')
        if previous and not label.startswith('lookup') and r['handle']!=previous:raise ValueError(label+' master identity')
        previous=r['handle']
        if label in EMPTY:
            if r['master']:raise ValueError(label+' did not empty/preserve empty')
        elif label in RELEASE:
            # This reference frees the slot into the master-pointer free list.
            # A subsequent lookup can reuse the slot; its address is not a new identity.
            if r['master']>>24:raise ValueError(label+' slot not released')
        else:
            flags=0xe0 if label in ('lock','purge-locked','state-locked') else 0x60
            if not r['master']&0xffffff or r['master']>>24!=flags:raise ValueError(label+' resident flags')
    return 'PASS resource lifecycle reference: 28 calls; purge/lock/release/empty/detached/nil, flags, errors and stack'

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('log',type=Path);p.add_argument('--status',type=int,required=True);p.add_argument('--original',type=Path,required=True);p.add_argument('--dump',type=Path,default=Path('tmp/mac-purged-resource.bin'));a=p.parse_args()
    try:
        print(validate(a.log.read_text(),a.status))
        item=next(r for r in read_resource_fork(a.original) if r.kind==b'CREL' and r.rid==13)
        if item.attrs!=0x28:raise ValueError('original purgeable attributes')
        actual=a.dump.read_bytes()
        if actual!=item.body:raise ValueError('purged/reloaded original body')
        print(f'PASS purged/reloaded CREL 13: bytes={len(actual)} SHA256={hashlib.sha256(actual).hexdigest()} attrs=28')
    except (ValueError,KeyError,OSError,StopIteration) as e:raise SystemExit('FAIL resource lifecycle reference: '+str(e))
