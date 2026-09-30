#!/usr/bin/env python3
"""First offscreen PaintRect: complete fill, preservation, paired pixels and ABI."""
import argparse,struct
from pathlib import Path
from check_driver22 import ROOT,one,fields
from resource_fork import read_resource_fork

def read(side,phase,kind):return (ROOT/'tmp'/f'paintworld-{side}-{phase}-{kind}.bin').read_bytes()
def check(reference,status,native=None,native_status=None):
    if status!=0 or any(x in reference for x in ('FAIL','LUA ERROR','Error in')) or reference.count('PASS original offscreen PaintRect')!=1 or reference.count('Exited via the debugger')!=1:raise ValueError('original completion')
    code=next(r.body for r in read_resource_fork(ROOT/'tmp/runtime-data/Alone In The Dark') if r.kind==b'CODE' and r.rid==5)
    if code[0x1e3e:0x1e46].hex()!='2f3cffff4d58a8a2':raise ValueError('original caller bytes')
    e,r=[fields(one(reference,r'^PR_'+phase+r' (.*)$')) for phase in ('ENTER','RETURN')]
    if one(reference,r'^PR_BYTES (\w+)$')!=f"{e['a5']-0xb2a8:08X}A8A2":raise ValueError('relocated original caller')
    if r['sp']!=e['sp']+4 or r['d0'] or r['d1']!=((e['d1']&0xffff0000)|8) or r['a1']!=e['port']:raise ValueError('original ABI')
    for reg in [f'd{i}' for i in range(3,8)]+[f'a{i}' for i in range(2,7)]:
        if e[reg]!=r[reg]:raise ValueError('original preserved '+reg)
    sides=['reference']
    if native:
        n=native.read_text()
        if native_status!=0 or any(x in n for x in ('FAIL','Error in','DIAG / GDB TIMEOUT','Program received signal')) or n.count('PASS native original offscreen PaintRect stack/register contract')!=1:raise ValueError('native call completion')
        sides.append('native')
    planes={}
    for side in sides:
        for kind in ('port','pm','clut','vis','clip','rect'):
            if read(side,'enter',kind)!=read(side,'return',kind):raise ValueError(side+' changed '+kind)
        pm=read(side,'enter','pm');port=read(side,'enter','port');rect=struct.unpack('>4h',read(side,'enter','rect')[4:12])
        stride=struct.unpack_from('>H',pm,4)[0]&0x3fff;mt,ml,mb,mr=struct.unpack_from('>4h',pm,6)
        if (stride,mt,ml,mb,mr,rect)!=(652,0,0,401,648,(0,0,140,320)):raise ValueError('reached geometry')
        before=read(side,'enter','pixels');after=read(side,'return','pixels');expected=bytearray(before)
        if len(before)!=stride*(mb-mt) or struct.unpack_from('>I',port,80)[0]!=255:raise ValueError('buffer/foreground')
        for y in range(140):expected[y*stride:y*stride+320]=b'\xff'*320
        if after!=expected:raise ValueError(side+' whole-buffer fill/preservation')
        planes[side]=b''.join(after[y*stride:y*stride+648] for y in range(401))
    if native and planes['reference']!=planes['native']:raise ValueError('paired pixel columns')
    print('PASS offscreen PaintRect: caller/ABI, 44800-pixel fill, full-buffer preservation'+('; paired 648x401 pixels' if native else '; reference only'))
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('reference',type=Path);p.add_argument('--status',required=True,type=int);p.add_argument('--native',type=Path);p.add_argument('--native-status',type=int);a=p.parse_args()
    try:check(a.reference.read_text(),a.status,a.native,a.native_status)
    except (ValueError,OSError,KeyError) as e:raise SystemExit('FAIL offscreen PaintRect: '+str(e))
