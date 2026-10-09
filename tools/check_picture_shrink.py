#!/usr/bin/env python3
"""Compare the compiled indexed preview shrink with the unmodified Mac's full draw."""
import argparse
import os
from pathlib import Path
import re
import struct
import subprocess
import local_temp as tempfile
from check_picture8 import unpack
from check_video_transfer import native as transfer_table
from resource_fork import read_resource_fork
ROOT=Path(__file__).resolve().parents[1]

def require(ok,message):
    if not ok:raise ValueError(message)

def check(folder,log,status,resource,native_screen=None,native_clut=None):
    require(status==0 and log.count('PASS original saved-preview DrawPicture return')==1
            and log.count('Exited via the debugger')==1 and not re.search(r'FAIL|LUA ERROR|Error in breakpoint',log),
            'original normal drawing return')
    require('PREVIEW_ENTER return=4553AA rect=33,36,87,124 size=55492 stride=652' in log
            and log.count('PREVIEW_RETURN pc=4553AA')==1,'actual preview call and return')
    picture=(folder/'source-picture.bin').read_bytes()
    expected=next(r.body for r in read_resource_fork(resource) if r.kind==b'PICT' and r.rid==128)
    require(picture==expected,'unmodified actual saved picture')
    require(picture[54:66]==bytes.fromhex('81480000000000c801470000')
            and struct.unpack_from('>4h',picture,2156)==(0,0,200,320)
            and struct.unpack_from('>4h',picture,2164)==(0,0,70,100)
            and struct.unpack_from('>H',picture,2172)[0]==64,'measured source raster and ditherCopy')
    require((folder/'source-pm.bin').read_bytes()==(folder/'source-return-pm.bin').read_bytes(),
            'unchanged destination PixMap')
    rows=[];at=2174
    for _ in range(200):
        n=struct.unpack_from('>H',picture,at)[0];at+=2
        rows.append(unpack(picture[at:at+n],328));at+=n
    require(at==55490 and picture[at:]==bytes.fromhex('00ff'),'complete original packed raster')
    before=(folder/'source-before.bin').read_bytes();after=(folder/'source-after.bin').read_bytes()
    changed=[i for i,(a,b) in enumerate(zip(before,after)) if a!=b]
    require(len(changed)==4752 and all(33<=i//652<87 and 36<=i%652<124 for i in changed),
            'exact original preview drawing footprint')
    expected=b''.join(after[(y+33)*652+36:(y+33)*652+124] for y in range(54))
    device=(folder/'source-dither-colors.bin').read_bytes();cube=(folder/'source-dither-inverse.bin').read_bytes()
    require(device==(folder/'source-colors.bin').read_bytes() and len(cube)==4096,'actual logical destination dither palette and cube')
    inverse=device[:4]+bytes.fromhex('0004')+cube+bytes(518)
    require(len(device)==2056 and len(inverse)==4620,'complete actual dither colour environment')
    request=struct.pack('>5H',328,320,200,88,54)+b''.join(rows)+picture[100:2156]+device+inverse
    with tempfile.TemporaryDirectory(prefix='aitd-picture-shrink-') as temp:
        exe=Path(temp)/'check'
        subprocess.run([os.environ.get('HOST_CXX','c++'),'-std=c++17','-Wall','-Wextra','-Werror',
                        '-fsanitize=address,undefined',str(ROOT/'tools/test_picture_shrink.cpp'),'-o',str(exe)],check=True)
        actual=subprocess.run([str(exe)],input=request,stdout=subprocess.PIPE,check=True,timeout=30).stdout
        require(actual==expected,'compiled helper differs from original preview pixels')
        # Unknown integral/overlapping layouts must remain rejected.
        for dims in ((328,320,200,200,54),(328,320,200,88,50)):
            rejected=subprocess.run([str(exe)],input=struct.pack('>5H',*dims)+request[10:],stdout=subprocess.PIPE,timeout=30)
            require(rejected.returncode==4 and not rejected.stdout,'unsupported layout rejection')
    print('PASS original/compiled preview: all 4752 pixels, logical destination cube and owned workspace')
    if native_screen is not None:
        require(native_clut is not None,'native palette required')
        screen=native_screen.read_bytes();clut=native_clut.read_bytes()
        require(len(screen)==307200 and len(clut)==2056,'complete native display and palette')
        transfer=transfer_table();rgb=(folder/'ordinary-firstfloor-load-choice-rgb.bin').read_bytes()
        require(len(rgb)==640*480*4,'complete original visible Load choice')
        palette=[tuple(transfer[v] for v in struct.unpack_from('>3H',clut,10+i*8)) for i in range(256)]
        bad=0
        for y in range(183,237):
            for x in range(196,284):
                pen=screen[y*640+x];color=struct.unpack_from('<I',rgb,4*(y*640+x))[0]&0xffffff
                expected_color=palette[pen][0]<<16|palette[pen][1]<<8|palette[pen][2]
                bad+=color!=expected_color
        require(bad==0,f'visible native saved preview differs at {bad} pixels')
        print('PASS native saved preview: all 4752 visible pixels through verified display transfer')

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('log',type=Path);p.add_argument('--folder',type=Path,required=True)
    p.add_argument('--resource',type=Path,required=True);p.add_argument('--status',type=int,required=True)
    p.add_argument('--native-screen',type=Path);p.add_argument('--native-clut',type=Path)
    a=p.parse_args()
    try:check(a.folder,a.log.read_text(),a.status,a.resource,a.native_screen,a.native_clut)
    except (ValueError,OSError,StopIteration) as e:raise SystemExit('FAIL picture shrink: '+str(e))
