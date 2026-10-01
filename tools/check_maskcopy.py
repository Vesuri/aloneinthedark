#!/usr/bin/env python3
"""Independent masked-copy pixel model, original ABI and record isolation."""
import argparse,re,struct,os,subprocess,tempfile
from pathlib import Path
from check_insetrgn import pixels
ROOT=Path(__file__).resolve().parents[1]
def rect(b,n=0):return struct.unpack_from('>4h',b,n)
def word(b,n):return struct.unpack_from('>H',b,n)[0]
def run(log,status):
    t=log.read_text()
    if status or t.count('PASS original pond masked CopyBits')!=1 or t.count('Exited via the debugger')!=1 or re.search(r'FAIL|LUA ERROR|TIMEOUT|Error in',t):raise ValueError('completion')
    raw=(ROOT/'tmp/segments/CODE_4_Dark').read_bytes()[0x3460:0x346e]
    if raw.hex()!='486efff8486efff842672f0aa8ec' or re.findall(r'^MASKCOPY_BYTES (\w+)$',t,re.M)!=[raw.hex().upper()]:raise ValueError('original caller bytes')
    records=[re.findall(r'^MASKCOPY_'+phase+r' (.*)$',t,re.M) for phase in ('ENTER','RETURN')]
    if any(len(r)!=2 for r in records):raise ValueError('original and distinctive fixture required')
    for index,prefix in enumerate(('', 'fixture-')):
        e,r=[dict(re.findall(r'(\w+)=([^ ]+)',v[index])) for v in records]
        if int(r['sp'],16)!=int(e['sp'],16)+22 or int(r['d0'],16):raise ValueError('ABI')
        for key in [f'd{i}' for i in range(2,8)]+[f'a{i}' for i in range(2,7)]:
            if e[key]!=r[key]:raise ValueError('preserved '+key)
        args=bytes.fromhex(e['args'])
        if not int.from_bytes(args[:4],'big') or args[4:6]!=bytes(2):raise ValueError('mask/mode')
        if e['source']!=r['source'] or e['target']!=r['target']:raise ValueError('rectangles changed')
        source=rect(bytes.fromhex(e['source']));target=rect(bytes.fromhex(e['target']))
        if source!=target:raise ValueError('measured unscaled rectangles')
        def data(phase,name):return (ROOT/f'tmp/maskcopy-reference-{prefix}{phase}-{name}.bin').read_bytes()
        for name in ('src-pm','dst-pm','src-pixels','src-clut','dst-clut','mask','port','vis','clip','inverse'):
            if data('enter',name)!=data('return',name):raise ValueError('changed '+name)
        sp=data('enter','src-pm');dp=data('enter','dst-pm');src=data('enter','src-pixels');before=data('enter','dst-pixels');after=data('return','dst-pixels')
        st,sl,sb,sr=rect(sp,6);dt,dl,db,dr=rect(dp,6);ss=word(sp,4)&0x3fff;ds=word(dp,4)&0x3fff
        if word(sp,32)!=8 or word(dp,32)!=8 or len(src)!=ss*(sb-st) or len(before)!=ds*(db-dt) or len(after)!=len(before):raise ValueError('storage')
        if data('enter','src-clut')!=data('enter','dst-clut'):raise ValueError('measured matching palettes')
        mask=pixels(data('enter','mask'));port=rect(data('enter','port'),16)
        def membership(name):
            b=data('enter',name)
            if len(b)==10:
                top,left,bottom,right=rect(b,2)
                return lambda x,y:top<=y<bottom and left<=x<right
            points=pixels(b)
            return lambda x,y:(x,y) in points
        vis=membership('vis');clip=membership('clip')
        expected=bytearray(before);copied=0
        for x,y in mask:
            if not (target[0]<=y<target[2] and target[1]<=x<target[3] and dt<=y<db and dl<=x<dr and st<=y<sb and sl<=x<sr and vis(x,y) and clip(x,y) and port[0]<=y<port[2] and port[1]<=x<port[3]):continue
            expected[(y-dt)*ds+x-dl]=src[(y-st)*ss+x-sl];copied+=1
        if after!=expected:raise ValueError('complete masked destination')
        changed=sum(a!=b for a,b in zip(before,after))
        if not copied or (index and not changed):raise ValueError('fixture cannot discriminate missing copy')
        print(f'PASS {prefix or "original-"}masked copy: {copied} covered pixels, {changed} changed; complete destination and preserved source/records')
def check_native(log,status):
    t=log.read_text()
    if status or t.count('PASS native pond masked CopyBits')!=1 or t.count('COMPLETE native masked copy and continuation')!=1 or t.count('[Inferior 1 (Remote target) detached]')!=1 or re.search(r'FAIL|Error in|Program received signal|TIMEOUT',t):raise ValueError('native completion')
    records=[re.findall(r'^MASKCOPY_'+phase+r' (.*)$',t,re.M) for phase in ('ENTER','RETURN')]
    if any(len(v)!=1 for v in records):raise ValueError('native call count')
    e,r=[dict(re.findall(r'(\w+)=([^ ]+)',v[0])) for v in records]
    if int(r['sp'],16)!=int(e['sp'],16)+22 or int(r['d0'],16):raise ValueError('native ABI')
    for key in [f'd{i}' for i in range(2,8)]+[f'a{i}' for i in range(2,7)]:
        if e[key]!=r[key]:raise ValueError('native preserved '+key)
    args=re.findall(r'^MASKCOPY_ARGS mask=(\w+) mode=(\w+) destination=(\w+) expected=(\w+)$',t,re.M)
    if len(args)!=1 or not int(args[0][0],16) or int(args[0][1],16):raise ValueError('native mask/mode')
    referenceRect=rect((ROOT/'tmp/maskcopy-reference-enter-from.bin').read_bytes())
    if any(rect(bytes.fromhex(v))!=referenceRect for v in (e['source'],e['target'],r['source'],r['target'])):raise ValueError('native rectangles')
    def data(phase,name):return (ROOT/f'tmp/maskcopy-native-{phase}-{name}.bin').read_bytes()
    def ref(phase,name):return (ROOT/f'tmp/maskcopy-reference-{phase}-{name}.bin').read_bytes()
    for name in ('src-pm','dst-pm','src-pixels','src-clut','dst-clut','mask','port','vis','clip','inverse'):
        if data('enter',name)!=data('return',name):raise ValueError('native changed '+name)
    if data('enter','mask')!=ref('enter','mask'):raise ValueError('paired mask')
    for name in ('src-clut','dst-clut'):
        if data('enter',name)[4:]!=ref('enter',name)[4:]:raise ValueError('paired colours '+name)
    if data('enter','src-clut')[:4]!=data('enter','dst-clut')[:4]:raise ValueError('native colour environment')
    sp=data('enter','src-pm');dp=data('enter','dst-pm');src=data('enter','src-pixels');before=data('enter','dst-pixels');after=data('return','dst-pixels')
    for name,pm in (('src-pm',sp),('dst-pm',dp)):
        if pm[4:42]!=ref('enter',name)[4:42]:raise ValueError('paired map '+name)
    st,sl,sb,sr=rect(sp,6);dt,dl,db,dr=rect(dp,6);ss=word(sp,4)&0x3fff;ds=word(dp,4)&0x3fff
    if len(src)!=ss*(sb-st) or len(before)!=ds*(db-dt) or len(after)!=len(before):raise ValueError('native storage')
    if len(data('enter','vis'))!=10 or len(data('enter','clip'))!=10:raise ValueError('native clip form')
    bounds=[rect(data('enter','port'),16),rect(data('enter','vis'),2),rect(data('enter','clip'),2)]
    expected=bytearray(before);copied=0;original_source=ref('enter','src-pixels');original_after=ref('return','dst-pixels')
    for x,y in pixels(data('enter','mask')):
        if not (referenceRect[0]<=y<referenceRect[2] and referenceRect[1]<=x<referenceRect[3] and st<=y<sb and sl<=x<sr and dt<=y<db and dl<=x<dr and all(a<=y<c and b<=x<d for a,b,c,d in bounds)):continue
        si=(y-st)*ss+x-sl;di=(y-dt)*ds+x-dl
        expected[di]=src[si];copied+=1
        if src[si]!=original_source[si] or after[di]!=original_after[di]:raise ValueError('paired copied pixels')
    if not copied or after!=expected:raise ValueError('native complete destination')
    if re.findall(r'^MASKCOPY_BOOK batches=(\d+)$',t,re.M)!=['0']:raise ValueError('book replay')
    for label in ('PUBLICATION','DIRTY'):
        line=re.findall(r'^MASKCOPY_'+label+r' (.*)$',t,re.M)
        if len(line)!=1 or any(a!=b for a,b in re.findall(r'=(\d+)/(\d+)',line[0])):raise ValueError('offscreen '+label)
    next_stop=re.findall(r'^MASKCOPY_NEXT trap=(\w+) segment=(\w+) offset=(\w+) routine=(.+)$',t,re.M)
    if len(next_stop)!=1 or next_stop[0][3]=='UNKNOWN TRAP' or tuple(int(x,16) for x in next_stop[0][:3])==(0xa8ec,4,0x346c):raise ValueError('named continuation')
    print(f'PASS native masked copy: paired {copied} pixels, complete destination preservation, source/mask/records, ABI, no publication or book replay, named continuation')

def check_helper():
    with tempfile.TemporaryDirectory(prefix='aitd-maskcopy-') as directory:
        exe=Path(directory)/'check'
        subprocess.run([os.environ.get('HOST_CXX','c++'),'-std=c++17','-Wall','-Wextra','-Werror','-fsanitize=address,undefined',str(ROOT/'tools/test_copybits8.cpp'),'-o',str(exe)],check=True)
        for prefix in ('','fixture-'):
            subprocess.run([str(exe),str(ROOT/'tmp'),prefix],check=True,timeout=30)

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('log',type=Path);p.add_argument('--status',type=int,required=True);p.add_argument('--native',type=Path);p.add_argument('--native-status',type=int);a=p.parse_args();run(a.log,a.status);check_helper()
    if a.native:
        if a.native_status is None:p.error('--native requires --native-status')
        check_native(a.native,a.native_status)
