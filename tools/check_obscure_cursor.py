#!/usr/bin/env python3
"""Check the unchanged ObscureCursor caller, logical state and calling convention."""
import argparse,re
from pathlib import Path
from check_cursor_visibility import reference
from resource_fork import read_resource_fork
ROOT=Path(__file__).resolve().parents[1]
def records(text,tag):
    return [dict(re.findall(r'(\w+)=([0-9A-Fa-f]+)(?: |$)',row)) for row in re.findall(r'^'+tag+r' (.*)$',text,re.M)]
def check(ref,status,native=None,native_status=None):
    reference(ref,status)
    code=next(r.body for r in read_resource_fork(ROOT/'tmp/runtime-data/Alone In The Dark') if r.kind==b'CODE' and r.rid==7)
    expected='0C47000366084A2C00136602A856'
    if code[0xfea:0xff8].hex().upper()!=expected or re.findall(r'^CUR_BYTES (\w+)$',ref,re.M)!=[expected]:raise ValueError('original/live reference bytes')
    entries,returns=records(ref,'CUR_ENTER'),records(ref,'CUR_RETURN')
    if len(entries)!=10 or len(returns)!=10:raise ValueError('reference count')
    for n in (0,2,3,6,9):
        a,b=entries[n],returns[n]
        for reg in ['D'+str(i) for i in range(1,8)]+['A'+str(i) for i in range(1,7)]:
            if a[reg]!=b[reg]:raise ValueError('reference preserved '+reg)
        if int(b['A7'],16)!=int(a['A7'],16)+(8 if n==0 else 0):raise ValueError('reference stack')
        before=bytes.fromhex(a['low'])
        if int(b['D0'],16)!=(1 if before[0] else int(a['D0'],16)):raise ValueError('conditional D0')
    before,after=records(ref,'CUR_BEFORE_MOVE'),records(ref,'CUR_AFTER_MOVE')
    if len(before)!=1 or len(after)!=1 or before[0]['mouse']==after[0]['mouse']:raise ValueError('actual reference movement')
    if native is not None:
        from check_native_driver import check as startup
        startup(native,native_status)
        aa,bb=records(native,'CUR_NATIVE_ENTER'),records(native,'CUR_NATIVE_RETURN')
        count=len(aa)
        if not count or len(bb)!=count or native.count('PASS native original ObscureCursor')!=count:raise ValueError('native completion/count')
        if re.findall(r'^CUR_BYTES (\w+)$',native,re.M)!=[expected]*count:raise ValueError('native caller bytes')
        for i,(a,b) in enumerate(zip(aa,bb)):
            if a['level']!='0' or a['initialized']!='1' or (b['level'],b['obscured'])!=('0','1'):raise ValueError('native logical state')
            if a['obscured']!=('0' if i==0 else '1'):raise ValueError('initial/repeated obscuring')
            expected_d0=1 if a['obscured']=='0' else int(a['D0'],16)
            if int(b['D0'],16)!=expected_d0 or b['A7']!=a['A7'] or b['image']!=a['image']:raise ValueError('native D0/stack/image')
            for reg in ['D'+str(j) for j in range(1,8)]+['A'+str(j) for j in range(1,7)]:
                if a[reg]!=b[reg]:raise ValueError('native preserved '+reg)
            if b['allowed']!=a['allowed'] or b['allowed'] not in ('0','1') or b['visible']!='0':raise ValueError('native cursor publication/gate')
    return 'PASS cursor obscuring: original bytes, distinct hidden/obscured state, conditional D0, stack/register contract and measured mouse restoration'
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('reference',type=Path);p.add_argument('--reference-status',type=int,required=True);p.add_argument('--native',type=Path);p.add_argument('--native-status',type=int);a=p.parse_args()
    try:print(check(a.reference.read_text(),a.reference_status,a.native.read_text() if a.native else None,a.native_status))
    except (ValueError,KeyError,OSError) as e:raise SystemExit('FAIL cursor obscuring: '+str(e))
