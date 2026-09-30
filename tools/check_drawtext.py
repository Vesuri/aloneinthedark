#!/usr/bin/env python3
"""Paired intro DrawText contract; owned glyphs intentionally differ from Times."""
import argparse,json,re,struct
from pathlib import Path
from resource_fork import read_resource_fork
ROOT=Path(__file__).resolve().parents[1]
def read(side,phase,kind):return (ROOT/'tmp'/f'drawtext-{side}-{phase}-{kind}.bin').read_bytes()
def word(data,offset):return struct.unpack_from('>H',data,offset)[0]
def check(reference,status,native=None,native_status=None):
    if status!=0 or any(x in reference for x in ('FAIL','LUA ERROR','Error in')) or reference.count('PASS original intro DrawText fixtures=3')!=1 or reference.count('Exited via the debugger')!=1:raise ValueError('original completion')
    code=next(r.body for r in read_resource_fork(ROOT/'tmp/runtime-data/Alone In The Dark') if r.kind==b'CODE' and r.rid==12)
    if code[0x342:0x348].hex()!='548f3e80a885':raise ValueError('original caller bytes')
    text=(ROOT/'tmp/drawtext-reference-string.bin').read_bytes()
    if text.decode('mac_roman')!='©1992 I•Motion/Infogrames, 1994 Interplay':raise ValueError('original string')
    for i,(pen,frac) in enumerate(((285,0x1c00),(532,0xb800),(37,0x8000),(37,0x8000))):
        side='reference'+(f'-fixture{i}' if i else '')
        e,r=[dict((k,int(v,16)) for k,v in re.findall(r'(sp|d[0-7]|a[0-6])=([0-9A-F]+)',re.search(r'^TEXT_'+p+f' fixture={i} .*$',reference,re.M)[0])) for p in ('ENTER','RETURN')]
        if r['sp']!=e['sp']+(4 if i==2 else 8) or r['d0']:raise ValueError('original ABI')
        if i!=2 and any(e[k]!=r[k] for k in [f'd{n}' for n in range(1,8)]+[f'a{n}' for n in range(1,7)]):raise ValueError('original preserved registers')
        before=read(side,'enter','port');after=read(side,'return','port');expected=bytearray(before)
        struct.pack_into('>H',expected,14,frac);struct.pack_into('>H',expected,50,pen)
        if after!=expected:raise ValueError('original pen or preserved port')
        if i>=2 and read(side,'enter','pixels')!=read(side,'return','pixels'):raise ValueError('MoveTo/empty changed pixels')
        for kind in ('pm','vis','clip','clut'):
            if read(side,'enter',kind)!=read(side,'return',kind):raise ValueError('original changed '+kind)
    if native:
        log=native.read_text()
        if native_status!=0 or any(x in log for x in ('FAIL','Error in','DIAG / GDB TIMEOUT','Program received signal')) or log.count('[Inferior 1 (Remote target) detached]')!=1 or log.count('PASS native original DrawText stack/register contract')!=1:raise ValueError('native completion')
        if 'DT_NATIVE_BYTES 548F3E80A885' not in log or 'DT_ARGUMENTS count=41 first=0' not in log:raise ValueError('native call identity')
        if (ROOT/'tmp/drawtext-native-string.bin').read_bytes()!=text:raise ValueError('native string')
        before=read('native','enter','port');after=read('native','return','port');expected=bytearray(before)
        struct.pack_into('>H',expected,14,0x1c00);struct.pack_into('>H',expected,50,285)
        if after!=expected or word(before,14)!=0x8000 or word(before,50)!=37 or word(before,48)!=196:raise ValueError('native pen/preserved port')
        for kind in ('pm','vis','clip','clut'):
            if read('native','enter',kind)!=read('native','return',kind):raise ValueError('native changed '+kind)
        for off,size in ((14,2),(16,8),(48,4),(68,20)):
            if before[off:off+size]!=read('reference','enter','port')[off:off+size]:raise ValueError('paired text state')
        native_before=read('native','enter','pixels');reference_before=read('reference','enter','pixels')
        if any(native_before[y*652:y*652+648]!=reference_before[y*652:y*652+648] for y in range(401)):raise ValueError('paired initial pixel columns')
        if read('native','return','clut')[4:]!=read('reference','return','clut')[4:]:raise ValueError('paired colours')
        expected=bytearray(read('native','enter','pixels'));pm=read('native','enter','pm')
        if struct.unpack_from('>4h',pm,6)!=(0,0,401,648) or word(pm,4)&0x3fff!=652:raise ValueError('geometry')
        # Independent placeholder stencil from the authored shapes, with measured
        # cell boundaries. This verifies every pixel, including stride padding.
        shapes=json.loads((ROOT/'resources/placeholder-font.json').read_text())['glyphs']
        metrics=(ROOT/'src/mac/Times14Metrics.h').read_text().split('advances[256]={')[1].split('};')[0]
        units=[int(x) for x in re.findall(r'\d+',metrics)];position=32768
        limits=[struct.unpack_from('>4h',before,16)]+[struct.unpack_from('>4h',read('native','enter',r),2) for r in ('vis','clip')]
        for c in text:
            end=position+units[c]*76544;cell=end//65536-position//65536
            shape=shapes[bytes([c]).decode('mac_roman').upper()]
            columns=[x for x in range(5) if any(row&(16>>x) for row in shape)]
            if columns:
                lo,hi=min(columns),max(columns)+1;width=min(hi-lo,cell-1)
                for y in range(12):
                    for x in range(width):
                        px=37+position//65536+x;py=184+y
                        if shape[y*7//12]&(16>>(lo+x*(hi-lo)//width)) and all(t<=py<b and l<=px<r for t,l,b,r in limits):expected[py*652+px]=26
            position=end
        if read('native','return','pixels')!=expected:raise ValueError('native full-buffer stencil/preservation')
        print('PASS native DrawText: original string/ABI/pen/colour, full-buffer owned glyph stencil and preservation')
    print('PASS original DrawText: fractional accumulation, repeated draw, MoveTo reset, empty draw, ABI and preserved metadata')
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('reference',type=Path);p.add_argument('--status',required=True,type=int);p.add_argument('--native',type=Path);p.add_argument('--native-status',type=int);a=p.parse_args()
    try:check(a.reference.read_text(),a.status,a.native,a.native_status)
    except (ValueError,OSError,KeyError,TypeError) as e:raise SystemExit('FAIL DrawText: '+str(e))
