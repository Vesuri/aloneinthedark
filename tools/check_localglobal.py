#!/usr/bin/env python3
"""Pair the original background-window LocalToGlobal calls."""
import argparse,re,struct
from pathlib import Path
from resource_fork import read_resource_fork
root=Path(__file__).resolve().parents[1]
def check(reference,native,reference_status,native_status):
    code=next(r.body for r in read_resource_fork(root/'tmp/runtime-data/Alone In The Dark') if r.kind==b'CODE' and r.rid==9)
    if code[0xe1c:0xe28].hex()!='486efff4a870486efff8a870':raise ValueError('original instructions')
    pairs=[]
    for side,text,status in (('reference',reference,reference_status),('native',native,native_status)):
        if status!=0 or any(v in text for v in ('FAIL','LUA ERROR','Error in','timeout')):raise ValueError(side+' completion')
        marker='PASS original LocalToGlobal calls=2' if side=='reference' else 'PASS native LocalToGlobal calls=2'
        end='Exited via the debugger' if side=='reference' else '[Inferior 1 (Remote target) detached]'
        if text.count(marker)!=1 or text.count(end)!=1:raise ValueError(side+' terminal controls')
        def rows(label):return [dict(re.findall(r'(\w+)=(\w+)',r)) for r in re.findall('^'+label+' (.*)$',text,re.M)]
        entries,returns=rows('LG_ENTRY'),rows('LG_RETURN')
        if len(entries)!=2 or len(returns)!=2 or [r['data'] for r in rows('LG_BYTES')]!=['486EFFF4A870','486EFFF8A870']:raise ValueError(side+' original call sequence')
        values=[]
        for n,(e,r) in enumerate(zip(entries,returns),1):
            if e['n']!=str(n) or r['n']!=str(n) or int(r['sp'],16)!=int(e['sp'],16)+4:raise ValueError(side+' stack/index')
            for reg in [f'd{i}' for i in range(8)]+[f'a{i}' for i in range(7)]:
                if e[reg]!=r[reg]:raise ValueError(side+' preserved '+reg)
            if e['bounds']!=r['bounds'] or e['bounds']!='1F401F40212021C0' or e['point']!=r['point'] or e['port']!=r['port']:raise ValueError(side+' selected port')
            before=int(e['value'],16);after=int(r['value'],16)
            expected=(((before>>16)-8000)&65535)<<16 | (((before&65535)-8000)&65535)
            if after!=expected:raise ValueError(side+' conversion')
            for kind,size in (('point',12),('port',108),('pm',50)):
                a=(root/f'tmp/localglobal-{side}-{n}-entry-{kind}.bin').read_bytes()
                b=(root/f'tmp/localglobal-{side}-{n}-return-{kind}.bin').read_bytes()
                if len(a)!=size or len(b)!=size:raise ValueError(side+' dump length')
                if kind=='point':
                    if a[:4]!=b[:4] or a[8:]!=b[8:] or a[4:8]!=before.to_bytes(4,'big') or b[4:8]!=after.to_bytes(4,'big'):raise ValueError(side+' output/guards')
                elif a!=b:raise ValueError(side+' changed '+kind)
            values.append((before,after))
        if values!=[(0,0xe0c0e0c0),(0x3e803e80,0x1f401f40)]:raise ValueError(side+' original point values')
        pairs.append(values)
    if pairs[0]!=pairs[1]:raise ValueError('paired outputs')
    from check_native_driver import check as check_startup
    check_startup(native,native_status)
    return 'PASS paired LocalToGlobal: both original points, caller bytes, preserved registers/stack, adjacent bytes, port and PixMap'
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('reference',type=Path);p.add_argument('native',type=Path);p.add_argument('--reference-status',type=int,required=True);p.add_argument('--native-status',type=int,required=True);a=p.parse_args()
    try:print(check(a.reference.read_text(),a.native.read_text(),a.reference_status,a.native_status))
    except (ValueError,OSError,KeyError) as e:raise SystemExit('FAIL LocalToGlobal: '+str(e))
