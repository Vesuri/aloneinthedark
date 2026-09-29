#!/usr/bin/env python3
"""Check the Mac enumeration contract against original resource-map ordering."""
import argparse
import hashlib
from pathlib import Path
import re
from resource_fork import read_resource_fork

def cases(resources):
    result=[(label,'count',sum(r.kind==typ for r in resources),None) for label,typ in [('count-crel',b'CREL'),('chain-count-crel',b'CREL'),('count-code',b'CODE'),('count-strs',b'STRS'),('count-missing',b'QQQQ'),('chain-count-missing',b'QQQQ')]]
    result.append(('load-off','switch',None,None))
    def indexed(label,typ,index):
        items=[r for r in resources if r.kind==typ]
        item=items[index-1] if 0<index<=len(items) else None
        result.append((label,'index',None,item))
        if item:result.append((label+'-info','info',None,item))
    indexed('crel-zero',b'CREL',0);indexed('crel-negative',b'CREL',-1)
    for n in range(1,12):indexed('crel-'+str(n),b'CREL',n)
    indexed('crel-large',b'CREL',32767);indexed('crel-min',b'CREL',-32768)
    indexed('type-missing',b'QQQQ',1)
    indexed('code-first',b'CODE',1);indexed('code-second',b'CODE',2);indexed('code-last',b'CODE',14)
    indexed('strs-first',b'STRS',1)
    result.append(('load-on','switch',None,None));indexed('loaded-first',b'CREL',1)
    return result

def validate(text,status,resources):
    if status or any(x in text for x in ('FAIL ','LUA ERROR','Error in breakpoint')) or text.count('PASS resource enumeration capture complete')!=1 or 'ARM resource-enumeration Engine+$3CDC bytes=a820245f' not in text:raise ValueError('runner, original byte check or completion')
    rows=[{k:v if k in ('label','kind') else int(v,16) for k,v in re.findall(r'(\w+)=(\S+)',line)} for line in text.splitlines() if line.startswith('RENUM ')]
    expected=cases(resources)
    if len(rows)!=44 or len(rows)!=len(expected):raise ValueError('stage count')
    handles={}
    for n,(r,(label,kind,count,item)) in enumerate(zip(rows,expected),1):
        error=0x8888 if kind=='switch' else 0xff40 if kind=='index' and not item else 0
        d0=0x12345678 if kind=='switch' else error
        if (r['stage'],r['label'],r['kind'],r['error'],r['d0'])!=(n,label,kind,error,d0) or r['sp']!=r['expectedsp']:raise ValueError(label+' stage/result/stack')
        if kind=='count' and r['result']!=count:raise ValueError(label+' count')
        if kind=='index':
            if bool(r['result'])!=bool(item):raise ValueError(label+' handle')
            if item:
                key=(item.kind,item.rid)
                if key in handles and handles[key]!=r['result']:raise ValueError(label+' cached master')
                if key not in handles and r['result'] in handles.values():raise ValueError(label+' duplicate master')
                handles[key]=r['result']
                if item.kind==b'CREL':
                    loaded=label=='loaded-first'
                    if bool(r['master']&0xffffff)!=loaded:raise ValueError(label+' load control')
        if kind=='info':
            if r['id']!=item.rid&0xffff or r['type']!=int.from_bytes(item.kind,'big') or r['result']!=handles[(item.kind,item.rid)]:raise ValueError(label+' original map order/metadata')
        elif r['id']!=0xcccc or r['type']!=0xcccccccc:raise ValueError(label+' output canaries')
    return 'PASS resource enumeration reference: 44 calls; counts, map order, bounds, load control, metadata and stack'

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('log',type=Path);p.add_argument('--status',type=int,required=True);p.add_argument('--original',type=Path,required=True);p.add_argument('--dump',type=Path,default=Path('tmp/mac-enumerated-resource.bin'));a=p.parse_args()
    try:
        resources=read_resource_fork(a.original);print(validate(a.log.read_text(),a.status,resources))
        item=next(r for r in resources if r.kind==b'CREL');actual=a.dump.read_bytes()
        if actual!=item.body:raise ValueError('enumerated original resource body')
        print(f'PASS enumerated first CREL: id={item.rid} bytes={len(actual)} SHA256={hashlib.sha256(actual).hexdigest()}')
    except (ValueError,KeyError,OSError,StopIteration) as e:raise SystemExit('FAIL resource enumeration reference: '+str(e))
