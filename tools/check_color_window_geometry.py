#!/usr/bin/env python3
"""Check initial colour-window geometry against original WIND bounds."""
import argparse
from pathlib import Path
import re
import struct
from check_getgworld import fields
from resource_fork import read_resource_fork


def require(ok,message):
    if not ok:
        raise ValueError(message)


def check(text,status,folder,resource,native=False):
    side='native' if native else 'reference'
    require(status == 0 and not re.search(r'FAIL|Error in|LUA ERROR|timeout|Protocol error',text,re.I),side+' run')
    marker='PASS native colour-window geometry capture calls=2' if native else 'PASS original colour-window geometry calls=2'
    require(text.count(marker)==1 and ('[Inferior 1 (Remote target) detached]' if native else 'Exited via the debugger') in text,side+' completion')
    rows=read_resource_fork(resource)
    code=next(r.body for r in rows if r.kind==b'CODE' and r.rid==9)
    entered=[fields(s) for s in re.findall(r'^GEOM_ENTER (.*)$',text,re.M)]
    returned=[fields(s) for s in re.findall(r'^GEOM_RETURN (.*)$',text,re.M)]
    require(len(entered)==len(returned)==2,'both original constructors')
    previous=0;pixmaps=[];pixels=[]
    for (rid,site),e,r in zip([(131,0x1272),(128,0x109a)],entered,returned):
        require(code[site:site+2]==bytes.fromhex('aa46') and e==dict(id=rid,site=site,opcode=0xaa46,sp=e['sp'],behind=0xffffffff,storage=0,result=0),'original constructor arguments/site')
        require(r['id']==rid and r['sp']==r['expected']==e['sp']+10 and r['window']!=0 and r['next']==previous,'constructor return and chain')
        require(r['kind']==8 and r['visible']==0,side+' hidden user-window kind')
        window=(folder/f'window-geometry-{side}-{rid}-window.bin').read_bytes()
        pm=(folder/f'window-geometry-{side}-{rid}-pm.bin').read_bytes()
        require(len(window)==156 and len(pm)==50,'record extents')
        wind=next(row.body for row in rows if row.kind==b'WIND' and row.rid==rid)
        top,left,bottom,right=struct.unpack_from('>4h',wind)
        require(struct.unpack_from('>4h',window,16)==(0,0,bottom-top,right-left),side+' local port rectangle')
        require(struct.unpack_from('>4h',pm,6)==(-top,-left,480-top,640-left),side+' translated PixMap bounds')
        require(struct.unpack_from('>H',window,6)[0]==0xc000 and struct.unpack_from('>H',pm,4)[0]==0x8280 and struct.unpack_from('>H',pm,32)[0]==8,'eight-bit colour port/view')
        handles=[]
        for name,offset in [('visibility',24),('clip',28),('structure',114),('content',118),('update',122)]:
            handles.append(struct.unpack_from('>I',window,offset)[0])
            region=(folder/f'window-geometry-{side}-{rid}-{name}.bin').read_bytes()
            expected=bytes.fromhex('000a800180017fff7fff') if name=='clip' else bytes.fromhex('000a0000000000000000')
            require(region==expected,side+' initial '+name+' region')
        require(len(set(handles))==5 and all(handles),side+' independent region handles')
        previous=r['window'];pixmaps.append(r['pm']);pixels.append(struct.unpack_from('>I',pm)[0])
    require(len(set(pixmaps))==2 and all(pixmaps),'independent per-window PixMaps')
    require(pixels[0]==pixels[1] and pixels[0]!=0,'shared screen pixels')
    print('PASS '+side+' colour-window geometry: original calls, local port rectangles, translated independent PixMaps, hidden regions and chain')


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('log',type=Path)
    p.add_argument('--status',type=int,required=True)
    p.add_argument('--native',action='store_true')
    p.add_argument('--folder',type=Path,default=Path('tmp'))
    p.add_argument('--resource',type=Path,default=Path('tmp/runtime-data/Alone In The Dark'))
    a=p.parse_args()
    check(a.log.read_text(),a.status,a.folder,a.resource,a.native)
