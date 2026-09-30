#!/usr/bin/env python3
"""Check the reached clut 129 layout, ownership and original-call ABI."""
import argparse,re,struct
from pathlib import Path
from resource_fork import read_resource_fork
ROOT=Path(__file__).resolve().parents[1]
def check(reference,status,native=None,native_status=None):
    text=reference.read_text()
    def completion(text,status,marker,end):
        if status!=0 or any(v in text for v in ('FAIL','Error in','LUA ERROR','timeout')) or text.count(marker)!=1 or text.count(end)!=1:raise ValueError('positive completion')
    completion(text,status,'PASS original clut129 and ownership fixtures=6','Exited via the debugger')
    resources=read_resource_fork(ROOT/'tmp/runtime-data/Alone In The Dark')
    code=next(r.body for r in resources if r.kind==b'CODE' and r.rid==5)
    source=next(r for r in resources if r.kind==b'clut' and r.rid==129)
    if code[0x1fd6:0x1fde].hex()!='42973f3c0081aa18' or text.count('CT129_BYTES 42973F3C0081AA18')!=1:raise ValueError('original caller bytes')
    if source.attrs!=0x20 or len(source.body)!=2064 or source.body[4:8]!=bytes.fromhex('400000ff'):raise ValueError('source layout')
    def rows(label):return [dict((k,int(v,16)) for k,v in re.findall(r'(\w+)=([0-9A-F]+)(?: |$)',line)) for line in re.findall(r'^CT129_'+label+r' (.*)$',text,re.M)]
    enters,returns=rows('ENTER'),rows('RETURN')
    if len(enters)!=7 or len(returns)!=7:raise ValueError('fixture count')
    for i,(e,r) in enumerate(zip(enters,returns)):
        if e['fixture']!=i or r['fixture']!=i:raise ValueError('fixture order')
        # Original entry is observed at the exception dispatcher (eight bytes).
        if r['sp']!=e['sp']+[10,0,0,4,6,0,0][i]:raise ValueError('stack cleanup')
        for reg in [f'd{j}' for j in range(1,8)]+[f'a{j}' for j in range(2,7)]:
            if e[reg]!=r[reg]:raise ValueError('preserved '+reg)
        if r['mem']!=0 or r['res']!=(0xff40 if i==3 else 0):raise ValueError('error state')
    first=returns[0]
    if not first['result'] or first['d0']!=first['result'] or first['a0']!=first['result']:raise ValueError('original handle result')
    if [returns[i]['d0'] for i in (1,2,5,6)]!=[2064,0,0x60,2064]:raise ValueError('size/state fixtures')
    if not returns[4]['result'] or returns[4]['result']==first['result']:raise ValueError('detached resource reload')
    returned=(ROOT/'tmp/ctable129-reference-returned.bin').read_bytes()
    resource=(ROOT/'tmp/ctable129-reference-resource.bin').read_bytes()
    if resource!=source.body or len(returned)!=2064 or returned[4:]!=source.body[4:] or returned[:4]==source.body[:4]:raise ValueError('exact resource/table bytes and new seed')
    if native:
        text=native.read_text()
        completion(text,native_status,'PASS native original clut129 bytes/ownership/ABI MDRV=absent','[Inferior 1 (Remote target) detached]')
        if text.count('CT129_NATIVE_BYTES 42973F3C0081AA18')!=1:raise ValueError('native caller bytes')
        m=re.search(r'^CT129_NATIVE_RETURN handle=([0-9A-F]+) body=([0-9A-F]+) size=2064 state=0 seed=([0-9A-F]+) flags=4000 entries=256$',text,re.M)
        if not m or not int(m[1],16) or not int(m[2],16):raise ValueError('native table ownership/header')
        body=(ROOT/'tmp/ctable129-native-returned.bin').read_bytes()
        if body!=struct.pack('>I',int(m[3],16))+returned[4:]:raise ValueError('native full body including trailing bytes')
    print('PASS clut129: original bytes, 2064-byte body, 256 entries, flags, seed, trailing bytes, detachment, handle state and ABI')
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('reference',type=Path);p.add_argument('--status',type=int,required=True);p.add_argument('--native',type=Path);p.add_argument('--native-status',type=int);a=p.parse_args()
    try:check(a.reference,a.status,a.native,a.native_status)
    except (OSError,ValueError,KeyError) as e:raise SystemExit('FAIL clut129: '+str(e))
