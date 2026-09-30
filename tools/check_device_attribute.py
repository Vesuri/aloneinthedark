#!/usr/bin/env python3
"""Verify actual GDevice flags, Pascal Boolean/padding and query ABI."""
import argparse,re
from pathlib import Path
from resource_fork import read_resource_fork
root=Path(__file__).resolve().parents[1]
def check(text,status,native=False):
    if status!=0 or any(s in text for s in ('FAIL','LUA ERROR','Error in','timeout')):raise ValueError('run completion')
    marker='PASS native TestDeviceAttribute original=1' if native else 'PASS original TestDeviceAttribute plus 16 flag fixtures'
    terminal='[Inferior 1 (Remote target) detached]' if native else 'Exited via the debugger'
    if text.count(marker)!=1 or text.count(terminal)!=1:raise ValueError('positive completion')
    code=next(r.body for r in read_resource_fork(root/'tmp/runtime-data/Alone In The Dark') if r.kind==b'CODE' and r.rid==9)
    original='42272F0A3F3C000DAA2C'
    if code[0xe32:0xe3c].hex().upper()!=original or re.findall(r'^DA_BYTES data=(\w+)$',text,re.M)!=[original]:raise ValueError('original/live caller bytes')
    rows=[(phase,dict(re.findall(r'(\w+)=([\w-]+)',row))) for phase,row in re.findall(r'^DA_(ENTRY|RETURN) (.*)$',text,re.M)]
    fixtures=[-1] if native else list(range(-1,16))
    if len(rows)!=len(fixtures)*2:raise ValueError('query count')
    for index,fixture in enumerate(fixtures):
        (ep,e),(rp,r)=rows[index*2:index*2+2]
        if ep!='ENTRY' or rp!='RETURN' or int(e['fixture'])!=fixture or e['fixture']!=r['fixture']:raise ValueError('query order')
        attribute=int(e['attribute'],16)
        if attribute!=(13 if fixture==-1 else fixture) or e['attribute']!=r['attribute'] or e['device']!=r['device']:raise ValueError('query arguments')
        if native:
            body=(root/'tmp/device-attribute-native-entry.bin').read_bytes()
            after=(root/'tmp/device-attribute-native-return.bin').read_bytes()
        else:body=bytes.fromhex(e['body']);after=bytes.fromhex(r['body'])
        if len(body)!=62 or body!=after:raise ValueError('device preservation')
        flags=int.from_bytes(body[20:22],'big')
        if flags!=0xb921:raise ValueError('main-device flags')
        result=int(r['result'],16);before=int(e['result'],16)
        if result>>8!=((flags>>attribute)&1) or result&255!=before&255:raise ValueError('Boolean/padding')
        if int(r['sp'],16)!=int(e['sp'],16)+6:raise ValueError('stack cleanup')
        if int(r['d0'],16)!=(int(e['d0'],16)&0xffff0000)|attribute or int(r['d1'],16)!=(int(e['d1'],16)&0xffff0000)|flags:raise ValueError('D0/D1 low words')
        for reg in [f'd{i}' for i in range(2,8)]+[f'a{i}' for i in range(2,7)]:
            if e[reg]!=r[reg]:raise ValueError('preserved '+reg)
        if fixture>=0 and (e['d0'],e['d1'],e['result'])!=('12345678','89ABCDEF','CCDD'):raise ValueError('fixture sentinels')
    if native:
        from check_native_driver import check as check_startup
        check_startup(text,status)
    return 'PASS '+('native original' if native else 'original and sixteen reference')+' device attribute queries: flags, Boolean/padding, stack/register contract and unchanged device'
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('log',type=Path);p.add_argument('--status',type=int,required=True);p.add_argument('--native',action='store_true');a=p.parse_args()
    try:print(check(a.log.read_text(),a.status,a.native))
    except (ValueError,OSError,KeyError) as e:raise SystemExit('FAIL device attribute: '+str(e))
