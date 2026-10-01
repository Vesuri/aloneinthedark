#!/usr/bin/env python3
"""Paired intro DrawText contract; owned glyphs intentionally differ from Times."""
import argparse,json,re,struct
from pathlib import Path
from resource_fork import read_resource_fork
ROOT=Path(__file__).resolve().parents[1]
def word(data,offset):return struct.unpack_from('>H',data,offset)[0]
def check(reference,status,native=None,native_status=None,dot=False,accent=False):
    if dot and accent:raise ValueError('conflicting cases')
    prefix='accenttext' if accent else ('dottext' if dot else 'drawtext')
    def read(side,phase,kind):return (ROOT/'tmp'/f'{prefix}-{side}-{phase}-{kind}.bin').read_bytes()
    label='accented-a' if accent else ('dot-above' if dot else 'intro')
    tag='ACCENT' if accent else ('DOT' if dot else 'DT')
    x,y=(99,114) if accent else ((129,98) if dot else (37,196))
    ends=((179,0xb900),(229,0xf200),(129,0x8000),(129,0x8000)) if dot else ((285,0x1c00),(532,0xb800),(37,0x8000),(37,0x8000))
    if accent:ends=((125,0x3200),(150,0xe400),(99,0x8000),(99,0x8000))
    if status!=0 or any(x in reference for x in ('FAIL','LUA ERROR','Error in')) or reference.count(f'PASS original {label} DrawText fixtures=3')!=1 or reference.count('Exited via the debugger')!=1:raise ValueError('original completion')
    code=next(r.body for r in read_resource_fork(ROOT/'tmp/runtime-data/Alone In The Dark') if r.kind==b'CODE' and r.rid==12)
    if code[0x342:0x348].hex()!='548f3e80a885':raise ValueError('original caller bytes')
    text=(ROOT/'tmp'/f'{prefix}-reference-string.bin').read_bytes()
    if text.decode('mac_roman')!=('Yaâl' if accent else ('I˙Motion' if dot else '©1992 I•Motion/Infogrames, 1994 Interplay')):raise ValueError('original string')
    for i,(pen,frac) in enumerate(ends):
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
    if dot:
        if code[0x138:0x13e].hex()!='486efff8a88b':raise ValueError('original FontInfo bytes')
        e=re.search(r'DOT_METRIC_ENTER state=([0-9A-F]+) data=([0-9A-F]+) bytes=486EFFF8A88B',reference)
        r=re.search(r'DOT_METRIC_RETURN data=([0-9A-F]+)',reference)
        if not e or not r or e[1]!='001400000001000E00000000' or r[1]!='000C0004000F0000'+e[2][16:]:raise ValueError('original Times FontInfo/extent')
    if native:
        log=native.read_text()
        if native_status!=0 or any(x in log for x in ('FAIL','Error in','DIAG / GDB TIMEOUT','Program received signal')) or log.count('[Inferior 1 (Remote target) detached]')!=1 or log.count('PASS native original '+(label+' ' if dot or accent else '')+'DrawText stack/register contract')!=1:raise ValueError('native completion')
        if tag+'_NATIVE_BYTES 548F3E80A885' not in log or tag+f'_ARGUMENTS count={len(text)} first=0' not in log:raise ValueError('native call identity')
        if (ROOT/'tmp'/f'{prefix}-native-string.bin').read_bytes()!=text:raise ValueError('native string')
        before=read('native','enter','port');after=read('native','return','port');expected=bytearray(before)
        struct.pack_into('>H',expected,14,ends[0][1]);struct.pack_into('>H',expected,50,ends[0][0])
        if after!=expected or word(before,14)!=0x8000 or word(before,50)!=x or word(before,48)!=y:raise ValueError('native pen/preserved port')
        for kind in ('pm','vis','clip','clut'):
            if read('native','enter',kind)!=read('native','return',kind):raise ValueError('native changed '+kind)
        for off,size in ((14,2),(16,8),(48,4),(68,20)):
            if before[off:off+size]!=read('reference','enter','port')[off:off+size]:raise ValueError('paired text state')
        native_before=read('native','enter','pixels');reference_before=read('reference','enter','pixels')
        if not (dot or accent) and any(native_before[y*652:y*652+648]!=reference_before[y*652:y*652+648] for y in range(401)):raise ValueError('paired initial pixel columns')
        if accent:
            # Earlier credit lines use the same owned font. Their text boxes
            # cover the paired reference captions plus the owned glyph ascent.
            # The two-column margin covers separate word placement/ink bearings.
            areas=((48,30,131,46),(99,54,213,70),(48,78,164,94))
            for row in range(401):
                for col in range(648):
                    n,r=native_before[row*652+col],reference_before[row*652+col]
                    if n!=r and (26 not in (n,r) or not any(l<=col<rr and t<=row<b for l,t,rr,b in areas)):
                        raise ValueError('paired initial pixels outside prior credit ink')
        if dot:
            # The preceding 'Published by' line uses owned glyphs too. Outside
            # its measured ink bounds the full visible input buffer must match.
            for row in range(401):
                for col in range(648):
                    n,r=native_before[row*652+col],reference_before[row*652+col]
                    if n!=r and (not (119<=col<189 and 70<=row<85) or 26 not in (n,r)):
                        raise ValueError('paired initial pixels outside prior placeholder ink')
        if dot and 'PASS native Times FontInfo ascent=12 descent=4 maximum=15 leading=0' not in log:raise ValueError('native Times FontInfo')
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
                for row in range(10):
                    for col in range(width):
                        px=x+position//65536+col;py=y-10+row
                        if shape[row*7//10]&(16>>(lo+col*(hi-lo)//width)) and all(t<=py<b and l<=px<r for t,l,b,r in limits):expected[py*652+px]=26
            position=end
        if read('native','return','pixels')!=expected:raise ValueError('native full-buffer stencil/preservation')
        print('PASS native DrawText: original string/ABI/pen/colour, full-buffer owned glyph stencil and preservation')
    print('PASS original DrawText: fractional accumulation, repeated draw, MoveTo reset, empty draw, ABI and preserved metadata')
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('reference',type=Path);p.add_argument('--status',required=True,type=int);p.add_argument('--native',type=Path);p.add_argument('--native-status',type=int);p.add_argument('--dot',action='store_true');p.add_argument('--accent',action='store_true');a=p.parse_args()
    try:check(a.reference.read_text(),a.status,a.native,a.native_status,a.dot,a.accent)
    except (ValueError,OSError,KeyError,TypeError) as e:raise SystemExit('FAIL DrawText: '+str(e))
