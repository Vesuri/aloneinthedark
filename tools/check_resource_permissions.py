#!/usr/bin/env python3
"""Validate the scratch-only Mac resource permissions/creation capture."""
import argparse
from pathlib import Path
import re
from resource_fork import read_resource_fork
LABELS=('application exclusive-create open-empty-map raw-open raw-write-bad-map raw-close open-malformed-map delete-empty create-absent open-initial allocate add update close-initial create-existing'.split()
        +[label+'-'+str(p) for p in range(5) for label in ['open','lookup','close']]
        +'open-readonly lookup-readonly changed-readonly attrs-readonly write-readonly readonly-allocate add-readonly count-readonly-added remove-readonly update-readonly close-readonly current-after-readonly open-after-readonly lookup-after-readonly lookup-readonly-added close-after-readonly lock open-locked-default lookup-locked-default close-locked-default open-locked-read lookup-locked-read close-locked-read open-locked-2 open-locked-3 open-locked-4 unlock delete-file current-final'.split())
CURRENT={'application','current-after-readonly','current-final'}
OS={'exclusive-create','raw-open','raw-write-bad-map','raw-close','delete-empty','allocate','readonly-allocate','lock','unlock','delete-file'}
ALLOC={'allocate','readonly-allocate'}
FAIL_OPEN={'open-empty-map':0xffd9,'open-malformed-map':0xffd9,'open-locked-2':0xffca,'open-locked-3':0xffca,'open-locked-4':0xffca}
ERRORS={**FAIL_OPEN,'create-existing':0xffd0,**{name:0xffc3 for name in ['changed-readonly','add-readonly','update-readonly','close-readonly']}}
def validate(text,status,resources):
    if status or any(x in text for x in ('FAIL ','LUA ERROR','Error in breakpoint')) or text.count('PASS resource permissions capture complete; scratch deleted')!=1 or 'ARM resource-permissions Engine+$3CDC bytes=a820245f' not in text:raise ValueError('runner, byte guard, completion or cleanup')
    rows=[{k:v if k=='label' else int(v,16) for k,v in re.findall(r'(\w+)=(\S+)',line)} for line in text.splitlines() if line.startswith('RPERM label=')]
    if [r['label'] for r in rows]!=LABELS:raise ValueError('ordered 59-call sequence')
    by={r['label']:r for r in rows};app=by['application']['result']
    for n,r in enumerate(rows,1):
        label=r['label'];opened=label.startswith('open-');lookup=label.startswith('lookup-')
        error=0x8888 if label in OS|CURRENT else ERRORS.get(label,0)
        preserve=label in CURRENT|{'update','update-readonly','attrs-readonly'}
        d0=0x12345678 if preserve else 4 if label.startswith('create-') else 0 if label in OS else error
        mem=0x7777 if label in (OS-ALLOC)|CURRENT|{'create-absent','create-existing','attrs-readonly','update-readonly','lookup-readonly-added'} else 0
        delta=4 if lookup else 2 if opened or label in CURRENT|{'attrs-readonly','count-readonly-added'} else 0
        if (r['stage'],r['error'],r['mem'],r['d0'],r['sp'])!=(n,error,mem,d0,r['base']-delta):raise ValueError(label+' registers/errors/stack')
        if opened:
            if label in FAIL_OPEN:
                if r['result']!=0xffff:raise ValueError(label+' failed ref')
            elif r['result'] in (0,0xffff,app) or r['ref']!=r['result']:raise ValueError(label+' open ref')
        elif label in CURRENT:
            if not app or r['result']!=app:raise ValueError(label+' current file')
        elif lookup:
            if label=='lookup-readonly-added':
                if r['result']:raise ValueError('failed readonly add persisted')
            elif not r['result'] or r['result']!=r['handle'] or r['body']!=0x41424344 or r['master']>>24!=0x20:
                raise ValueError(label+' exact original body/handle')
        elif label=='raw-open':
            if r['result'] in (0,0xffff,app) or r['result']!=r['ref']:raise ValueError('raw open')
        elif label=='raw-write-bad-map':
            if r['result']!=16:raise ValueError('malformed map write count')
        elif label in ALLOC:
            if not r['result'] or r['result']!=r['handle' if label=='allocate' else 'other']:raise ValueError(label+' allocation')
        elif r['result']!=(1 if label=='count-readonly-added' else 0):raise ValueError(label+' scalar result')
    if by['readonly-allocate']['other']==by['lookup-readonly']['handle']:raise ValueError('independent readonly add handle')
    for label in ['changed-readonly','attrs-readonly','write-readonly','remove-readonly','close-readonly']:
        row=by[label];flags=0 if label in {'remove-readonly','close-readonly'} else 0x20
        if row['handle']!=by['lookup-readonly']['handle'] or row['body']!=0x45464748 or row['master']>>24!=flags:raise ValueError(label+' in-memory state')
    core=next(r.body for r in resources if r.kind==b'CODE' and r.rid==3)
    for offset,wanted in ((0x46f2,'a81a3d5f'),(0x4780,'a9c43d5f'),(0x4830,'a81b6000'),(0x48be,'a9b1558f')):
        if core[offset:offset+4]!=bytes.fromhex(wanted):raise ValueError('original resource-file call bytes')
    return 'PASS resource permissions reference: 59 calls; permissions 0-4, create/exists, empty/malformed maps, readonly mutation/close, lock errors, exact reopen and cleanup'
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('log',type=Path);p.add_argument('--status',type=int,required=True);p.add_argument('--original',type=Path,required=True);a=p.parse_args()
    try:print(validate(a.log.read_text(),a.status,read_resource_fork(a.original)))
    except (ValueError,KeyError,OSError,StopIteration) as error:raise SystemExit('FAIL resource permissions reference: '+str(error))
