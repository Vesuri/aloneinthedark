#!/usr/bin/env python3
"""Compare installed Mac file info to the original archive-derived companions.

The current reference volume was populated through host extraction/MacBinary:
its dates are 7200 seconds lower, and Finder has changed initialized/icon fields.
These explicit installation differences must not hide type, creator or size errors.
"""
import argparse
from pathlib import Path
import re
import struct
from installed_metadata import encode

def validate(text,root,status):
    if status or 'FAIL ' in text or 'Error in breakpoint' in text or text.count('PASS installed capture complete; read-only complete')!=1 or 'bytes=7008a2606004' not in text:raise ValueError('runner, byte proof or completion')
    rows=[]
    for line in text.splitlines():
        if line.startswith('INSTALLED label='):
            f=dict(re.findall(r'(\w+)=(\S+)',line));rows.append({k:v if k=='label' else int(v,16) for k,v in f.items()})
    names=[('application','Alone In The Dark'),('camera','Alone Data/Camera00.PAK'),('ress','Alone Data/ITD_Ress.PAK'),('present','Alone Data/Present.PAK')]
    if len(rows)!=4:raise ValueError('stage count')
    for n,(row,(label,name)) in enumerate(zip(rows,names),1):
        if (row['label'],row['stage'],row['state'],row['trap'],row['d0'],row['result'])!=(label,n,n,0xa20c,0,0):raise ValueError(label+' sequence/result')
        info=(root/(name+'.finfo')).read_bytes()
        if len(info)!=32:raise ValueError(label+' companion size')
        finder=info[4:20];created,modified=struct.unpack('>II',info[20:28])
        if info!=encode(finder,created,modified):raise ValueError(label+' companion checksum')
        reference=b''.join(struct.pack('>I',row['finder'+str(i)]) for i in range(4))
        expected=bytearray(finder)
        if n==1:expected[12:14]=b'\0\x80'
        else:expected[8:10]=b'\0\0'
        if reference!=expected or row['created']+7200!=created or row['modified']+7200!=modified:raise ValueError(label+' metadata discrepancy beyond measured installation changes')
        size=(root/name).stat().st_size
        if row['data']!=(0 if n==1 else size) or row['resource']!=(size if n==1 else 0) or row['attr']!=(0x84 if n==1 else 0):raise ValueError(label+' fork sizes/attributes')
    return 'PASS installed reference: type/creator/forks exact; explicit reference import date offset=-7200 and Finder initialized/icon differences'
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('log',type=Path);p.add_argument('root',type=Path);p.add_argument('--status',type=int,required=True);a=p.parse_args()
    try:print(validate(a.log.read_text(),a.root,a.status))
    except (ValueError,KeyError) as e:raise SystemExit('FAIL installed reference: '+str(e))
