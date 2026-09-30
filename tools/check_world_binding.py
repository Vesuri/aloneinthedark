#!/usr/bin/env python3
"""Compare the original screen-backed SetGWorld binding and native return ABI."""
import argparse
import hashlib
from pathlib import Path
import struct
from check_choice_services import one
from check_getgworld import fields
from resource_fork import read_resource_fork


def require(ok,message):
    if not ok:
        raise ValueError(message)


def check(reference,native,reference_status,native_status,folder,resource,background=False):
    segment,start,end=(9,0xdfe,0xe0c) if background else (7,0x1276,0x1288)
    code=next(r.body for r in read_resource_fork(resource) if r.kind==b'CODE' and r.rid==segment)[start:end]
    expected=bytes.fromhex('2f2c000842a7203c00080006ab1d') if background else None
    require(code==expected if background else hashlib.sha256(code).hexdigest()=='6cc93f9eb31462a18a6460396cd3b737ec91052179d1062dee0bf78c309f0fb9','original binding instructions')
    prefix='worldrestore' if background else 'worldbind'
    for side,text,status in [('reference',reference,reference_status),('native',native,native_status)]:
        require(status==0 and all(s not in text for s in ('FAIL','Error in','LUA ERROR','TIMEOUT','Program received signal')),side+' run')
        marker='PASS original world binding' if side=='reference' else ('PASS native world restoration\n' if background else 'PASS native world binding\n')
        ending='Exited via the debugger' if side=='reference' else '[Inferior 1 (Remote target) detached]'
        require(text.count(marker)==text.count(ending)==1,side+' normal completion')
        require(bytes.fromhex(one(text,r'WB_BYTES data=([0-9A-F]+)'))==code,side+' live original instructions')
        e=fields(one(text,r'WB_ENTER (.*)'));r=fields(one(text,r'WB_RETURN (.*)'))
        before=fields(one(text,r'WB_STATE phase=before (.*)'));after=fields(one(text,r'WB_STATE phase=after (.*)'))
        require(e['device']==0 and e['window']!=0 and e['d0']==0x80006,side+' measured arguments')
        require(r['sp']==e['sp']+8 and r['d0']==0x8c000 and r['a0']==e['window'] and r['a1']==before['main'],side+' return ABI')
        require(all(e[k]==r[k] for k in ['d1','d2','d3','d4','d5','d6','d7','a2','a3','a4','a5','a6']),side+' preserved registers')
        require(before['port'] and before['port']!=e['window'] and before['main']==before['device'],side+' initial world')
        require(after==dict(before,port=e['window']),side+' sole binding change')
        for name,size in [('window',156),('pm',50),('device',62),('pixels',307200)]:
            a=(folder/f'{prefix}-{side}-before-{name}.bin').read_bytes()
            b=(folder/f'{prefix}-{side}-after-{name}.bin').read_bytes()
            require(len(a)==size and a==b,side+' unchanged '+name)
            if name=='window':
                require(a[6:8]==bytes.fromhex('c000') and a[110]==1 and struct.unpack_from('>4h',a,16)==((0,0,16000,16000) if background else (0,0,200,320)),side+' visible colour port')
            elif name=='pm':
                require(struct.unpack_from('>4h',a,6)==((8000,8000,8480,8640) if background else (-150,-160,330,480)) and a[32:34]==bytes.fromhex('0008'),side+' screen-backed coordinates')
            elif name=='pixels':
                # Positive control: MAME's generic debugger save can read the
                # wrong address space for video. Require the real cleared client.
                nonblack=sum(a[y*640+x]!=255 for y in range(150,350) for x in range(160,480))
                require(nonblack==((56 if background else 43) if side=='reference' else 0),side+' actual client pixels')
                if background and side=='reference':
                    # This later Mac capture has a clock-shaped cursor rather
                    # than the earlier arrow. Validate its exact footprint.
                    mask=('.######...','####.###..','####.###..','####.###.#',
                          '##...###.#','########..','########..','.######...')
                    for y,row in enumerate(mask,267):
                        for x,bit in enumerate(row,252):
                            require(a[y*640+x]==(0 if bit=='#' else 255),'reference cursor footprint')
    before=fields(one(native,r'WB_NATIVE phase=before (.*)'));after=fields(one(native,r'WB_NATIVE phase=after (.*)'))
    require(before==after and before['queued']==1 and before['dirty']==0 and (background or before['seed']==4),'unchanged native presentation/palette state')
    require((folder/f'{prefix}-native-before-clut.bin').read_bytes()==(folder/f'{prefix}-native-after-clut.bin').read_bytes(),'unchanged native CLUT')
    if background:
        from check_native_driver import check as check_startup
        check_startup(native,native_status)
        print('PASS paired background SetGWorld: original bytes, real visible nonfront window, binding/ABI and unchanged records/pixels/palette')
        return
    require(native.count('PASS native world binding next-stop original-MDRV=absent')==1,'progression and driver guard')
    print('PASS paired SetGWorld: original bytes, nil-device selection, colour-port binding, return registers and unchanged pixels; '+one(native,r'WB_NEXT (state=3 trap=A0F8 selector=11 segment=3 offset=17FC manager=SOUND DRIVER routine=SELECTOR windows=(?:135|161) services=(?:480/479|488/487))'))


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('reference',type=Path);p.add_argument('native',type=Path)
    p.add_argument('--reference-status',type=int,required=True);p.add_argument('--native-status',type=int,required=True)
    p.add_argument('--folder',type=Path,default=Path('tmp'));p.add_argument('--resource',type=Path,default=Path('tmp/runtime-data/Alone In The Dark'))
    p.add_argument('--background',action='store_true')
    a=p.parse_args();check(a.reference.read_text(),a.native.read_text(),a.reference_status,a.native_status,a.folder,a.resource,a.background)
