#!/usr/bin/env python3
"""Validate the CPU-only original Mac create/delete/Finder-info fixture."""
import argparse
from pathlib import Path
import re

def validate(text,status):
    if status or 'FAIL ' in text or 'Error in breakpoint' in text or text.count('PASS catalog capture complete; scratch deleted')!=1 or 'bytes=7008a2606004' not in text:
        raise ValueError('runner, original bytes, completion or cleanup')
    spec=[('create',0xa208,0),('duplicate',0xa208,-48),('directory',0xa215,0),('initial_info',0xa00c,0),('set_info',0xa00d,0),('changed_info',0xa00c,0),('hierarchical_info',0xa20c,0),('hierarchical_set_info',0xa20d,0),('after_hierarchical_set',0xa00c,0),('open',0xa000,0),('open_info',0xa00c,0),('busy_delete',0xa009,-47),('close',0xa001,0),('lock',0xa041,0),('locked_info',0xa00c,0),('locked_set_info',0xa00d,0),('after_locked_set',0xa00c,0),('locked_delete',0xa009,-45),('unlock',0xa042,0),('delete',0xa009,0),('missing_info',0xa00c,-43),('missing_delete',0xa009,-43),('recreate',0xa008,0),('recreated_info',0xa20c,0),('recreated_setinfo',0xa00d,0),('write_open',0xa000,0),('write',0xa003,0),('written_info',0xa00c,0),('write_flush',0xa013,0),('flushed_info',0xa00c,0),('write_close',0xa001,0),('closed_info',0xa00c,0),('hierarchical_delete',0xa209,0),('bad_directory',0xa208,-120),('empty_name',0xa008,-48),('flush',0xa013,0)]
    rows=[]
    for line in text.splitlines():
        if line.startswith('CATALOG label='):
            fields=dict(re.findall(r'(\w+)=(\S+)',line));rows.append({k:v if k=='label' else int(v,16) for k,v in fields.items()})
    if len(rows)!=len(spec):raise ValueError('stage count')
    by={r['label']:r for r in rows}
    for n,(r,(label,trap,error)) in enumerate(zip(rows,spec),1):
        if (r['label'],r['stage'],r['state'],r['trap'],r['d0']&65535,r['result'])!=(label,n,n,trap,error&65535,error&65535):raise ValueError(label+' sequence/result')
    for label in ['initial_info','recreated_info']:
        r=by[label]
        if any(r[k] for k in ['finder0','finder1','finder2','finder3','attr','data','resource','ref']) or not r['created'] or r['created']!=r['modified']:raise ValueError(label+' initial metadata')
    if by['initial_info']['id']==by['recreated_info']['id']:raise ValueError('reused file ID')
    for label,attr,modified in [('changed_info',0,0xabcd0304),('hierarchical_info',0,0xabcd0304),('after_hierarchical_set',0,0xabcd0304),('open_info',0x88,0xabcd0304),('locked_info',1,0xabcd0304),('after_locked_set',1,0xabcd0506)]:
        r=by[label]
        if [r['finder'+str(i)] for i in range(4)]!=[0x54455354,0x41495444,0x04000012,0x00340000] or r['created']!=0xabcd0102 or r['modified']!=modified or r['attr']!=attr or r['id']!=by['initial_info']['id']:raise ValueError(label+' metadata')
    if by['open_info']['ref']!=by['open']['ref'] or not by['open']['ref']:raise ValueError('open reference')
    for label in ['written_info','flushed_info','closed_info']:
        r=by[label]
        if r['data']!=4 or r['resource'] or r['created']!=0xabcd0102 or r['id']!=by['recreated_info']['id']:raise ValueError(label+' written metadata')
    if by['written_info']['modified']!=0xabcd0304 or by['flushed_info']['modified'] in [0,0xabcd0304] or by['flushed_info']['modified']!=by['closed_info']['modified']:raise ValueError('modification date publication')
    return 'PASS catalog reference: 36 calls, Finder bytes/dates/attributes, stable IDs, duplicate/busy/locked/missing errors, scratch deleted'
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('log',type=Path);p.add_argument('--status',type=int,required=True);a=p.parse_args()
    try:print(validate(a.log.read_text(),a.status))
    except (ValueError,KeyError) as e:raise SystemExit('FAIL catalog reference: '+str(e))
