#!/usr/bin/env python3
"""Paired full-buffer acceptance for the original game-window LineTo."""
import argparse,hashlib,os,re,struct,subprocess,tempfile
from pathlib import Path
from check_aga_capture import check_frame
ROOT=Path(__file__).resolve().parents[1]
def read(side,phase,kind):return (ROOT/'tmp'/f'windowline-{side}-{phase}-{kind}.bin').read_bytes()
def check(reference,status,native=None,native_status=None):
    if status!=0 or reference.count('PASS original window LineTo fixtures=0')!=1 or reference.count('Exited via the debugger')!=1 or re.search(r'FAIL|LUA ERROR|Error in',reference):raise ValueError('reference completion')
    code=(ROOT/'tmp/segments/CODE_13_Dan2').read_bytes()
    if code[0xb52:0xb5c].hex()!='3eae000c3f2e000ea891' or 'LINE_BYTES 3EAE000C3F2E000EA891' not in reference:raise ValueError('original caller bytes')
    records=[re.search(r'^LINE_'+p+r' fixture=0 (.*)$',reference,re.M)[1] for p in ('ENTER','RETURN')]
    e,r=[dict((k,int(v,16)) for k,v in re.findall(r'(sp|d[0-7]|a[0-6])=([0-9A-F]+)',line)) for line in records]
    if r['sp']!=e['sp']+4 or r['d0'] or any(e[k]!=r[k] for k in [f'd{i}' for i in range(1,8)]+[f'a{i}' for i in range(1,7)]):raise ValueError('reference ABI')
    if native:
        log=native.read_text()
        if native_status!=0 or re.search(r'FAIL|Error in|TIMEOUT|Program received signal',log) or log.count('[Inferior 1 (Remote target) detached]')!=1 or log.count('PASS native original window LineTo caller stack registers and pen position')!=1:raise ValueError('native completion')
        end=re.search(r'(?:WINDOWLINE_NEXT|MLIST_NEXT) state=3 trap=A0F8 (?:selector=F )?segment=3 offset=FC8 manager=SOUND DRIVER routine=SELECTOR windows=249 services=(\d+)/(\d+)',log)
        q=re.search(r'NEXT_DRIVER .*statuses=(\d+)',log) or re.search(r'WINDOWLINE_NEXT .*queries=(\d+)',log)
        if not end or not q or int(end[1])-int(q[1])!=1389 or int(end[2])-int(q[1])!=1388:raise ValueError('next named stop/service accounting')
        if 'WINDOWLINE_DIRTY top=150 left=420 bottom=350 right=421' not in log:raise ValueError('dirty rectangle')
    with tempfile.TemporaryDirectory(prefix='aitd-windowline-') as work:
        exe=Path(work)/'test'
        subprocess.run([os.environ.get('HOST_CXX','c++'),'-std=c++17','-Wall','-Wextra','-Werror','-fsanitize=address,undefined',str(ROOT/'tools/test_line8.cpp'),'-o',str(exe)],check=True)
        for side in (['reference','native'] if native else ['reference']):
            port=read(side,'enter','port');pm=read(side,'enter','pm')
            if port[48:58]!=bytes.fromhex('00000104000100010008') or struct.unpack_from('>I',port,80)[0]!=16:raise ValueError('pen state')
            after_port=bytearray(port);after_port[48:52]=bytes.fromhex('00c80104')
            if read(side,'return','port')!=after_port:raise ValueError('pen/preserved port')
            for kind in ('pm','clut','vis','clip'):
                if read(side,'enter',kind)!=read(side,'return',kind):raise ValueError('preserved '+kind)
            if pm[4:14]!=bytes.fromhex('8280ff6aff60014a01e0') or port[16:24]!=struct.pack('>4h',0,0,200,320):raise ValueError('screen geometry')
            for kind,want in [('vis',(0,0,200,320)),('clip',(-32767,-32767,32767,32767))]:
                if read(side,'enter',kind)!=struct.pack('>H4h',10,*want):raise ValueError('rectangular clipping')
            before=read(side,'enter','pixels');after=read(side,'return','pixels');expected=bytearray(before)
            if before!=(ROOT/'tmp'/f'copylate-{side}-return-dst-pixels.bin').read_bytes():raise ValueError('input differs from verified title frame')
            if len(before)!=307200:raise ValueError('complete screen extent')
            for y in range(150,350):expected[y*640+420]=16
            if after!=expected:raise ValueError('independent full-screen line/preservation')
            bounds=pm[6:14]+port[16:24]+read(side,'enter','vis')[2:]+read(side,'enter','clip')[2:]+struct.pack('>4h',260,0,260,200)
            output=subprocess.check_output([str(exe),'window'],input=bounds+before,timeout=30)
            if output!=after:raise ValueError('production raster and dirty footprint')
    if native:
        if read('native','return','clut')[4:]!=read('reference','return','clut')[4:]:raise ValueError('paired colours')
        # Full input buffers equal the previously paired title capture, including
        # its explained D5/D6/D7 differences. All new changes must match exactly.
        n0,n1=[read('native',p,'pixels') for p in ('enter','return')]
        r0,r1=[read('reference',p,'pixels') for p in ('enter','return')]
        nd={i for i,(a,b) in enumerate(zip(n0,n1)) if a!=b};rd={i for i,(a,b) in enumerate(zip(r0,r1)) if a!=b}
        if nd!=rd or len(nd)!=200:raise ValueError('paired changed pixels')
        m=re.search(r'WINDOWLINE_AGA front=([0-9A-F]+) copper=([0-9A-F]+) queued=(\d+) presented=(\d+) crop=160/150 pending=0 line=(\d+) late=0',log)
        if not m or m[3]!=m[4] or int(m[5])>=72 or log.count('PASS native window LineTo AGA publication')!=1:raise ValueError('VBI publication')
        folder=ROOT/'tmp';source=(folder/'aga-windowline-logical.bin').read_bytes();clut=(folder/'aga-windowline-clut.bin').read_bytes();transfer=(folder/'video-transfer-lut16.bin').read_bytes()
        if source!=n1:raise ValueError('published logical buffer differs from completed line')
        if hashlib.sha256(transfer).hexdigest()!='bf0a6433c155a61989e5dc0571bae1357066ab476a24d0afaf2e2aa7094fe2aa':raise ValueError('reference colour transfer')
        check_frame(folder,'aga-windowline-active',source,clut,160,150,int(m[1],16),transfer)
        for suffix in ('planes','copper'):
            if (folder/f'aga-windowline-queued-{suffix}.bin').read_bytes()!=(folder/f'aga-windowline-active-{suffix}.bin').read_bytes():raise ValueError('queued/published bytes')
        print('PASS native window LineTo: paired 200 pixels, complete buffer/records, ABI, exact dirty rectangle and AGA publication')
    print('PASS original window LineTo: bytes/ABI, pen, 200 clipped pixels and complete 307200-byte framebuffer')
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('reference',type=Path);p.add_argument('--status',required=True,type=int);p.add_argument('--native',type=Path);p.add_argument('--native-status',type=int);a=p.parse_args()
    try:check(a.reference.read_text(),a.status,a.native,a.native_status)
    except (ValueError,OSError,KeyError,TypeError) as e:raise SystemExit('FAIL window LineTo: '+str(e))
