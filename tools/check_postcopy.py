#!/usr/bin/env python3
"""Original-call and independent full-buffer acceptance for post-intro CopyBits."""
import argparse, re, struct, os, subprocess
import local_temp as tempfile
from pathlib import Path
from resource_fork import read_resource_fork
ROOT=Path(__file__).resolve().parents[1]
def word(b,n):return struct.unpack_from('>H',b,n)[0]
def rect(b,n=0):return struct.unpack_from('>4h',b,n)
def data(machine,phase,name):return (ROOT/'tmp'/f'postcopy-{machine}-{phase}-{name}.bin').read_bytes()
def check(text,status,native=False):
    marker='PASS native post-intro CopyBits' if native else 'PASS original post-intro CopyBits'
    end='[Inferior 1 (Remote target) detached]' if native else 'Exited via the debugger'
    if status!=0 or text.count(marker)!=1 or text.count(end)!=1 or any(x in text for x in ('FAIL','Error in','LUA ERROR','timeout')):raise ValueError('completion')
    code=next(r.body for r in read_resource_fork(ROOT/'tmp/runtime-data/Alone In The Dark') if r.kind==b'CODE' and r.rid==13)
    raw=code[0x7e8:0x7fc]
    if raw.hex()!='486800022f0c2f2e0008486efff8426742a7a8ec' or re.findall(r'^POSTCOPY_BYTES (\w+)$',text,re.M)!=[raw.hex().upper()]:raise ValueError('original/live caller')
    entries=[re.findall(r'^POSTCOPY_'+phase+r' (.*)$',text,re.M) for phase in ('ENTER','RETURN')]
    if any(len(x)!=1 for x in entries):raise ValueError('call count')
    e,r=[dict(re.findall(r'(\w+)=([^ ]+)',x[0])) for x in entries]
    if int(r['sp'],16)!=int(e['sp'],16)+22 or int(r['d0'],16)!=0:raise ValueError('return/stack')
    for key in [f'd{i}' for i in range(2,8)]+[f'a{i}' for i in range(2,7)]:
        if e[key]!=r[key]:raise ValueError('preserved '+key)
    if native:
        args=re.findall(r'^POSTCOPY_ARGS mask=0 mode=0 destination=(\w+) expected=(\w+)$',text,re.M)
        if len(args)!=1 or args[0][0]!=args[0][1]:raise ValueError('native call form')
    else:
        args=bytes.fromhex(e['args'])
        if args[:6]!=bytes(6) or int.from_bytes(args[14:18],'big')!=int(e['port'],16)+2:raise ValueError('reference call form')
    if any(e[k]!=r[k] for k in ('source','target')):raise ValueError('rectangle preservation')
    fromRect=rect(bytes.fromhex(e['source']));toRect=rect(bytes.fromhex(e['target']))
    if fromRect!=(156,0,164,20) or toRect!=(62,0,70,20):raise ValueError('original rectangles')
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
        mapping=list(map(int,subprocess.check_output([str(exe),str(ROOT/'tmp'/f'postcopy-{machine}-enter-src-clut.bin'),str(ROOT/'tmp'/f'postcopy-{machine}-enter-dst-clut.bin')],text=True,timeout=30).split()))
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
        publication=re.findall(r'^POSTCOPY_PUBLICATION queued=(\d+)/(\d+) presented=(\d+)/(\d+)$',text,re.M)
        if len(publication)!=1 or publication[0][0]!=publication[0][1]:raise ValueError('offscreen publication')
        dirty=re.findall(r'^POSTCOPY_DIRTY dirty=(\d+)/(\d+) rectangles=(\d+)/(\d+)$',text,re.M)
        if len(dirty)!=1 or dirty[0][0]!=dirty[0][1] or dirty[0][2]!=dirty[0][3]:raise ValueError('offscreen dirty state')
        if sct[4:]!=data('reference','enter','src-clut')[4:] or dct[4:]!=data('reference','enter','dst-clut')[4:]:raise ValueError('paired colour tables')
        # This atlas is the result of the independently verified 20 PICT draws.
        # Outside their written rectangles, Mac allocator bytes and native zeroes
        # are intentionally unspecified. No such byte participates in this copy.
        for side in ('native','reference'):
            if data(side,'enter','src-pixels')!=(ROOT/'tmp'/f'pict8-{side}-20-return-pixels.bin').read_bytes():raise ValueError('atlas provenance')
        written=set()
        pictures=re.findall(r'^PICT8_ENTER n=(\d+) .*?rect=([0-9A-F]{16}) ',text,re.M)
        if [int(n) for n,_ in pictures]!=list(range(1,21)):raise ValueError('atlas draw ledger')
        for _,box in pictures:
            t,l,b,r=rect(bytes.fromhex(box))
            for y in range(t,b):
                for x in range(l,r):written.add(y*sr+x)
        reference_source=data('reference','enter','src-pixels')
        if any(src[i]!=reference_source[i] for i in written):raise ValueError('paired drawn atlas pixels')
        for y in range(fromRect[0],fromRect[2]):
            for x in range(fromRect[1],fromRect[3]):
                if y*sr+x not in written:raise ValueError('copy reads unspecified atlas pixels')
        for name,pm in [('src',sp),('dst',dp)]:
            reference_pm=data('reference','return',name+'-pm')
            if pm[4:42]!=reference_pm[4:42]:raise ValueError('paired pixel-map fields')
        reference_destination=data('reference','return','dst-pixels')
        for y in range(db-dt):
            if after[y*dr:y*dr+dright-dl]!=reference_destination[y*dr:y*dr+dright-dl]:raise ValueError('paired complete destination pixels')
    print('PASS post-intro CopyBits: original bytes/ABI, destination colour remapping, complete source/destination buffers and unchanged records')
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('log',type=Path);p.add_argument('--status',type=int,required=True);p.add_argument('--native',action='store_true');a=p.parse_args()
    try:check(a.log.read_text(),a.status,a.native)
    except (ValueError,OSError,KeyError) as e:raise SystemExit('FAIL post-intro CopyBits: '+str(e))
