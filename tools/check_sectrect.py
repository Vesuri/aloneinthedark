#!/usr/bin/env python3
"""Verify original SectRect and measured empty/alias contracts."""
import argparse,re,struct
from pathlib import Path
from resource_fork import read_resource_fork
ROOT=Path(__file__).resolve().parents[1]
def pairs(text,fixtures=14):
    rows=[(phase,dict(re.findall(r'(\w+)=([0-9A-Fa-f]+)(?: |$)',row))) for phase,row in re.findall(r'^SR_(ENTER|RETURN) (.*)$',text,re.M)]
    if len(rows)!=2*(2+fixtures):raise ValueError('pair count')
    for i in range(2+fixtures):
        (ep,e),(rp,r)=rows[2*i:2*i+2]
        if ep!='ENTER' or rp!='RETURN':raise ValueError('pair order')
        yield e,r

def check(text,status,native=False):
    if status!=0 or any(s in text for s in ('FAIL','LUA ERROR','Error in','timeout')):raise ValueError('run completion')
    marker='PASS native original SectRect' if native else 'PASS original SectRect calls=2 fixtures=14'
    end='[Inferior 1 (Remote target) detached]' if native else 'Exited via the debugger'
    if text.count(marker)!=(2 if native else 1) or text.count(end)!=1:raise ValueError('positive completion')
    code=next(r.body for r in read_resource_fork(ROOT/'tmp/runtime-data/Alone In The Dark') if r.kind==b'CODE' and r.rid==9)
    expected='4227205248680022486EFFF4486EFFECA8AA'
    if code[0xe80:0xe92].hex().upper()!=expected or re.findall(r'^SR_BYTES data=(\w+)$',text,re.M)!=[expected]:raise ValueError('original/live bytes')
    for i,(e,r) in enumerate(pairs(text,0 if native else 14)):
        if int(e['n'])!=min(i+1,2) or int(e['fixture'])!=max(0,i-1) or any(e[k]!=r[k] for k in ('n','fixture','sp','dst','r1','r2')):raise ValueError('call identity')
        a,b=[struct.unpack('>4h',bytes.fromhex(e[k])) for k in ('data1','data2')]
        bounds=(max(a[0],b[0]),max(a[1],b[1]),min(a[2],b[2]),min(a[3],b[3]))
        nonempty=bounds[0]<bounds[2] and bounds[1]<bounds[3]
        output=struct.pack('>4h',*(bounds if nonempty else (0,0,0,0))).hex().upper()
        if r['dest']!=output:raise ValueError('intersection output')
        for data,pointer in (('data1','r1'),('data2','r2')):
            if r[data]!=(output if e[pointer]==e['dst'] else e[data]):raise ValueError('input mutation/alias')
        before,result=int(e['result'],16),int(r['result'],16)
        if result>>8!=int(nonempty) or result&255!=before&255:raise ValueError('Boolean/padding')
        if int(r['returnsp'],16)!=int(e['sp'],16)+12 or int(r['d0'],16)!=((int(e['d0'],16)&0xffff0000)|14):raise ValueError('stack/D0')
        for reg in [f'd{n}' for n in range(1,8)]+[f'a{n}' for n in range(2,7)]:
            if e[reg]!=r[reg]:raise ValueError('preserved '+reg)
        if i<2:
            source='E0C0E0C01F401F40' if i==0 else '009600A0015E01E0'
            output='0000000001E00280' if i==0 else source
            if (e['data1'],e['data2'],r['dest'],result>>8)!=('0000000001E00280',source,output,1):raise ValueError('original rectangle selection')
    if native:
        from check_native_driver import check as check_startup
        check_startup(text,status)
        for n,output in ((1,'0000000001e00280'),(2,'009600a0015e01e0')):
            before=(ROOT/f'tmp/sectrect-native-{n}-enter-guard.bin').read_bytes();after=(ROOT/f'tmp/sectrect-native-{n}-return-guard.bin').read_bytes()
            if len(before)!=16 or len(after)!=16 or before[:4]!=after[:4] or before[12:]!=after[12:] or after[4:12].hex()!=output:raise ValueError('native surrounding bytes')
    return 'PASS SectRect '+('native original' if native else 'reference original plus 14 fixtures')+': bytes, intersection/empty/alias outputs, Boolean/padding and ABI'
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('log',type=Path);p.add_argument('--status',type=int,required=True);p.add_argument('--native',action='store_true');a=p.parse_args()
    try:print(check(a.log.read_text(),a.status,a.native))
    except (ValueError,OSError,KeyError) as e:raise SystemExit('FAIL SectRect: '+str(e))
