#!/usr/bin/env python3
"""Check Mac dirty resource lifecycle evidence, including live-handle state."""
import argparse
from pathlib import Path
import re
from resource_fork import read_resource_fork

LABELS='application create-a map-a open-a allocate-a add-a update-a change-release release-dirty lookup-released attrs-released change-detach detach-dirty attrs-still-dirty write-before-detach detach-written attrs-detached lookup-detached dispose-detached change-empty empty-dirty attrs-empty load-empty attrs-loaded update-loaded change-close close-dirty reopen-a lookup-closed create-b map-b open-b allocate-b add-b use-app close-noncurrent-a current-after-a close-noncurrent-dirty-b current-after-b reopen-b lookup-noncurrent-closed close-b delete-a delete-b current-final'.split()
CURRENT={'application','current-after-a','current-after-b','current-final'}
OS={'create-a','create-b','allocate-a','allocate-b','dispose-detached','empty-dirty','delete-a','delete-b'}
PRESERVE_MEM=CURRENT|{'create-a','create-b','map-a','map-b','release-dirty','lookup-released','detach-dirty','update-loaded','use-app','delete-a','delete-b'}|{s for s in LABELS if s.startswith('attrs-')}
PRESERVE_D0=CURRENT|{'open-a','open-b','reopen-a','reopen-b','update-a','update-loaded','release-dirty','load-empty'}|{s for s in LABELS if s.startswith('attrs-')}

def validate(text,status,resources):
    if status or any(x in text for x in ('FAIL ','LUA ERROR','Error in breakpoint')) or text.count('PASS resource dirty lifecycle capture complete; scratch deleted')!=1 or text.count('ARM resource-dirty Engine+$3CDC bytes=a820245f')!=1:
        raise ValueError('runner, original gate or completion')
    rows=[{k:v if k=='label' else int(v,16) for k,v in re.findall(r'(\w+)=(\S+)',line)} for line in text.splitlines() if line.startswith('RDIRTY label=')]
    if [r['label'] for r in rows]!=LABELS:raise ValueError('ordered 45-call sequence')
    by={r['label']:r for r in rows};app=by['application']['result']
    for n,r in enumerate(rows,1):
        s=r['label'];lookup=s.startswith('lookup-');opened=s in {'open-a','open-b','reopen-a','reopen-b'}
        err=0x8888 if s in OS|CURRENT else 0xff3a if s=='detach-dirty' else 0xff40 if s=='attrs-detached' else 0
        d0=0x12345678 if s in PRESERVE_D0 else 4 if s in {'map-a','map-b'} else err if s=='detach-dirty' else 0
        delta=4 if lookup else 2 if opened or s in CURRENT or s.startswith('attrs-') else 0
        if (r['stage'],r['error'],r['mem'],r['d0'],r['sp'])!=(n,err,0x7777 if s in PRESERVE_MEM else 0,d0,r['base']-delta):raise ValueError(s+' registers/errors/stack')
        if s in CURRENT:
            if not app or r['result']!=app:raise ValueError(s+' current file')
        elif opened:
            if r['result'] in (0,0xffff,app) or r['result']!=r['other' if s.endswith('-b') else 'ref']:raise ValueError(s+' reference')
        elif lookup or s.startswith('allocate-'):
            if not r['result'] or r['result']!=r['handle']:raise ValueError(s+' handle result')
        elif s.startswith('attrs-'):
            expected={'attrs-released':2,'attrs-still-dirty':2,'attrs-detached':0,'attrs-empty':0xe002,'attrs-loaded':0x600}[s]
            if r['result']!=expected:raise ValueError(s+' attributes (including captured upper bits)')
        elif r['result']:raise ValueError(s+' scalar result')
    groups=[('allocate-a',0x41414141,0),('add-a update-a',0x41414141,0x20),('change-release release-dirty lookup-released attrs-released',0x42424242,0x20),('change-detach detach-dirty attrs-still-dirty write-before-detach',0x43434343,0x20),('detach-written attrs-detached',0x43434343,0),('lookup-detached dispose-detached load-empty attrs-loaded update-loaded',0x43434343,0x20),('change-empty',0x44444444,0x20),('change-close lookup-closed',0x45454545,0x20),('allocate-b',0x46464646,0),('add-b use-app close-noncurrent-a current-after-a lookup-noncurrent-closed',0x46464646,0x20)]
    for names,body,flag in groups:
        for name in names.split():
            r=by[name]
            if not r['handle'] or not r['master']&0xffffff or r['master']>>24!=flag or r['body']!=body:raise ValueError(name+' live body/resource flag')
    for names in ['allocate-a add-a update-a change-release release-dirty lookup-released attrs-released change-detach detach-dirty attrs-still-dirty write-before-detach detach-written attrs-detached','lookup-detached dispose-detached change-empty empty-dirty attrs-empty load-empty attrs-loaded update-loaded change-close','allocate-b add-b use-app close-noncurrent-a current-after-a']:
        if len({by[s]['handle'] for s in names.split()})!=1:raise ValueError('live handle identity')
    if by['lookup-detached']['handle']==by['detach-written']['handle']:raise ValueError('detached handle reused while live')
    if any(by[s]['master'] for s in ['empty-dirty','attrs-empty']):raise ValueError('empty body retained')
    if by['open-b']['other'] in (app,by['open-b']['ref']):raise ValueError('independent open files')
    engine=next(r.body for r in resources if r.kind==b'CODE' and r.rid==7)
    if engine[0x3cdc:0x3ce0]!=bytes.fromhex('a820245f'):raise ValueError('original Engine gate')
    return 'PASS resource dirty reference: 45 calls; dirty release/detach/empty/reload, current/noncurrent close, exact persisted bodies and cleanup'

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('log',type=Path);p.add_argument('--status',type=int,required=True);p.add_argument('--original',type=Path,required=True);a=p.parse_args()
    try:print(validate(a.log.read_text(),a.status,read_resource_fork(a.original)))
    except (ValueError,KeyError,OSError,StopIteration) as error:raise SystemExit('FAIL resource dirty reference: '+str(error))
