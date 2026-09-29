#!/usr/bin/env python3
"""Validate the read-only System 7.5.5 HGetVInfo contract capture."""
import argparse
from pathlib import Path
import re
import struct

def validate(text,status):
    if status or 'FAIL ' in text or 'Error in breakpoint' in text or text.count('PASS vinfo capture complete; read-only complete')!=1 or 'bytes=7008a2606004' not in text:
        raise ValueError('runner, original bytes or completion')
    rows=[]
    for line in text.splitlines():
        if line.startswith('VINFO label='):
            fields=dict(re.findall(r'(\w+)=(\S+)',line))
            rows.append({k:v if k=='label' else int(v,16) for k,v in fields.items()})
    labels=['get-default','explicit','default','wd','drive','drive-valid','badvol','index1','index2','zero-name','named','named-colon','missing','negative-default','system-wd','system-query']
    if len(rows)!=len(labels):raise ValueError('stage count')
    base=rows[1]
    for field,value in {'created':0xdc1e1d53,'attr':0x60,'bitmap':3,'blocks':0xfea4,'blocksize':0x7600,'clump':0x1d800,'start':19,'sig':0x4244,'fsid':0,'backup':0,'sequence':0}.items():
        if base[field]!=value:raise ValueError('reference disk '+field)
    if not 0<base['free']<=base['blocks'] or not base['files'] or not base['dirs'] or not base['finder0'] or not base['finder2'] or not base['drive'] or base['driver']<0x8000:
        raise ValueError('reference disk identities/counts')
    datafields=['created','modified','attr','valence','bitmap','alloc','blocks','blocksize','clump','start','nextid','free','sig','drive','driver','fsid','backup','sequence','writes','files','dirs']+['finder'+str(i) for i in range(8)]
    shorts={'attr','valence','bitmap','alloc','blocks','start','free','sig','drive','driver','fsid','sequence'}
    errors={'drive':1,'badvol':0x1234,'index2':0,'named':0x1234,'missing':0xffff}
    for n,(row,label) in enumerate(zip(rows,labels),1):
        if (row['label'],row['stage'],row['state'])!=(label,n,n):raise ValueError('sequence')
        error=label in errors
        if row['d0']&65535!=(0xffdd if error else 0) or row['result']!=(0xffdd if error else 0):raise ValueError(label+' result')
        if label=='get-default':
            if not 0x8000<=row['volume']<0xffff:raise ValueError('default WD')
            continue
        if label.startswith('system-'):
            if row['volume']!=0x8053 or row['blocksize']!=base['finder0']:raise ValueError('System folder/WD identity')
            continue
        if error:
            if row['volume']!=errors[label]:raise ValueError(label+' error volume')
            for field in datafields:
                if row[field]!=(0xcccc if field in shorts else 0xcccccccc):raise ValueError(label+' altered error output '+field)
        else:
            if row['volume']!=0xffff:raise ValueError(label+' volume reference')
            for field in datafields:
                wanted=5 if field=='valence' and label in ['default','wd','negative-default'] else 3 if field=='valence' else base[field]
                if row[field]!=wanted:raise ValueError(label+' '+field)
        if label in ['index1','zero-name','named-colon','negative-default']:
            name=b''.join(struct.pack('>I',row['name'+str(i)]) for i in range(4))
            if not name.startswith(b'\x0d7.5.5 2GB (D)'):raise ValueError(label+' volume name')
    return 'PASS vinfo reference: 16 calls; volume/index/name/WD selection, untouched errors, full HFS record and System folder identity'

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('log',type=Path);p.add_argument('--status',type=int,required=True);a=p.parse_args()
    try:print(validate(a.log.read_text(),a.status))
    except (ValueError,KeyError) as error:raise SystemExit('FAIL vinfo reference: '+str(error))
