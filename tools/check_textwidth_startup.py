#!/usr/bin/env python3
"""Pair original/native TextWidth calls by exact strings, ranges and results."""
import argparse,re
from pathlib import Path
from resource_fork import read_resource_fork
root=Path(__file__).resolve().parents[1]
def fields(line):return dict(re.findall(r'(\w+)=(\w+)',line))
def check(reference,native,reference_status,native_status):
    for text,status in ((reference,reference_status),(native,native_status)):
        if status!=0 or any(s in text for s in ('FAIL','LUA ERROR','Error in sourced','timeout')):raise ValueError('run completion')
    if reference.count('PASS original TextWidth calls=220')!=1 or reference.count('Exited via the debugger')!=1 or native.count('PASS native TextWidth calls=220')!=1 or native.count('[Inferior 1 (Remote target) detached]')!=1:raise ValueError('positive completion')
    from check_native_driver import check as check_startup
    check_startup(native,native_status)
    code=next(r.body for r in read_resource_fork(root/'tmp/runtime-data/Alone In The Dark') if r.kind==b'CODE' and r.rid==12)
    if code[0x212:0x218].hex()!='548f3e80a886':raise ValueError('original bytes')
    def rows(text,label):return [fields(r) for r in re.findall('^'+label+' (.*)$',text,re.M)]
    enters,returns=rows(reference,'TW_ENTER'),rows(reference,'TW_RETURN')
    ne,nr=rows(native,'TW_NATIVE_ENTER'),rows(native,'TW_NATIVE_RETURN')
    if any(len(r)!=220 for r in (enters,returns,ne,nr)):raise ValueError('call count')
    if re.findall(r'^TW_BYTES data=(\w+)$',reference,re.M)!=['548F3E80A886']*220:raise ValueError('reference live caller')
    if [r['data'] for r in rows(native,'TW_NATIVE_BYTES')]!=['548F3E80A886']*220:raise ValueError('native live caller')
    for n,(e,r,a,b) in enumerate(zip(enters,returns,ne,nr),1):
        if int(a['n'])!=n or int(b['n'])!=n or a['segment12offset']!='216':raise ValueError('native order/caller')
        for key in ('count','first','font','size','face','extra'):
            if e[key]!=a[key]:raise ValueError(f'call {n} argument '+key)
        if r['width']!=b['width']:raise ValueError(f'call {n} width')
        if any(int(y['sp'],16)!=int(x['sp'],16)+8 for x,y in ((e,r),(a,b))):raise ValueError('stack cleanup')
        if e['port']!=r['port']:raise ValueError('reference port mutation')
        for reg in [f'd{i}' for i in range(3,8)]+[f'a{i}' for i in range(2,7)]:
            if e[reg]!=r[reg]:raise ValueError('reference preserved register')
        if (root/f'tmp/textwidth-native-{n}-text.bin').read_bytes()!=bytes.fromhex(e['text']):raise ValueError(f'call {n} string')
        before=(root/f'tmp/textwidth-native-{n}-before-port.bin').read_bytes()
        after=(root/f'tmp/textwidth-native-{n}-after-port.bin').read_bytes()
        if len(before)!=108 or before!=after:raise ValueError('native port mutation')
    return 'PASS paired TextWidth: 220 original strings/ranges/results, caller bytes, stack, preserved registers and ports'
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('reference',type=Path);p.add_argument('native',type=Path);p.add_argument('--reference-status',type=int,required=True);p.add_argument('--native-status',type=int,required=True);a=p.parse_args()
    try:print(check(a.reference.read_text(),a.native.read_text(),a.reference_status,a.native_status))
    except (ValueError,OSError,KeyError) as e:raise SystemExit('FAIL TextWidth startup: '+str(e))
