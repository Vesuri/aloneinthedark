#!/usr/bin/env python3
"""Validate the scratch-only Mac resource-file and search-chain capture."""
import argparse
from pathlib import Path
import re
from resource_fork import read_resource_fork
LABELS='application baseline-chain-strings baseline-chain-probes create-a-file create-a-map open-a current-a empty-a a-shared-allocate a-shared-add a-duplicate-allocate a-duplicate-add a-only-allocate a-only-add update-a open-a-again create-b-file create-b-map open-b current-b b-shared-allocate b-shared-add b-only-allocate b-only-add b-duplicate-allocate b-duplicate-add update-b b-chain-strings b-local-strings b-chain-probes b-local-probes b-chain-shared b-local-shared b-fallback-a b-local-missing b-named-shared use-a current-used-a a-chain-probes a-chain-shared a-cannot-see-b a-named-shared use-app current-app app-chain-probes app-shared use-invalid current-after-invalid use-b-again close-b current-after-close-b after-close-b-shared close-b-again current-after-invalid-close close-a current-after-close-a reopen-a reopened-a-bytes close-reopened-a delete-a delete-b open-missing current-final'.split()
COUNTS={'baseline-chain-strings','baseline-chain-probes','empty-a','b-chain-strings','b-local-strings','b-chain-probes','b-local-probes','a-chain-probes','app-chain-probes'}
OPEN={'open-a','open-a-again','open-b','reopen-a','open-missing'}
LOOKUP={'b-chain-shared','b-local-shared','b-fallback-a','b-local-missing','b-named-shared','a-chain-shared','a-cannot-see-b','a-named-shared','app-shared','after-close-b-shared','reopened-a-bytes'}
def validate(text,status,resources):
    if status or any(x in text for x in ('FAIL ','LUA ERROR','Error in breakpoint')) or text.count('PASS resource files capture complete; scratch deleted')!=1 or 'ARM resource-files Engine+$3CDC bytes=a820245f' not in text:raise ValueError('runner, original bytes, scratch cleanup or completion')
    rows=[{k:v if k=='label' else int(v,16) for k,v in re.findall(r'(\w+)=(\S+)',line)} for line in text.splitlines() if line.startswith('RFILE label=')]
    if len(rows)!=63 or [r['label'] for r in rows]!=LABELS:raise ValueError('ordered stage count')
    by={r['label']:r for r in rows};app=by['application']['result'];a=by['open-a']['result'];b=by['open-b']['result']
    if len({app,a,b})!=3 or any(x in (0,0xffff) for x in (app,a,b)):raise ValueError('distinct file references')
    for n,r in enumerate(rows,1):
        label=r['label'];current=label=='application' or label.startswith('current-')
        os=label in ('create-a-file','create-b-file','delete-a','delete-b') or label.endswith('-allocate')
        error=0x8888 if os or current else 0xff3f if label in ('use-invalid','close-b-again') else 0xffd5 if label=='open-missing' else 0
        preserved=current or label in ('open-a','open-a-again','open-missing','update-a','update-b','b-named-shared','a-named-shared')
        d0=0x12345678 if preserved else 4 if label=='create-a-map' else 10 if label=='create-b-map' else error if error!=0x8888 else 0
        delta=2 if current or label in OPEN|COUNTS else 4 if label in LOOKUP else 0
        if (r['stage'],r['error'],r['d0'],r['sp'])!=(n,error,d0,r['base']-delta):raise ValueError(label+' register/error/stack')
        if not (current or label in OPEN|COUNTS|LOOKUP or label.endswith('-allocate')) and r['result']:raise ValueError(label+' void result')
    for label in ('current-a','current-used-a','current-after-close-b','current-after-invalid-close','open-a-again'):
        if by[label]['result']!=a:raise ValueError(label+' A reference')
    if by['current-b']['result']!=b:raise ValueError('B current')
    for label in ('current-app','current-after-invalid','current-after-close-a','current-final'):
        if by[label]['result']!=app:raise ValueError(label+' application current')
    if by['reopen-a']['result'] in (0,0xffff,app) or by['open-missing']['result']!=0xffff:raise ValueError('reopen/missing')
    wanted={'baseline-chain-probes':0,'empty-a':0,'b-local-strings':1,'b-chain-probes':4,'b-local-probes':2,'a-chain-probes':4,'app-chain-probes':4}
    # System resources differ from the port overlay; compare the measured delta.
    baseline=by['baseline-chain-strings']['result']
    if baseline<2 or by['b-chain-strings']['result']!=baseline+2:raise ValueError('duplicate STR# count delta')
    for label,value in wanted.items():
        if by[label]['result']!=value:raise ValueError(label+' count')
    handles={label[:-9]:by[label]['result'] for label in LABELS if label.endswith('-allocate')}
    if len(set(handles.values()))!=6 or not all(handles.values()):raise ValueError('independent new handles')
    for label,key in [('b-chain-shared','b-shared'),('b-local-shared','b-shared'),('b-named-shared','b-shared'),('b-fallback-a','a-only'),('a-chain-shared','a-shared'),('a-named-shared','a-shared'),('after-close-b-shared','a-shared')]:
        if by[label]['result']!=handles[key]:raise ValueError(label+' search precedence/identity')
    for label in ('b-local-missing','a-cannot-see-b'):
        if by[label]['result']:raise ValueError(label+' unexpectedly found newer file')
    if not by['app-shared']['result'] or by['app-shared']['result'] in handles.values() or not by['reopened-a-bytes']['result']:raise ValueError('application/reopened handle')
    body={int(n,16):int(v,16) for n,v in re.findall(r'RFILE BODY stage=([0-9A-F]+) bytes=([0-9A-F]+)',text)}
    general=next(r.body for r in resources if r.kind==b'STR#' and r.rid==128)
    expected={'b-chain-shared':0x42424242,'b-local-shared':0x42424242,'b-fallback-a':0x31313131,'b-named-shared':0x42424242,'a-chain-shared':0x41414141,'a-named-shared':0x41414141,'app-shared':int.from_bytes(general[:4],'big'),'after-close-b-shared':0x41414141,'reopened-a-bytes':0x41414141}
    if len(body)!=len(expected):raise ValueError('body sample count')
    for label,value in expected.items():
        if body.get(by[label]['stage'])!=value:raise ValueError(label+' body')
    core=next(r.body for r in resources if r.kind==b'CODE' and r.rid==3)
    for offset,wanted in ((0x46f2,'a81a3d5f'),(0x4830,'a81b6000'),(0x4780,'a9c43d5f'),(0x48be,'a9b1558f')):
        if core[offset:offset+4]!=bytes.fromhex(wanted):raise ValueError('original resource-file call bytes')
    return 'PASS resource files reference: 63 calls; exclusive scratch/cleanup, create/open/current/close, duplicate counts, search identity and durable reopen'
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('log',type=Path);p.add_argument('--status',type=int,required=True);p.add_argument('--original',type=Path,required=True);a=p.parse_args()
    try:print(validate(a.log.read_text(),a.status,read_resource_fork(a.original)))
    except (ValueError,KeyError,OSError,StopIteration) as e:raise SystemExit('FAIL resource files reference: '+str(e))
