#!/usr/bin/env python3
"""Independent PackBits/colour oracle for the original image-preparation capture."""
import argparse,re,struct
from pathlib import Path
from resource_fork import read_resource_fork
ROOT=Path(__file__).resolve().parents[1]
def word(data,at):return struct.unpack_from('>H',data,at)[0]
def rect(data,at):return struct.unpack_from('>4h',data,at)
def unpack(data,count):
    out=bytearray();at=0
    while at<len(data):
        control=data[at];at+=1
        if control<128:
            n=control+1
            if at+n>len(data):raise ValueError('truncated PackBits literal')
            out+=data[at:at+n];at+=n
        elif control>128:
            if at==len(data):raise ValueError('truncated PackBits run')
            out+=bytes([data[at]])*(257-control);at+=1
        if len(out)>count:raise ValueError('PackBits row overflow')
    if len(out)!=count:raise ValueError('PackBits row length')
    return out

def decode(picture):
    frame=rect(picture,2);at=10;image=None;clip=None
    while at+2<=len(picture):
        op=word(picture,at);at+=2
        if op==0xff:
            if at!=len(picture) or image is None:raise ValueError('picture end')
            return frame,clip,image
        if op in (0,0x1e):continue
        if op==0x11:
            if word(picture,at)!=0x2ff:raise ValueError('picture version')
            at+=2;continue
        if op==0xc00:
            if at+24>len(picture):raise ValueError('picture header')
            at+=24;continue
        if op==1:
            if word(picture,at)!=10:raise ValueError('nonrectangular picture clip')
            clip=rect(picture,at+2);at+=10;continue
        if op!=0x98 or image is not None:raise ValueError(f'unmeasured PICT opcode {op:04x}')
        row=word(picture,at)&0x3fff;bounds=rect(picture,at+2)
        if not word(picture,at)&0x8000 or word(picture,at+12)!=0 or tuple(word(picture,at+i) for i in (26,28,30,32))!=(0,8,1,8):raise ValueError('indexed bitmap layout')
        at+=46
        if word(picture,at+4)!=0x8000 or word(picture,at+6)!=255:raise ValueError('picture palette layout')
        table=picture[at:at+2056];at+=2056
        source,destination=rect(picture,at),rect(picture,at+8)
        if word(picture,at+16)!=0 or source!=bounds or destination!=frame:raise ValueError('original srcCopy rectangles')
        at+=18;rows=[]
        for y in range(bounds[2]-bounds[0]):
            length=word(picture,at) if row>250 else picture[at];at+=2 if row>250 else 1
            if at+length>len(picture):raise ValueError('truncated packed row')
            rows.append(unpack(picture[at:at+length],row));at+=length
        at+=(at&1);image=(bounds,table,rows)
    raise ValueError('missing picture end')

def color_index(rgb,table,inverse):
    cell=((rgb[0]>>12)<<8)|((rgb[1]>>12)<<4)|(rgb[2]>>12)
    first=inverse[6+cell];current=first;best=first;distance=196606
    for _ in range(256):
        color=struct.unpack_from('>3H',table,10+current*8)
        d=sum(abs(x-y) for x,y in zip(rgb,color))
        if d<distance:distance=d;best=current
        current=inverse[4108+current]
        if current==first:return best
    raise ValueError('invalid inverse collision ring')

def check(log,status,native=False):
    if status!=0 or any(s in log for s in ('FAIL','LUA ERROR','timeout','Error in breakpoint')):raise ValueError('reference completion')
    if log.count('PASS original eight-bit picture preparation calls=20')!=1 or (not native and log.count('Exited via the debugger')!=1):raise ValueError('positive terminal controls')
    if native:
        from check_native_driver import check as check_startup
        check_startup(log,status)
    source=read_resource_fork(ROOT/'tmp/runtime-data/Alone In The Dark')
    code=next(r.body for r in source if r.kind==b'CODE' and r.rid==13)
    expected=bytes.fromhex('2f0b486efff8a8f6')
    if code[0x37c:0x384]!=expected or re.findall(r'^PICT8_BYTES data=([0-9A-F]+)$',log,re.M)!=[expected.hex().upper()]:raise ValueError('original/live caller bytes')
    table=(ROOT/'tmp/pict8-reference-clut.bin').read_bytes();inverse=(ROOT/'tmp/pict8-reference-inverse.bin').read_bytes()
    lines=[s for s in log.splitlines() if s.startswith(('PICT8_ENTER ','PICT8_RETURN '))]
    if len(lines)!=40:raise ValueError('original draw count')
    checked=0
    for n in range(1,21):
        rows=lines[(n-1)*2:n*2]
        if not rows[0].startswith('PICT8_ENTER ') or not rows[1].startswith('PICT8_RETURN '):raise ValueError('call order')
        e,r=[dict(re.findall(r'(\w+)=([^ ]+)',line)) for line in rows]
        if any(int(d['n'])!=n for d in (e,r)) or int(r['sp'],16)!=int(e['sp'],16)+8:raise ValueError('call index/stack')
        for reg in [f'd{i}' for i in range(8)]+[f'a{i}' for i in range(7)]:
            if e[reg]!=r[reg]:raise ValueError('preserved register '+reg)
        def data(phase,kind):
            platform='native' if native else 'reference'
            return (ROOT/f'tmp/pict8-{platform}-{n}-{phase}-{kind}.bin').read_bytes()
        picture=data('enter','picture')
        if picture!=next(v.body for v in source if v.kind==b'PICT' and v.rid==9999+n):raise ValueError('original picture body')
        for kind in ('port','pm','vis','clip','picture'):
            if data('enter',kind)!=data('return',kind):raise ValueError('drawing record mutation '+kind)
        frame,clip,(bounds,palette,pixels)=decode(picture);target=struct.unpack('>4h',bytes.fromhex(e['rect']))
        if clip!=frame or (target[2]-target[0],target[3]-target[1])!=(frame[2]-frame[0],frame[3]-frame[1]):raise ValueError('original clip/unscaled route')
        pm=data('enter','pm');stride=word(pm,4)&0x3fff;mapBounds=rect(pm,6)
        before=data('enter','pixels');expected=bytearray(before)
        mapping=[color_index(struct.unpack_from('>3H',palette,10+i*8),table,inverse) for i in range(256)]
        for y,row in enumerate(pixels):
            at=(target[0]+y-mapBounds[0])*stride+target[1]-mapBounds[1]
            width=bounds[3]-bounds[1];expected[at:at+width]=bytes(mapping[v] for v in row[:width])
        if data('return','pixels')!=expected:raise ValueError(f'picture {9999+n} pixels or untouched padding')
        checked+=len(expected)
    return f'PASS original picture preparation: 20 byte-guarded indexed PackBits draws; {checked} destination bytes, RGB palette mapping, untouched pixels/padding and restored records/ABI'

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('log',type=Path);p.add_argument('--status',type=int,required=True);p.add_argument('--native',action='store_true');a=p.parse_args()
    try:print(check(a.log.read_text(),a.status,a.native))
    except (ValueError,OSError,KeyError,struct.error,IndexError) as error:raise SystemExit('FAIL picture8: '+str(error))
