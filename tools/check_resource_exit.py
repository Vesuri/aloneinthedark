#!/usr/bin/env python3
"""Require a real Finder transition and exact dirty-resource readback after relaunch."""
import argparse
from pathlib import Path
import re
from resource_fork import read_resource_fork
LABELS='application create map open allocate add-dirty attrs-dirty application reopen lookup-after-exit close delete current-final'.split()
def validate(text,status,resources):
    marker='ARM resource-exit Engine+$3CDC bytes=a820245f CODE1+$0048/$04AA checked'
    if status or any(x in text for x in ('FAIL ','LUA ERROR','Error in breakpoint')) or text.count(marker)!=2 or text.count('PASS resource exit capture complete; scratch deleted')!=1:raise ValueError('runner, original-byte guards or completion')
    boundary='REXIT original-runtime-exit dirty-open=1';finder='REXIT Finder after original runtime exit'
    if text.count(boundary)!=1 or text.count(finder)!=1 or not text.index(boundary)<text.index(finder)<text.index('REXIT label=reopen'):raise ValueError('positive exit/Finder/relaunch sequence')
    rows=[{k:v if k=='label' else int(v,16) for k,v in re.findall(r'(\w+)=(\S+)',line)} for line in text.splitlines() if line.startswith('REXIT label=')]
    if [r['label'] for r in rows]!=LABELS:raise ValueError('ordered 13-call sequence')
    for i,r in enumerate(rows):
        s=r['label'];current=s in {'application','current-final'};opened=s in {'open','reopen'}
        error=0x8888 if current or s in {'create','allocate','delete'} else 0
        mem=0x7777 if current or s in {'create','map','attrs-dirty','delete'} else 0
        d0=0x12345678 if current or opened or s=='attrs-dirty' else 4 if s=='map' else 0
        delta=2 if current or opened or s=='attrs-dirty' else 4 if s=='lookup-after-exit' else 0
        stage=i+1 if i<7 else 0x1000+i-6
        if (r['stage'],r['error'],r['mem'],r['d0'],r['sp'])!=(stage,error,mem,d0,r['base']-delta):raise ValueError(s+' registers/errors/stack')
        if current:
            if not r['app'] or r['app']!=r['result']:raise ValueError(s+' application current')
        elif opened:
            if r['result'] in (0,0xffff,r['app']) or r['result']!=r['ref']:raise ValueError(s+' open reference')
        elif s in {'allocate','lookup-after-exit'}:
            if not r['handle'] or r['result']!=r['handle']:raise ValueError(s+' returned handle')
        elif r['result']!=(2 if s=='attrs-dirty' else 0):raise ValueError(s+' result')
        if s in {'allocate','add-dirty','attrs-dirty','lookup-after-exit'}:
            if not r['master']&0xffffff or r['master']>>24!=(0 if s=='allocate' else 0x20) or r['body']!=0x45584954:raise ValueError(s+' exact EXIT body/flags')
    if len({rows[i]['handle'] for i in (4,5,6)})!=1:raise ValueError('dirty live handle identity')
    code=next(r.body for r in resources if r.kind==b'CODE' and r.rid==1)
    for off,raw in ((0x48,'2a780904206d006c4e90a9f4'),(0x4aa,'226d0068303ca9f020690008a047303ca9f120690014a047303ca9f420690020a0472049a01f4e75')):
        if code[off:off+len(raw)//2]!=bytes.fromhex(raw):raise ValueError('original runtime exit/unpatch bytes')
    engine=next(r.body for r in resources if r.kind==b'CODE' and r.rid==7)
    if engine[0x3cdc:0x3ce0]!=bytes.fromhex('a820245f'):raise ValueError('original Engine gate')
    return 'PASS resource exit reference: dirty open resource survives original runtime exit, Finder transition and relaunch; exact EXIT body, close/delete and current restoration'
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('log',type=Path);p.add_argument('--status',type=int,required=True);p.add_argument('--original',type=Path,required=True);a=p.parse_args()
    try:print(validate(a.log.read_text(),a.status,read_resource_fork(a.original)))
    except (ValueError,KeyError,OSError,StopIteration) as error:raise SystemExit('FAIL resource exit reference: '+str(error))
