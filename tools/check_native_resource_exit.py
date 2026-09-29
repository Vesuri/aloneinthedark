#!/usr/bin/env python3
"""Validate bounded native exit evidence and independently inspect owned scratch forks."""
import argparse
from pathlib import Path
from resource_fork import read_resource_fork

ROOT=Path(__file__).resolve().parents[1]
DIRECTORY=ROOT/'amiga/.run/dh1/Saved Games'
NAME='Resource Exit'
ALLOWED={NAME+suffix for suffix in ('','.rsrc','.finfo','.uaem','.rsrc.uaem','.finfo.uaem')}

def scratch():
    return list(DIRECTORY.glob(NAME+'*'))

def validate_log(text,status,phase):
    marker=(f'PASS resource-exit phase={phase} original-return=1 restored=1 main-result=0 crt-return=1'
            if phase!=3 else 'PASS resource-exit fault stop=RESOURCE EXIT IO ERROR resident=EXIT service=active stream=open')
    if status!=0 or text.count(marker)!=1 or any(x in text for x in ('FAIL','TIMEOUT','Error in sourced','unexpected debugger stop')):
        raise ValueError('observer did not complete the required phase normally')

def original_bytes():
    rows=read_resource_fork(ROOT/'amiga/.run/dh1/data/Alone In The Dark')
    for code_id,offset,raw in (
        (1,0x48,'2a780904206d006c4e90a9f4'),
        (1,0x4aa,'226d0068303ca9f020690008a047303ca9f120690014a047303ca9f420690020a0472049a01f4e75'),
        (3,0x3e4,'4e56ff004ebafd7c')):
        code=next(r.body for r in rows if r.kind==b'CODE' and r.rid==code_id)
        if code[offset:offset+len(raw)//2]!=bytes.fromhex(raw):raise ValueError('original entry/exit bytes')

def inspect(phase):
    files=scratch()
    if phase in (0,2):
        if files:raise ValueError('scratch exists; preserve it for inspection: '+str(files))
        return
    if any(p.name not in ALLOWED or not p.is_file() for p in files):raise ValueError('unexpected scratch/staging files')
    if (DIRECTORY/NAME).read_bytes():raise ValueError('data fork is not empty')
    if not (DIRECTORY/(NAME+'.finfo')).is_file():raise ValueError('missing metadata companion')
    rows=read_resource_fork(DIRECTORY/(NAME+'.rsrc'))
    expected=[] if phase==3 else [(b'LIFE',128,0,'Scratch',b'EXIT')]
    if [(r.kind,r.rid,r.attrs,r.name,r.body) for r in rows]!=expected:raise ValueError('published fork differs from exact expected resources')

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--phase',type=int,choices=(0,1,2,3),required=True)
    p.add_argument('--log',type=Path);p.add_argument('--status',type=int)
    p.add_argument('--cleanup-fault',action='store_true')
    a=p.parse_args()
    try:
        if a.phase:validate_log(a.log.read_text(),a.status,a.phase)
        if a.phase==0:original_bytes()
        inspect(a.phase)
        if a.cleanup_fault:
            if a.phase!=3:raise ValueError('only verified fault scratch may be removed')
            for file in scratch():file.unlink()
            inspect(0)
        print('PASS native resource-exit preflight: original bytes and empty scratch' if a.phase==0 else f'PASS native resource-exit phase={a.phase}: bounded observer, exact fork and scratch state')
    except (ValueError,OSError,AttributeError,StopIteration) as error:raise SystemExit('FAIL native resource-exit: '+str(error))
