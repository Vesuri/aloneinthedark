#!/usr/bin/env python3
"""Compare the original presentation picture with the window renderer."""
import argparse,re,struct,hashlib
from pathlib import Path
from check_picture8 import decode,color_index,rect,word
from resource_fork import read_resource_fork
ROOT=Path(__file__).resolve().parents[1]
def check(log,status,native=False):
    if status!=0 or any(x in log for x in ('FAIL','LUA ERROR','Error in','timeout')):raise ValueError('run completion')
    if log.count('PASS original presentation picture calls=1')!=1:raise ValueError('positive control')
    terminal='[Inferior 1 (Remote target) detached]' if native else 'Exited via the debugger'
    if log.count(terminal)!=1:raise ValueError('terminal control')
    resources=read_resource_fork(ROOT/'tmp/runtime-data/Alone In The Dark')
    code=next(r.body for r in resources if r.kind==b'CODE' and r.rid==5)
    original=next(r.body for r in resources if r.kind==b'PICT' and r.rid==1500)
    if code[0x20ec:0x20f4].hex()!='2e8b486effe4a8f6' or re.findall(r'^PRESENTPICT_BYTES data=(\w+)$',log,re.M)!=['2E8B486EFFE4A8F6']:raise ValueError('original/live bytes')
    lines=[re.findall(r'^PRESENTPICT_'+phase+r' (.*)$',log,re.M) for phase in ('ENTER','RETURN')]
    if any(len(x)!=1 for x in lines):raise ValueError('call count')
    e,r=[dict(re.findall(r'(\w+)=([^ ]+)',x[0])) for x in lines]
    if int(r['sp'],16)!=int(e['sp'],16)+8:raise ValueError('stack cleanup')
    for reg in [f'd{i}' for i in range(8)]+[f'a{i}' for i in range(7)]:
        if e[reg]!=r[reg]:raise ValueError('preserved '+reg)
    def data(phase,kind,platform=None):
        return (ROOT/'tmp'/f'presentpict-{platform or ("native" if native else "reference")}-1-{phase}-{kind}.bin').read_bytes()
    for kind in ('port','pm','vis','clip','clut','picture'):
        if data('enter',kind)!=data('return',kind):raise ValueError('record changed '+kind)
    if data('enter','picture')!=original:raise ValueError('picture identity')
    frame,pclip,(bounds,palette,rows)=decode(original)
    target=struct.unpack('>4h',bytes.fromhex(e['rect']))
    if target!=(4,32,196,288) or frame!=pclip or frame!=bounds:raise ValueError('measured rectangles')
    pm=data('enter','pm');stride=word(pm,4)&0x3fff;mt,ml,mb,mr=rect(pm,6)
    if stride!=640 or (mt,ml,mb,mr)!=(-150,-160,330,480):raise ValueError('screen geometry')
    before=data('enter','pixels');after=data('return','pixels')
    if len(before)!=307200 or len(after)!=307200:raise ValueError('full buffer capture')
    table=data('enter','clut');inverse=data('return','inverse','reference')
    mapping=[color_index(struct.unpack_from('>3H',palette,10+i*8),table,inverse) for i in range(256)]
    expected=bytearray(before)
    limits=[rect(data('enter','port'),16),rect(data('enter','vis'),2),rect(data('enter','clip'),2),(mt,ml,mb,mr)]
    for y in range(target[0],target[2]):
        for x in range(target[1],target[3]):
            if all(t<=y<b and l<=x<r for t,l,b,r in limits):
                expected[(y-mt)*stride+x-ml]=mapping[rows[y-target[0]][x-target[1]]]
    if expected!=after:raise ValueError('independent full-buffer decode/colour/clip comparison')
    if native:
        from check_native_driver import check as startup
        startup(log,status)
        from check_aga_capture import check_frame
        m=re.findall(r'PRESENTPICT_AGA front=([0-9A-F]+) queued=5 presented=5 pending=0 line=(\d+) late=0',log)
        if len(m)!=1 or int(m[0][1])>=72:raise ValueError('picture publication')
        transfer=(ROOT/'tmp/video-transfer-lut16.bin').read_bytes()
        if hashlib.sha256(transfer).hexdigest()!='bf0a6433c155a61989e5dc0571bae1357066ab476a24d0afaf2e2aa7094fe2aa':raise ValueError('video transfer identity')
        check_frame(ROOT/'tmp','presentpict-aga',after,table,160,150,int(m[0][0],16),transfer)
        ref=data('return','pixels','reference');refct=data('return','clut','reference')
        if table[4:]!=refct[4:] or any(after[y*640+160:y*640+480]!=ref[y*640+160:y*640+480] for y in range(150,350)):raise ValueError('paired client/CLUT')
    print('PASS presentation picture: original bytes, 16358-byte source, all registers/stack, full buffer decode/clip/colour mapping and preserved records')
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('log',type=Path);p.add_argument('--status',type=int,required=True);p.add_argument('--native',action='store_true');a=p.parse_args()
    try:check(a.log.read_text(),a.status,a.native)
    except (ValueError,OSError,KeyError) as e:raise SystemExit('FAIL presentation picture: '+str(e))
