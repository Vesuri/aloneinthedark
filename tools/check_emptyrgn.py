#!/usr/bin/env python3
"""Pair the reached original EmptyRgn call, Boolean byte, registers and region."""
import argparse,re,struct
from pathlib import Path
from resource_fork import read_resource_fork
ROOT=Path(__file__).resolve().parents[1]

def check(reference,status,native=None,native_status=None):
    original=next(r.body for r in read_resource_fork(ROOT/'tmp/runtime-data/Alone In The Dark') if r.kind==b'CODE' and r.rid==4)[0x417a:0x4188]
    if original.hex()!='42272f39ffff4038a8e24a1f6608':raise ValueError('original caller')
    for side,text,exit_status in [('reference',reference,status)]+([('native',native,native_status)] if native is not None else []):
        marker='PASS '+('original' if side=='reference' else 'native original')+' EmptyRgn region and Boolean'
        end='Exited via the debugger' if side=='reference' else '[Inferior 1 (Remote target) detached]'
        if exit_status!=0 or re.search(r'FAIL|Error in|LUA ERROR|TIMEOUT|timeout|Program received signal',text) or text.count(marker)!=1 or text.count(end)!=1:raise ValueError(side+' completion')
        rows=[]
        for phase in ('ENTER','RETURN'):
            matches=re.findall(r'^EMPTYRGN_'+phase+r' (.*)$',text,re.M)
            if len(matches)!=1:raise ValueError(side+' '+phase+' record')
            rows.append({k:int(v,16) for k,v in re.findall(r'(\w+)=([0-9A-Fa-f]+)',matches[0])})
        e,r=rows
        def data(name):return (ROOT/f'tmp/emptyrgn-{side}-{name}.bin').read_bytes()
        raw=bytearray(original);struct.pack_into('>I',raw,4,(e['a5']-0xbfc8)&0xffffffff)
        if data('caller')!=raw:raise ValueError(side+' relocated caller')
        if r['sp']!=e['sp']+4 or r['result']!=((e['result']&255)|0x100):raise ValueError(side+' Boolean byte/padding/stack')
        if r['d1']!=0 or r['a0']!=e['body']+8 or r['a1']!=e['call']+2:raise ValueError(side+' return registers')
        if any(e[k]!=r[k] for k in ['d0']+[f'd{i}' for i in range(2,8)]+[f'a{i}' for i in range(2,7)]+['handle','body','size','zone','memerr','call']):raise ValueError(side+' preserved registers/state')
        if not e['handle'] or not e['body'] or e['size']!=10 or e['memerr']!=0 or data('enter-region')!=bytes.fromhex('000a0000000000000000') or data('return-region')!=data('enter-region'):raise ValueError(side+' complete unchanged region')
    print('PASS EmptyRgn: original/live bytes, Boolean and padding, stack/register ABI, exact unchanged empty region')

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('reference',type=Path);p.add_argument('--status',type=int,required=True);p.add_argument('--native',type=Path);p.add_argument('--native-status',type=int);a=p.parse_args()
    try:check(a.reference.read_text(),a.status,a.native.read_text() if a.native else None,a.native_status)
    except (ValueError,OSError,KeyError) as e:raise SystemExit('FAIL EmptyRgn: '+str(e))
