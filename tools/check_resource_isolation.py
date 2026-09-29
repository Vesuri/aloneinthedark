#!/usr/bin/env python3
"""Check the Mac two-resource WriteResource isolation contract."""
import argparse
from pathlib import Path
import re
from resource_fork import read_resource_fork
LABELS='application create map open allocate-a add-a allocate-b add-b update-baseline change-a change-b write-a attrs-written-a attrs-dirty-b empty-a reload-a empty-b attrs-empty-b reload-b attrs-reloaded-b update-discarded close-first reopen-first lookup-first-a lookup-first-b change-again-a change-again-b write-b attrs-dirty-a attrs-written-b empty-written-b reload-written-b update-both close-second reopen-second lookup-final-a lookup-final-b close-final delete current-final'.split()
def validate(text,status,resources):
    if status or any(x in text for x in ('FAIL ','LUA ERROR','Error in breakpoint')) or text.count('PASS resource isolation capture complete; scratch deleted')!=1 or text.count('ARM resource-isolation Engine+$3CDC bytes=a820245f')!=1:raise ValueError('runner, byte guard or completion')
    rows=[{k:v if k=='label' else int(v,16) for k,v in re.findall(r'(\w+)=(\S+)',line)} for line in text.splitlines() if line.startswith('RISOLATE label=')]
    if [r['label'] for r in rows]!=LABELS:raise ValueError('ordered 40-call sequence')
    by={r['label']:r for r in rows};app=by['application']['result']
    for n,r in enumerate(rows,1):
        s=r['label'];current=s in {'application','current-final'};attrs=s.startswith('attrs-');opened=s in {'open','reopen-first','reopen-second'};lookup=s.startswith('lookup-');allocated=s.startswith('allocate-');empty=s.startswith('empty-')
        os=s in {'create','delete'} or allocated or empty
        error=0x8888 if os or current else 0
        mem=0x7777 if current or attrs or s in {'create','map','delete','update-discarded'} else 0
        d0=0x12345678 if current or attrs or opened or s.startswith(('reload-','update-')) else 4 if s=='map' else 0
        delta=4 if lookup else 2 if current or attrs or opened else 0
        if (r['stage'],r['error'],r['mem'],r['d0'],r['sp'])!=(n,error,mem,d0,r['base']-delta):raise ValueError(s+' registers/errors/stack')
        if current:
            if not app or r['result']!=app:raise ValueError(s+' current file')
        elif opened:
            if r['result'] in (0,0xffff,app) or r['result']!=r['ref']:raise ValueError(s+' resource ref')
        elif lookup or allocated:
            if not r['handle'] or r['result']!=r['handle']:raise ValueError(s+' returned handle')
        elif attrs:
            # The System wrapper's undefined upper byte is traced/poison-verified.
            if r['result']&255!=(2 if s in {'attrs-dirty-a','attrs-dirty-b','attrs-empty-b'} else 0):raise ValueError(s+' defined attribute byte')
        elif r['result']:raise ValueError(s+' result')
        if empty or s=='attrs-empty-b':
            if r['master']:raise ValueError(s+' master not empty')
    bodies={0x41414141:'allocate-a add-a',0x42424242:'allocate-b add-b update-baseline reload-b attrs-reloaded-b update-discarded lookup-first-b',0x43434343:'change-a write-a attrs-written-a reload-a lookup-first-a',0x44444444:'change-b attrs-dirty-b',0x45454545:'change-again-a attrs-dirty-a lookup-final-a',0x46464646:'change-again-b write-b attrs-written-b reload-written-b update-both lookup-final-b'}
    for body,names in bodies.items():
        for s in names.split():
            r=by[s]
            if r['body']!=body or not r['master']&0xffffff or r['master']>>24!=(0 if s.startswith('allocate-') else 0x20):raise ValueError(s+' exact live body/flags')
    groups=['allocate-a add-a change-a write-a attrs-written-a empty-a reload-a','allocate-b add-b change-b attrs-dirty-b empty-b attrs-empty-b reload-b attrs-reloaded-b','lookup-first-a change-again-a attrs-dirty-a','lookup-first-b change-again-b write-b attrs-written-b empty-written-b reload-written-b']
    for group in groups:
        if len({by[s]['handle'] for s in group.split()})!=1:raise ValueError('live handle identity')
    for a,b in [('allocate-a','allocate-b'),('lookup-first-a','lookup-first-b'),('lookup-final-a','lookup-final-b')]:
        if by[a]['handle']==by[b]['handle']:raise ValueError('independent resource handles')
    for rid,offset,raw in [(7,0x3cdc,'a820245f'),(8,0x0906,'a9aa2f0b'),(8,0x090a,'a9b0204b')]:
        segment=next(r.body for r in resources if r.kind==b'CODE' and r.rid==rid)
        if segment[offset:offset+4]!=bytes.fromhex(raw):raise ValueError('original resource call bytes')
    return 'PASS resource isolation reference: 40 calls; each write affects only its selected resource, discarded dirty body reloads baseline, update persists remaining change, exact reopen/cleanup'
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('log',type=Path);p.add_argument('--status',type=int,required=True);p.add_argument('--original',type=Path,required=True);a=p.parse_args()
    try:print(validate(a.log.read_text(),a.status,read_resource_fork(a.original)))
    except (ValueError,KeyError,OSError,StopIteration) as e:raise SystemExit('FAIL resource isolation reference: '+str(e))
