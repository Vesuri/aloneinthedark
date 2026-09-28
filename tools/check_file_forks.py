#!/usr/bin/env python3
"""Strict original-Mac dual-fork reference acceptance."""
import argparse
from pathlib import Path
import re

def contract():
    rows=[]
    def add(label,trap,error=0,**fields):rows.append((label,trap,error,fields))
    add('create',0xa208);add('directory',0xa215)
    add('data_open',0xa200);add('resource_open',0xa20a);add('resource_empty',0xa011,eof=0)
    add('data_write',0xa003,actual=4,position=4);add('resource_write',0xa003,actual=6,position=6)
    add('both_info',0xa00c,attr=0x8c,data=4,resource=6)
    add('data_fcb',0xa260,flags=0x8100,length=4,mark=4);add('resource_fcb',0xa260,flags=0x8300,length=6,mark=6)
    add('resource_reader',0xa00a)
    add('resource_read',0xa002,actual=6,position=6,bytes=0xabcdef01,tail=0x2345)
    add('reader_close',0xa001);add('data_close',0xa001)
    add('resource_after_data_close',0xa260,flags=0x8300,length=6,mark=6);add('resource_close',0xa001)
    add('reopen_resource',0xa20a);add('resource_eof',0xa011,eof=6)
    add('resource_readback',0xa002,actual=6,position=6,bytes=0xabcdef01,tail=0x2345);add('reopened_close',0xa001)
    for p in range(5):
        add(f'permission_{p}',0xa20a)
        add(f'permission_flags_{p}',0xa260,flags=0x200 if p==1 else 0x1300 if p==4 else 0x300,length=6,mark=0)
        add(f'permission_close_{p}',0xa001)
    add('shared_first',0xa20a);add('shared_second',0xa20a);add('shared_close_second',0xa001);add('shared_close_first',0xa001)
    add('lock',0xa041)
    for p in range(5):
        add(f'locked_{p}',0xa20a,0 if p<2 else -54)
        add(f'locked_flags_{p}',0xa260,0 if p<2 else -51,**({'flags':0x2200,'length':6,'mark':0} if p<2 else {}))
        add(f'locked_close_{p}',0xa001,0 if p<2 else -51)
    add('unlock',0xa042);add('closed_info',0xa00c,attr=0,data=4,resource=6)
    add('delete',0xa009);add('missing_resource',0xa20a,-43);add('flush',0xa013)
    return rows

def validate(text,status):
    if status or 'FAIL ' in text or 'Error in breakpoint' in text or text.count('PASS forks capture complete; scratch deleted')!=1 or 'bytes=7008a2606004 HOpenRF=A20A' not in text:raise ValueError('runner, byte proof, completion or cleanup')
    rows=[]
    for line in text.splitlines():
        if line.startswith('FORKS label='):
            fields=dict(re.findall(r'(\w+)=(\S+)',line));rows.append({k:v if k=='label' else int(v,16) for k,v in fields.items()})
    expected=contract()
    if len(rows)!=len(expected):raise ValueError('stage count')
    for n,(row,(label,trap,error,fields)) in enumerate(zip(rows,expected),1):
        if (row['label'],row['stage'],row['state'],row['trap'],row['d0']&65535,row['result'])!=(label,n,n,trap,error&65535,error&65535):raise ValueError(label+' sequence/result')
        for k,v in fields.items():
            if row[k]!=v:raise ValueError(label+' '+k)
    by={r['label']:r for r in rows}
    for a,b in [('data_open','resource_open'),('resource_open','resource_reader'),('shared_first','shared_second')]:
        if not by[a]['ref'] or not by[b]['ref'] or by[a]['ref']==by[b]['ref']:raise ValueError('independent references')
    return 'PASS forks reference: 60 calls, independent bytes/EOF/marks, resource permissions/locks/sharing, scratch deleted'

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('log',type=Path);p.add_argument('--status',type=int,required=True);a=p.parse_args()
    try:print(validate(a.log.read_text(),a.status))
    except (ValueError,KeyError) as e:raise SystemExit('FAIL forks reference: '+str(e))
