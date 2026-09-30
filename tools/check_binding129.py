#!/usr/bin/env python3
"""Validate original presentation palette replacement and intentional chrome omission."""
import argparse,os,re,struct,subprocess,tempfile
from pathlib import Path
from resource_fork import read_resource_fork
ROOT=Path(__file__).resolve().parents[1]
NAMES=('window','windowpm','gd','pm','clut','pixels','palette','private','old','old-private')
def data(machine,phase,name):return (ROOT/'tmp'/f'binding129-{machine}-{phase}-{name}.bin').read_bytes()
def fields(line):return {k:int(v,16) for k,v in re.findall(r'(\w+)=([0-9A-Fa-f]+)(?: |$)',line)}
def one(text,pattern):
    m=re.findall(pattern,text,re.M)
    if len(m)!=1:raise ValueError('missing/duplicate '+pattern)
    return m[0]
def complete(text,status,marker,end):
    if status!=0 or any(s in text for s in ('FAIL','Error in','LUA ERROR','timeout')) or text.count(marker)!=1 or text.count(end)!=1:raise ValueError('completion')
def check(reference,status,native=None,native_status=None,helper=False):
    text=reference.read_text();complete(text,status,'PASS original presentation palette binding','Exited via the debugger')
    e=fields(one(text,r'^BIND129_ENTER (.*)$'));r=fields(one(text,r'^BIND129_RETURN (.*)$'))
    code=next(r.body for r in read_resource_fork(ROOT/'tmp/runtime-data/Alone In The Dark') if r.kind==b'CODE' and r.rid==5)
    raw=code[0x20c0:0x20ce]
    if raw.hex()!='2f002f39ffff4d601f3c0001aa95':raise ValueError('original source bytes')
    def guard(value,a5):
        live=bytes.fromhex(value);expected=raw[:4]+struct.pack('>I',(a5-0xb2a0)&0xffffffff)+raw[8:]
        if live!=expected:raise ValueError('live caller/A5 relocation')
    guard(one(text,r'^BIND129_BYTES (\w+)$'),e['a5'])
    if r['sp']!=e['sp']+10:raise ValueError('stack cleanup')
    for reg in [f'd{i}' for i in range(3,8)]+[f'a{i}' for i in range(2,7)]:
        if e[reg]!=r[reg]:raise ValueError('preserved '+reg)
    for key in ('window','palette','default'):
        if e[key]!=r[key]:raise ValueError('identity preservation')
    args=bytes.fromhex(one(text,r'^BIND129_ENTER .*args=(\w+) .*'))
    if args[0]!=1 or int.from_bytes(args[2:6],'big')!=e['palette'] or int.from_bytes(args[6:10],'big')!=e['window']:raise ValueError('arguments')
    if int(one(text,r'^BIND129_BINDING before=(\w+)$'),16)!=e['default'] or int(one(text,r'^BIND129_BINDING after=(\w+)$'),16)!=e['palette']:raise ValueError('actual window binding')
    for name in NAMES+('hardware',):
        if data('reference','query_before',name)!=data('reference','enter',name):raise ValueError('GetPalette query mutated '+name)
    for name in ('window','windowpm','gd','pm','old','old-private'):
        if data('reference','enter',name)!=data('reference','return',name):raise ValueError('reference modified '+name)
    before=data('reference','enter','palette');after=data('reference','return','palette');expected=bytearray(before)
    if len(before)!=4112 or before[:12]!=struct.pack('>III',0x01000000,3,0):raise ValueError('new palette initial state')
    struct.pack_into('>II',expected,4,0xc003,1)
    for i in range(256):struct.pack_into('>H',expected,26+16*i,0x800a)
    if after!=expected:raise ValueError('complete realized palette')
    ct=data('reference','return','clut');prior=data('reference','enter','clut')
    if len(ct)!=2056 or ct[:4]==prior[:4] or data('reference','return','private')!=ct[:4] or data('reference','enter','private')!=bytes(4):raise ValueError('new/private device seed')
    lut=(ROOT/'tmp/video-transfer-lut16.bin').read_bytes();hardware=data('reference','return','hardware')
    if len(lut)!=65536 or len(hardware)!=1024:raise ValueError('video tables')
    for i in range(256):
        if hardware[i*4+1:i*4+4]!=bytes(lut[v] for v in struct.unpack_from('>3H',ct,10+i*8)):raise ValueError('video colour transfer')
    a=data('reference','enter','pixels');b=data('reference','return','pixels')
    if len(a)!=307200 or len(b)!=307200:raise ValueError('full screen capture')
    changed=[i for i in range(len(a)) if a[i]!=b[i]]
    if len(changed)!=5056 or any(not (132<=i//640<150 and 160<=i%640<480) for i in changed):raise ValueError('only measured title-bar redraw')
    if helper:
        with tempfile.TemporaryDirectory(prefix='aitd-binding-') as work:
            exe=Path(work)/'test';subprocess.run([os.environ.get('HOST_CXX','c++'),'-std=c++17','-Wall','-Wextra','-Werror','-fsanitize=address,undefined',str(ROOT/'tools/test_palette8.cpp'),'-o',str(exe)],check=True)
            subprocess.run([str(exe),'--replacement',str(ROOT/'tmp')],check=True,timeout=30)
    for name in NAMES+('hardware',):
        if data('reference','query_after',name)!=data('reference','return',name):raise ValueError('post-query mutated '+name)
    next_pixels=data('reference','next','pixels')
    if any(next_pixels[y*640+160:y*640+480]!=bytes(320) for y in range(150,350)):raise ValueError('original subsequent white background')
    if native:
        text=native.read_text();complete(text,native_status,'PASS native presentation binding ABI','[Inferior 1 (Remote target) detached]')
        from check_native_driver import check as startup
        startup(text,native_status)
        value,a5=one(text,r'^BIND129_NATIVE_BYTES (\w+) a5=(\w+)$');guard(value,int(a5,16))
        es=fields(one(text,r'^BIND129_NATIVE_STATE phase=enter (.*)$'));rs=fields(one(text,r'^BIND129_NATIVE_STATE phase=return (.*)$'))
        if es['binding']!=es['default'] or es['active']!=es['default'] or rs['binding']!=es['palette'] or rs['active']!=es['palette'] or rs['default']!=es['default'] or rs['updates']!=1 or rs['pixelDirty'] or rs['rects']:raise ValueError('native association/publication state')
        for name in ('window','windowpm','gd','pm','old','old-private','pixels'):
            if data('native','enter',name)!=data('native','return',name):raise ValueError('native modified '+name)
        for phase in ('enter','return'):
            palette=data('native',phase,'palette');ref=data('reference',phase,'palette')
            if palette[:12]+palette[16:]!=ref[:12]+ref[16:]:raise ValueError('paired palette '+phase)
            table=data('native',phase,'clut')
            if table[4:]!=data('reference',phase,'clut')[4:]:raise ValueError('paired device table '+phase)
            pixels=data('native',phase,'pixels');ref=data('reference',phase,'pixels')
            if any(pixels[y*640+160:y*640+480]!=ref[y*640+160:y*640+480] for y in range(150,350)):raise ValueError('paired client pixels')
        if data('native','return','private')!=data('native','return','clut')[:4] or data('native','enter','private')!=bytes(4):raise ValueError('native private seed')
    print('PASS presentation binding: actual association, complete palette/CLUT/private transition, preserved old state and client pixels; Mac title bar intentionally omitted')
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('reference',type=Path);p.add_argument('--status',type=int,required=True);p.add_argument('--native',type=Path);p.add_argument('--native-status',type=int);p.add_argument('--helper',action='store_true');a=p.parse_args()
    try:check(a.reference,a.status,a.native,a.native_status,a.helper)
    except (ValueError,KeyError,OSError) as e:raise SystemExit('FAIL presentation binding: '+str(e))
