#!/usr/bin/env python3
"""Verify the measured reuse of an inactive, already-realized palette."""
import argparse
import os
from pathlib import Path
import re
import struct
import subprocess
import local_temp as tempfile
from resource_fork import read_resource_fork

ROOT = Path(__file__).resolve().parents[1]


def check(path, status, helper=False, native=None, native_status=None):
    text=path.read_text()
    if status != 0 or re.search(r'FAIL|LUA ERROR|TIMEOUT',text) or text.count('PASS original reactivated presentation palette')!=1 or text.count('Exited via the debugger')!=1:
        raise ValueError('original completion')
    data=lambda phase,kind:(ROOT/'tmp'/f'rebind-reference-{phase}-{kind}.bin').read_bytes()
    a,b=data('enter','palette'),data('return','palette')
    if len(a)!=4112 or len(b)!=4112 or struct.unpack_from('>II',a,4)!=(0xc003,0) or struct.unpack_from('>II',b,4)!=(0xc003,1):
        raise ValueError('realized inactive-to-active state')
    expected=bytearray(a);struct.pack_into('>I',expected,8,1)
    if b!=expected:raise ValueError('palette changes beyond active state')
    for kind in ('old','old-private'):
        if data('enter',kind)!=data('return',kind):raise ValueError('default palette preservation')
    if data('return','private')!=data('return','clut')[:4] or data('enter','private')==data('return','private'):
        raise ValueError('renewed private/device seed')
    a,b=data('enter','pixels'),data('return','pixels')
    if len(a)!=307200 or len(b)!=307200 or any(a[y*640+160:y*640+480]!=b[y*640+160:y*640+480] for y in range(150,350)):
        raise ValueError('client pixel preservation')
    if helper:
        with tempfile.TemporaryDirectory(prefix='aitd-rebind-') as work:
            exe=Path(work)/'test'
            subprocess.run([os.environ.get('HOST_CXX','c++'),'-std=c++17','-Wall','-Wextra','-Werror','-fsanitize=address,undefined',str(ROOT/'tools/test_palette8.cpp'),'-o',str(exe)],check=True)
            subprocess.run([str(exe),'--rebind',str(ROOT/'tmp')],check=True,timeout=30)
    if native:
        log=native.read_text()
        if native_status!=0 or re.search(r'FAIL|Error in|TIMEOUT|Program received signal',log) or log.count('PASS native palette reactivation ABI')!=1 or log.count('[Inferior 1 (Remote target) detached]')!=1:
            raise ValueError('native completion/ABI')
        callers=re.findall(r'^REBIND_NATIVE_BYTES ([0-9A-F]+) a5=([0-9A-F]+)$',log,re.M)
        code=next(r.body for r in read_resource_fork(ROOT/'tmp/runtime-data/Alone In The Dark') if r.kind==b'CODE' and r.rid==5)
        raw=code[0x20c0:0x20ce]
        if len(callers)!=1 or raw.hex()!='2f002f39ffff4d601f3c0001aa95':
            raise ValueError('original SetPalette caller')
        value,a5=callers[0]
        if bytes.fromhex(value)!=raw[:4]+struct.pack('>I',(int(a5,16)-0xb2a0)&0xffffffff)+raw[8:]:
            raise ValueError('native original caller/A5 relocation')
        nd=lambda phase,kind:(ROOT/'tmp'/f'rebind-native-{phase}-{kind}.bin').read_bytes()
        states=re.findall(r'^REBIND_NATIVE_STATE phase=(enter|return) window=([0-9A-F]+) palette=([0-9A-F]+) default=([0-9A-F]+) binding=([0-9A-F]+) active=([0-9A-F]+) updates=(\d+) screenDirty=(\d+) pixelDirty=(\d+) rects=(\d+)$',log,re.M)
        if len(states)!=2 or [r[0] for r in states]!=['enter','return']:
            raise ValueError('native binding records')
        enter,end=states
        if enter[1:4]!=end[1:4] or enter[4]!=enter[3] or enter[5]!=enter[3] or end[4]!=enter[2] or end[5]!=enter[2] or end[6:8]!=('1','1') or end[8:]!=('0','0'):
            raise ValueError('native association/pixel preservation')
        for phase in ('enter','return'):
            p,q=nd(phase,'palette'),data(phase,'palette')
            if p[:12]+p[16:]!=q[:12]+q[16:] or nd(phase,'clut')[4:]!=data(phase,'clut')[4:]:
                raise ValueError('paired native palette/device state '+phase)
        for kind,size in (('window',156),('windowpm',50),('gd',62),('pm',50),('old',4112),('old-private',4),('pixels',307200)):
            if len(nd('enter',kind))!=size:raise ValueError('native capture extent '+kind)
            if nd('enter',kind)!=nd('return',kind):raise ValueError('native preserved '+kind)
        if nd('return','private')!=nd('return','clut')[:4] or nd('enter','private')==nd('return','private'):
            raise ValueError('native new private/device seed')
    print('PASS original palette reactivation: active state, complete CLUT/private seed, default palette and client preservation')


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('log',type=Path);parser.add_argument('--status',type=int,required=True)
    parser.add_argument('--helper',action='store_true')
    parser.add_argument('--native',type=Path);parser.add_argument('--native-status',type=int)
    args=parser.parse_args()
    try:check(args.log,args.status,args.helper,args.native,args.native_status)
    except (ValueError,OSError) as error:raise SystemExit('FAIL palette reactivation: '+str(error))
