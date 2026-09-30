#!/usr/bin/env python3
"""Pair the original Dark RectRgn call, complete region bytes and heap ownership."""
import argparse,struct,re
from pathlib import Path
from resource_fork import read_resource_fork
ROOT=Path(__file__).resolve().parents[1]

def row(text,label):
    lines=re.findall(r'^RECTRGN_'+label+r' (.*)$',text,re.M)
    if len(lines)!=1:raise ValueError('missing/duplicate '+label)
    return {k:int(v,16) for k,v in re.findall(r'(\w+)=([0-9A-Fa-f]+)',lines[0])}

def check(reference,status,native=None,native_status=None):
    code=next(r.body for r in read_resource_fork(ROOT/'tmp/runtime-data/Alone In The Dark') if r.kind==b'CODE' and r.rid==4)
    original=code[0x3d36:0x3d48]
    if original.hex()!='2f39ffff40342079ffff3db248680016a8df':raise ValueError('original caller bytes')
    results=[]
    for side,text,exit_status in [('reference',reference,status)]+([('native',native,native_status)] if native is not None else []):
        marker='PASS original RectRgn and ownership queries' if side=='reference' else 'PASS native original RectRgn and ownership'
        ending='Exited via the debugger' if side=='reference' else '[Inferior 1 (Remote target) detached]'
        if exit_status!=0 or any(x in text for x in ('FAIL','Error in','LUA ERROR','TIMEOUT','timeout','Program received signal','Cannot execute','Remote connection closed')) or text.count(marker)!=1 or text.count(ending)!=1:
            raise ValueError(side+' normal completion')
        e,r=row(text,'ENTER'),row(text,'RETURN')
        raw=bytearray(original)
        for at in (2,8):struct.pack_into('>I',raw,at,(struct.unpack_from('>I',raw,at)[0]+e['a5'])&0xffffffff)
        def data(name):return (ROOT/f'tmp/rectrgn-{side}-{name}.bin').read_bytes()
        if data('caller')!=raw:raise ValueError(side+' live relocated caller')
        if not e['handle'] or not e['body'] or e['handle']==e['body'] or r['sp']!=e['sp']+8:raise ValueError(side+' handle/stack')
        if any(e[k]!=r[k] for k in ('handle','body','size','rect','zone','memerr')) or e['size']!=10 or e['memerr']!=0:raise ValueError(side+' preserved region ownership/error')
        if r['a0']!=e['handle'] or r['a1']!=r['body'] or any(e[k]!=r[k] for k in [f'd{i}' for i in range(8)]+[f'a{i}' for i in range(2,7)]):raise ValueError(side+' return registers')
        before,after,rect=data('enter-region'),data('return-region'),data('enter-rect')
        if before!=bytes.fromhex('000a0000000000000000') or len(rect)!=8 or data('return-rect')!=rect:raise ValueError(side+' initial region or unchanged rectangle')
        top,left,bottom,right=struct.unpack('>4h',rect)
        if top>=bottom or left>=right or after!=b'\0\x0a'+rect:raise ValueError(side+' complete rectangular region')
        if side=='reference':
            if row(text,'SIZE')!={'size':10,'memerr':0} or row(text,'FLAGS')!={'flags':0,'memerr':0}:raise ValueError('original size/flags')
            ownership=row(text,'OWNER')
        else:
            ownership=row(text,'NATIVE')
            if ownership['size']!=10 or ownership['flags']!=0:raise ValueError('native size/flags')
            if text.count('PASS menu-list checkpoint original-MDRV=absent')!=1:raise ValueError('MDRV absence')
        if ownership['owner']!=e['zone'] or ownership['zone']!=e['zone'] or ownership['memerr']!=0:raise ValueError(side+' owning heap')
        results.append((before,after,rect))
    if len(results)==2 and results[0]!=results[1]:raise ValueError('paired exact rectangle/region')
    print('PASS '+('paired' if native is not None else 'original')+' RectRgn: caller bytes, stack/register ABI, complete region, unchanged rectangle and ten-byte unlocked ownership')

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('reference',type=Path);p.add_argument('--status',required=True,type=int);p.add_argument('--native',type=Path);p.add_argument('--native-status',type=int);a=p.parse_args()
    try:check(a.reference.read_text(),a.status,a.native.read_text() if a.native else None,a.native_status)
    except (ValueError,OSError,KeyError) as e:raise SystemExit('FAIL RectRgn: '+str(e))
