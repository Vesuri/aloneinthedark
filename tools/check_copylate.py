#!/usr/bin/env python3
"""Original-call and independent full-buffer acceptance for later intro CopyBits."""
import argparse, re, struct, os, subprocess
import local_temp as tempfile
from pathlib import Path
from resource_fork import read_resource_fork
ROOT=Path(__file__).resolve().parents[1]
def word(b,n):return struct.unpack_from('>H',b,n)[0]
def rect(b,n=0):return struct.unpack_from('>4h',b,n)
def data(machine,phase,name):return (ROOT/'tmp'/f'copylate-{machine}-{phase}-{name}.bin').read_bytes()
def check(text,status,native=False):
    marker='PASS native later intro CopyBits' if native else 'PASS original later intro CopyBits'
    end='[Inferior 1 (Remote target) detached]' if native else 'Exited via the debugger'
    if status!=0 or text.count(marker)!=1 or text.count(end)!=1 or any(x in text for x in ('FAIL','Error in','LUA ERROR','timeout')):raise ValueError('completion')
    code=next(r.body for r in read_resource_fork(ROOT/'tmp/runtime-data/Alone In The Dark') if r.kind==b'CODE' and r.rid==4)
    raw=code[0x1da8:0x1dbe]
    if raw.hex()!='486c0002486b0002486efff8486efff8426742a7a8ec' or re.findall(r'^COPYLATE_BYTES (\w+)$',text,re.M)!=[raw.hex().upper()]:raise ValueError('original/live caller')
    entries=[re.findall(r'^COPYLATE_'+phase+r' (.*)$',text,re.M) for phase in ('ENTER','RETURN')]
    if any(len(x)!=1 for x in entries):raise ValueError('call count')
    e,r=[dict(re.findall(r'(\w+)=([^ ]+)',x[0])) for x in entries]
    if int(r['sp'],16)!=int(e['sp'],16)+22 or int(r['d0'],16)!=0:raise ValueError('return/stack')
    for key in [f'd{i}' for i in range(2,8)]+[f'a{i}' for i in range(2,7)]:
        if e[key]!=r[key]:raise ValueError('preserved '+key)
    if native:
        args=re.findall(r'^COPYLATE_ARGS mask=0 mode=0 destination=(\w+) expected=(\w+)$',text,re.M)
        if len(args)!=1 or args[0][0]!=args[0][1]:raise ValueError('native call form')
    else:
        args=bytes.fromhex(e['args'])
        if args[:6]!=bytes(6) or int.from_bytes(args[14:18],'big')!=int(e['port'],16)+2:raise ValueError('reference call form')
    fromRect=rect(bytes.fromhex(e['source']));toRect=rect(bytes.fromhex(e['target']))
    if fromRect!=(0,0,201,321) or toRect!=fromRect:raise ValueError('original rectangles')
    machine='native' if native else 'reference'
    for n in ('src-pm','dst-pm','src-clut','dst-clut','src-pixels','port','vis','clip'):
        if data(machine,'enter',n)!=data(machine,'return',n):raise ValueError('unchanged '+n)
    sp=data(machine,'enter','src-pm');dp=data(machine,'enter','dst-pm')
    src=data(machine,'enter','src-pixels');before=data(machine,'enter','dst-pixels');after=data(machine,'return','dst-pixels')
    sr=word(sp,4)&0x3fff;dr=word(dp,4)&0x3fff;st,sl,sb,sright=rect(sp,6);dt,dl,db,dright=rect(dp,6)
    if word(sp,32)!=8 or word(dp,32)!=8 or len(src)!=sr*(sb-st) or len(before)!=dr*(db-dt) or len(after)!=len(before):raise ValueError('pixel storage')
    sct=data(machine,'enter','src-clut');dct=data(machine,'enter','dst-clut')
    if len(sct)!=2056 or len(dct)!=2056 or sct[:4]==dct[:4]:raise ValueError('distinct colour environments')
    with tempfile.TemporaryDirectory(prefix='aitd-copy-colour-') as work:
        exe=Path(work)/'map'
        subprocess.run([os.environ.get('HOST_CXX','c++'),'-std=c++17','-Wall','-Wextra','-Werror','-fsanitize=address,undefined',str(ROOT/'tools/test_copybits_color.cpp'),'-o',str(exe)],check=True)
        mapping=list(map(int,subprocess.check_output([str(exe),str(ROOT/'tmp'/f'copylate-{machine}-enter-src-clut.bin'),str(ROOT/'tmp'/f'copylate-{machine}-enter-dst-clut.bin'),str(ROOT/'tmp'/f'copylate-{machine}-return-inverse.bin')],text=True,timeout=30).split()))
    if len(mapping)!=256:raise ValueError('colour mapping size')
    bounds=[rect(dp,6),rect(data(machine,'enter','port'),16),rect(data(machine,'enter','vis'),2),rect(data(machine,'enter','clip'),2)]
    expected=bytearray(before)
    for y in range(toRect[0],toRect[2]):
        for x in range(toRect[1],toRect[3]):
            sy=fromRect[0]+y-toRect[0];sx=fromRect[1]+x-toRect[1]
            if st<=sy<sb and sl<=sx<sright and all(t<=y<b and l<=x<r for t,l,b,r in bounds):expected[(y-dt)*dr+x-dl]=mapping[src[(sy-st)*sr+sx-sl]]
    if after!=expected:raise ValueError('independent complete destination comparison')
    if not native and data(machine,'enter','inverse')!=data(machine,'return','inverse'):raise ValueError('original inverse table changed')
    if native:
        from check_native_driver import check as startup
        startup(text,status)
        ref=data('reference','return','dst-pixels')
        # The Mac's four padding bytes per source row are allocator contents.
        # They are preserved on each platform, excluded from the pixel bounds.
        # Visible glyphs and every copied client pixel must match the Mac.
        reference_source=data('reference','enter','src-pixels')
        if sct[4:]!=data('reference','enter','src-clut')[4:] or dct[4:]!=data('reference','enter','dst-clut')[4:]:raise ValueError('paired colour tables')
        for y in range(401):
            for x in range(648):
                if src[y*652+x]!=reference_source[y*652+x]:raise ValueError('unexplained paired source pixel difference')
        for y in range(200):
            for x in range(320):
                at=(y+150)*640+x+160
                if after[at]!=ref[at]:raise ValueError('paired client pixel difference')
    print('PASS later intro CopyBits: original bytes/ABI, inverse-table colour remapping, complete source/destination buffers and unchanged records')
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('log',type=Path);p.add_argument('--status',type=int,required=True);p.add_argument('--native',action='store_true');a=p.parse_args()
    try:check(a.log.read_text(),a.status,a.native)
    except (ValueError,OSError,KeyError) as e:raise SystemExit('FAIL later intro CopyBits: '+str(e))
