#!/usr/bin/env python3
"""Intro mode-0 PaintRect: complete fill, preservation, paired pixels and ABI."""
import argparse,struct
from pathlib import Path
from check_driver22 import ROOT,one,fields
from resource_fork import read_resource_fork

def read(side,phase,kind):return (ROOT/'tmp'/f'paintlater-{side}-{phase}-{kind}.bin').read_bytes()
def check(reference,status,native=None,native_status=None):
    if status!=0 or any(x in reference for x in ('FAIL','LUA ERROR','Error in')) or reference.count('PASS original later PaintRect')!=1 or reference.count('Exited via the debugger')!=1:raise ValueError('original completion')
    code=next(r.body for r in read_resource_fork(ROOT/'tmp/runtime-data/Alone In The Dark') if r.kind==b'CODE' and r.rid==13)
    if code[0xd4e:0xd54].hex()!='486efff0a8a2':raise ValueError('original caller bytes')
    e,r=[fields(one(reference,r'^PR_'+phase+r' (.*)$')) for phase in ('ENTER','RETURN')]
    if one(reference,r'^PR_BYTES (\w+)$')!='486EFFF0A8A2':raise ValueError('relocated original caller')
    if r['sp']!=e['sp']+4 or r['d0'] or r['d1']!=((e['d1']&0xffff0000)|8) or r['a1']!=e['port']:raise ValueError('original ABI')
    for reg in [f'd{i}' for i in range(3,8)]+[f'a{i}' for i in range(2,7)]:
        if e[reg]!=r[reg]:raise ValueError('original preserved '+reg)
    sides=['reference']
    if native:
        n=native.read_text()
        if native_status!=0 or any(x in n for x in ('FAIL','Error in','DIAG / GDB TIMEOUT','Program received signal')) or n.count('[Inferior 1 (Remote target) detached]')!=1 or n.count('PASS native original later mode-0 PaintRect stack/register contract')!=1:raise ValueError('native call completion')
        sides.append('native')
    planes={}
    for side in sides:
        for kind in ('port','pm','clut','vis','clip','rect'):
            if read(side,'enter',kind)!=read(side,'return',kind):raise ValueError(side+' changed '+kind)
        pm=read(side,'enter','pm');port=read(side,'enter','port');rect=struct.unpack('>4h',read(side,'enter','rect')[4:12])
        stride=struct.unpack_from('>H',pm,4)[0]&0x3fff;mt,ml,mb,mr=struct.unpack_from('>4h',pm,6)
        if (stride,mt,ml,mb,mr,rect)!=(652,0,0,401,648,(192,117,200,181)):raise ValueError('reached geometry')
        before=read(side,'enter','pixels');after=read(side,'return','pixels');expected=bytearray(before)
        if struct.unpack_from('>H',port,56)[0]!=0:raise ValueError('reached pen mode')
        if len(before)!=stride*(mb-mt) or struct.unpack_from('>I',port,80)[0]!=18:raise ValueError('buffer/foreground')
        for y in range(192,200):expected[y*stride+117:y*stride+181]=bytes([18])*64
        if after!=expected:raise ValueError(side+' whole-buffer fill/preservation')
        if sum(a!=b for a,b in zip(before,after))!=430:raise ValueError(side+' contrasting fill coverage')
        planes[side]=b''.join(after[y*stride:y*stride+648] for y in range(401))
    if native and planes['reference']!=planes['native']:raise ValueError('paired pixel columns')
    if native and read('reference','return','clut')[4:]!=read('native','return','clut')[4:]:raise ValueError('paired CLUT')
    print('PASS later PaintRect: caller/ABI, 512-pixel fill, full-buffer preservation'+('; paired 648x401 pixels' if native else '; reference only'))
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('reference',type=Path);p.add_argument('--status',required=True,type=int);p.add_argument('--native',type=Path);p.add_argument('--native-status',type=int);a=p.parse_args()
    try:check(a.reference.read_text(),a.status,a.native,a.native_status)
    except (ValueError,OSError,KeyError) as e:raise SystemExit('FAIL later PaintRect: '+str(e))
