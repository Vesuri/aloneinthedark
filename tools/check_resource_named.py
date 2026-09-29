#!/usr/bin/env python3
"""Require the completed, byte-checked Mac named/ID resource lookup capture."""
import argparse
import hashlib
from pathlib import Path
import re
from resource_fork import read_resource_fork
LABELS='exact lower upper accent missing type-case empty-name other-name chain-exact chain-missing id-exact id-missing id-after-error id-zero id-negative id-type-missing chain-id-missing chain-id-type-missing chain-empty-name id-after-missing'.split()
ERRORS={'accent','missing','type-case','empty-name','chain-missing','chain-empty-name'}
GENERAL={'exact','lower','upper','chain-exact','id-exact','id-after-error','id-after-missing'}
PRESERVED={'chain-exact','chain-missing','chain-empty-name'}
def validate(text,status):
    if status or any(x in text for x in ['FAIL ','LUA ERROR','Error in breakpoint']) or text.count('PASS named resource capture complete')!=1 or 'ARM named-resource Engine+$3CDC bytes=a820245f' not in text:
        raise ValueError('runner, original bytes or completion')
    if 'RESOURCE ORIGINAL name0=0747656E name1=6572616C type=53545223' not in text:raise ValueError('original General request')
    original=re.findall(r'RESOURCE ORIGINAL result=([0-9A-F]+) error=0000',text)
    if len(original)!=1 or not int(original[0],16):raise ValueError('original resource handle')
    original=int(original[0],16)
    rows=[{k:v if k=='label' else int(v,16) for k,v in re.findall(r'(\w+)=(\S+)',line)} for line in text.splitlines() if line.startswith('RNAMED ')]
    if len(rows)!=len(LABELS):raise ValueError('stage count')
    for n,(r,label) in enumerate(zip(rows,LABELS),1):
        error=0xff40 if label in ERRORS else 0
        if r['stage']!=n or r['label']!=label or r['error']!=error or r['sp']!=r['expectedsp'] or r['original']!=original:raise ValueError(label+' result/stack')
        if r['d0']!=(0x12345678 if label in PRESERVED else error):raise ValueError(label+' D0')
        if label in GENERAL:
            if r['handle']!=original:raise ValueError(label+' reused handle')
        elif label=='other-name':
            if r['handle'] in (0,original):raise ValueError('other named resource identity')
        elif r['handle']:raise ValueError(label+' missing handle')
    return 'PASS resource lookup reference: 20 calls; case/marks/empty names, reused handles, named -192 versus ID noErr, D0 and stack'
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('log',type=Path);p.add_argument('--status',type=int,required=True);p.add_argument('--original',type=Path,required=True);p.add_argument('--dump',type=Path,default=Path('tmp/mac-general-resource.bin'));a=p.parse_args()
    try:
        print(validate(a.log.read_text(),a.status))
        original=next(r.body for r in read_resource_fork(a.original) if r.kind==b'STR#' and r.rid==128)
        actual=a.dump.read_bytes()
        if actual!=original:raise ValueError('original General resource bytes')
        print(f'PASS General Mac resource: bytes={len(actual)} SHA256={hashlib.sha256(actual).hexdigest()}')
    except (ValueError,KeyError,OSError,StopIteration) as e:raise SystemExit('FAIL resource lookup reference: '+str(e))
