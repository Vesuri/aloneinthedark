#!/usr/bin/env python3
"""Validate original RGB getters against selected-port fields and guarded writes."""
import argparse,re
from pathlib import Path
from resource_fork import read_resource_fork
ROOT=Path(__file__).resolve().parents[1]
def rows(text,phase):
    return [dict(re.findall(r'(\w+)=([0-9A-Fa-f]+)(?: |$)',line)) for line in re.findall(r'^GC_'+phase+r' (.*)$',text,re.M)]
def check(text,status,native=False):
    if status!=0 or any(s in text for s in ('FAIL','Error in','LUA ERROR','timeout')):raise ValueError('run completion')
    marker='PASS native colour getter n=' if native else 'PASS original colour getters calls=2 fixtures=4'
    end='[Inferior 1 (Remote target) detached]' if native else 'Exited via the debugger'
    if text.count(marker)!=(2 if native else 1) or text.count(end)!=1:raise ValueError('positive completion')
    expected=['2F2E0008AA19','2F2E000CAA1A']
    code=next(r.body for r in read_resource_fork(ROOT/'tmp/runtime-data/Alone In The Dark') if r.kind==b'CODE' and r.rid==12)
    if [code[o:o+6].hex().upper() for o in (0x6238,0x623e)]!=expected:raise ValueError('original bytes')
    if re.findall(r'^GC_BYTES n=\d+ data=(\w+)$',text,re.M)!=expected:raise ValueError('live caller bytes')
    enters,returns=rows(text,'ENTER'),rows(text,'RETURN')
    if len(enters)!=(2 if native else 6) or len(returns)!=len(enters):raise ValueError('call count')
    for i,(a,b) in enumerate(zip(enters,returns)):
        trap=0xaa19+i%2;offset=36 if trap==0xaa19 else 42
        n=min(i+1,2);fixture=max(0,i-1)
        if int(a['n'])!=n or int(a['fixture'])!=fixture or int(a['trap'],16)!=trap:raise ValueError('call order')
        for k in ('n','fixture','trap','rgb','port','fields','version'):
            if a[k]!=b[k]:raise ValueError('input preservation '+k)
        if int(a['version'],16)&0xc000!=0xc000:raise ValueError('colour port')
        color=a['fields'][0:12] if offset==36 else a['fields'][12:24]
        if b['value']!=color:raise ValueError('selected RGB value')
        before,after=bytes.fromhex(a['guard']),bytes.fromhex(b['guard'])
        if len(before)!=14 or len(after)!=14 or before[:4]!=after[:4] or before[10:]!=after[10:] or after[4:10].hex().upper()!=color:raise ValueError('six-byte guarded write')
        if int(b['sp'],16)!=int(a['sp'],16)+4 or int(b['d0'],16)!=(80 if offset==36 else 84) or int(b['d1'],16)!=offset or b['a1'].lstrip('0')!=a['rgb'].lstrip('0'):raise ValueError('stack/register outputs')
        for reg in [f'd{j}' for j in range(2,8)]+[f'a{j}' for j in range(2,7)]:
            if a[reg]!=b[reg]:raise ValueError('preserved '+reg)
        stem=f'getcolor-native-{n}' if native else f'getcolor-reference-{n}-{fixture}'
        before=(ROOT/'tmp'/f'{stem}-enter-port.bin').read_bytes();after=(ROOT/'tmp'/f'{stem}-return-port.bin').read_bytes()
        if len(before)!=108 or before!=after or before[36:48].hex().upper()!=a['fields']:raise ValueError('whole port unchanged')
        if i<2 and color!='000000000000':raise ValueError('original black RGB')
    if not native:
        if len(re.findall(r'^GC_INIT thePort=[0-9A-F]+ a5=[0-9A-F]+$',text,re.M))!=1:raise ValueError('actual InitGraf pointer')
        if [r['value'] for r in returns[2:]]!=['123456789ABC','DEF013572468','FFFF00008000','0000FFFF8001']:raise ValueError('nontrivial reference fixtures')
    else:
        from check_native_driver import check as startup
        startup(text,status)
    return 'PASS colour getters: original caller bytes, selected RGB fields, six-byte guards, unchanged ports and stack/register contract'
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('log',type=Path);p.add_argument('--status',type=int,required=True);p.add_argument('--native',action='store_true');a=p.parse_args()
    try:print(check(a.log.read_text(),a.status,a.native))
    except (ValueError,KeyError,OSError) as e:raise SystemExit('FAIL colour getters: '+str(e))
