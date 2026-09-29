#!/usr/bin/env python3
"""Strict original-Mac OpenDF reference acceptance."""
import argparse
from pathlib import Path
import re

def contract():
    rows=[]
    def add(label,trap,error=0,**fields):rows.append((label,trap,error,fields))
    add('create',0xa208);add('created_info',0xa20c,data=0,resource=0);add('directory',0xa215)
    add('seed_open',0xa260);add('seed_write',0xa003,actual=4,position=4);add('seed_close',0xa001)
    for trap,prefix in [(0xa060,'fs_'),(0xa260,'hfs_')]:
        for p in range(5):
            add(prefix+'open_'+str(p),trap)
            add(prefix+'fcb_'+str(p),0xa260,flags=0 if p==1 else 0x1100 if p==4 else 0x100,length=4,mark=0)
            if p==1:add(prefix+'read',0xa002,actual=4,position=4,bytes=0x12345678)
            add(prefix+'close_'+str(p),0xa001)
    add('exclusive',0xa060);add('conflict',0xa260,-49);add('exclusive_close',0xa001)
    add('shared_first',0xa060);add('shared_second',0xa260)
    add('shared_read',0xa002,actual=4,position=4,bytes=0x12345678)
    add('shared_position',0xa018,position=0)
    add('shared_close_second',0xa001);add('shared_close_first',0xa001)
    add('ignored_directory',0xa060);add('ignored_close',0xa001)
    add('bad_directory',0xa260,-43,ref=0);add('hopen_bad_directory',0xa200,-43,ref=0);add('hopenrf_bad_directory',0xa20a,-43,ref=0);add('bad_volume',0xa260,-35,ref=0)
    add('file_directory',0xa260,-43,ref=0);add('file_parent',0xa260,-43,ref=0);add('missing_parent',0xa260,-120,ref=0);add('restore_name',0xa20c,data=4,resource=0)
    add('lock',0xa041)
    for p in range(5):
        add('locked_'+str(p),0xa060,0 if p<2 else -54)
        if p<2:add('locked_close_'+str(p),0xa001)
    add('unlock',0xa042);add('delete',0xa009);add('missing',0xa060,-43,ref=0);add('flush',0xa013)
    return rows

def validate(text,status):
    if status or 'FAIL ' in text or 'Error in breakpoint' in text or text.count('PASS opendf capture complete; scratch deleted')!=1 or 'bytes=7008a2606004 OpenDF=701AA060' not in text:raise ValueError('runner, byte proof, completion or cleanup')
    rows=[]
    for line in text.splitlines():
        if line.startswith('OPENDF label='):
            fields=dict(re.findall(r'(\w+)=(\S+)',line));rows.append({k:v if k=='label' else int(v,16) for k,v in fields.items()})
    expected=contract()
    if len(rows)!=len(expected):raise ValueError('stage count')
    for n,(row,(label,trap,error,fields)) in enumerate(zip(rows,expected),1):
        if (row['label'],row['stage'],row['state'],row['trap'],row['d0']&65535,row['result'])!=(label,n,n,trap,error&65535,error&65535):raise ValueError(label+' sequence/result')
        for k,v in fields.items():
            if row[k]!=v:raise ValueError(label+' '+k)
    by={r['label']:r for r in rows}
    if not by['shared_first']['ref'] or not by['shared_second']['ref'] or by['shared_first']['ref']==by['shared_second']['ref']:
        raise ValueError('independent shared references')
    if not by['exclusive']['ref'] or by['exclusive']['ref']!=by['conflict']['ref']:
        raise ValueError('conflicting writer reference')
    for row in rows:
        expected={'hopen_bad_directory':(0x143a2e41,0x49544420),'file_parent':(0x1a3a2e41,0x49544420),'missing_parent':(0x193a4149,0x54442041)}.get(row['label'],(0x132e4149,0x54442050))
        if (row['name0'],row['name1'])!=expected:raise ValueError('dot-prefixed or diagnostic name')
    return 'PASS opendf reference: 69 calls, dot-name, classic/HFS directory distinction, data bytes/permissions/sharing/errors, scratch deleted'

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('log',type=Path);p.add_argument('--status',type=int,required=True);a=p.parse_args()
    try:print(validate(a.log.read_text(),a.status))
    except (ValueError,KeyError) as e:raise SystemExit('FAIL opendf reference: '+str(e))
