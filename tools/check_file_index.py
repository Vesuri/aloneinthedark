#!/usr/bin/env python3
"""Strict acceptance for the owned HFS indexed-file reference directory."""
import argparse
from pathlib import Path
import re

ORDER=' !"#$%&\'()*+,-.0123456789;<=>?@A`BCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_{|}~'

def validate(text,status):
    if status or 'FAIL ' in text or 'Error in breakpoint' in text or text.count('PASS index capture complete; scratch deleted')!=1 or 'bytes=7008a2606004' not in text:raise ValueError('runner, byte proof, completion or cleanup')
    expected=[]
    def add(label,trap,error=0):expected.append((label,trap,error))
    add('make_directory',0xa260)
    for i in range(1,68):add(f'create_{i}',0xa208)
    add('make_subdirectory',0xa260)
    for i in range(1,70):add(f'index_{i}',0xa20c,0 if i<=67 else -43)
    for label,error in [('null_name',0),('negative_name',0),('bad_directory',-43),('bad_volume',-35)]:add(label,0xa20c,error)
    add('default_directory',0xa215);add('classic_index',0xa00c);add('open_wd',0xa260)
    add('wd_bad_directory',0xa20c,-43);add('close_wd',0xa260);add('restore_directory',0xa215)
    for i in range(1,68):add(f'delete_{i}',0xa209)
    add('delete_subdirectory',0xa209);add('delete_directory',0xa209);add('flush',0xa013)
    rows=[]
    for line in text.splitlines():
        if line.startswith('INDEX label='):
            f=dict(re.findall(r'(\w+)=(\S+)',line));rows.append({k:v if k=='label' else int(v,16) for k,v in f.items()})
    if len(rows)!=len(expected):raise ValueError('stage count')
    for n,(row,(label,trap,error)) in enumerate(zip(rows,expected),1):
        if (row['label'],row['stage'],row['state'],row['trap'],row['d0']&65535,row['result'])!=(label,n,n,trap,error&65535,error&65535):raise ValueError(label+' sequence/result')
    by={r['label']:r for r in rows};ids=[]
    for i,ch in enumerate(ORDER,1):
        row=by[f'index_{i}']
        if row['name0']!=0x03690078+(ord(ch)<<8) or row['index']!=i or row['attr'] or not row['id']:raise ValueError('enumeration order/name/attributes')
        ids.append(row['id'])
    if len(set(ids))!=67:raise ValueError('file identity reused')
    if by['null_name']['id']!=ids[0] or by['null_name']['name0']!=0x0769676e or by['classic_index']['id']!=ids[0] or by['negative_name']['id']!=ids[ORDER.index('A')]:raise ValueError('null/classic/negative selection')
    if by['make_subdirectory']['id'] in ids:raise ValueError('directory returned as file')
    return 'PASS index reference: 218 calls, 67-character HFS order, directories excluded, null/classic/WD/errors, scratch deleted'
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('log',type=Path);p.add_argument('--status',type=int,required=True);a=p.parse_args()
    try:print(validate(a.log.read_text(),a.status))
    except (ValueError,KeyError) as e:raise SystemExit('FAIL index reference: '+str(e))
