#!/usr/bin/env python3
"""Check the production solid-fill helper, optionally against original Mac captures."""
import argparse,os,re,struct,subprocess,tempfile
from pathlib import Path
from resource_fork import read_resource_fork
ROOT=Path(__file__).resolve().parents[1]
def rect(*v):return struct.pack('>4h',*v)
def run(reference=None,status=None,native=None,native_status=None,mode=8):
    if mode not in (0,8):raise ValueError("unsupported fixture mode")
    prefix="window-mode0-reference-" if mode==0 else "paintrect-reference-"
    if native and mode==0:raise ValueError("use the idle-call observer for native mode-0 acceptance")
    cases=[]
    if reference:
        text=reference.read_text()
        if status!=0 or re.search(r'FAIL|LUA ERROR|Error in|timeout',text) or text.count('PASS original window PaintRect fixtures=2')!=1 or text.count('Exited via the debugger')!=1:raise ValueError('reference completion')
        code=next(r.body for r in read_resource_fork(ROOT/'tmp/runtime-data/Alone In The Dark') if r.kind==b'CODE' and r.rid==13)
        if code[0xd4e:0xd54].hex()!='486efff0a8a2' or 'PR_BYTES 486EFFF0A8A2' not in text:raise ValueError('original caller bytes')
        for f in range(3):
            rows=[]
            for phase in ('ENTER','RETURN'):
                row=re.findall(r'^PR_'+phase+r' fixture='+str(f)+r' (.*)$',text,re.M)
                if len(row)!=1:raise ValueError('missing/duplicate original call')
                rows.append({k:int(v,16) for k,v in re.findall(r'\b(sp|port|[da][0-7])=([0-9A-F]+)',row[0])})
            e,r=rows
            if r['sp']!=e['sp']+4 or r['d0']!=0 or r['d1']!=((e['d1']&0xffff0000)|8) or r['a1']!=e['port']:raise ValueError('original return ABI')
            for reg in [f'd{i}' for i in range(3,8)]+[f'a{i}' for i in range(2,7)]:
                if r[reg]!=e[reg]:raise ValueError('original preserved '+reg)
            stem=prefix+('' if f==0 else f'fixture{f}-')
            def read(phase,name):return (ROOT/'tmp'/f'{stem}{phase}-{name}.bin').read_bytes()
            port,pm=read('enter','port'),read('enter','pm')
            if struct.unpack_from('>H',port,56)[0]!=mode:raise ValueError('pen mode')
            for name in ('port','pm','rect','vis','clip','pen','pen-data','clut'):
                if read('enter',name)!=read('return',name):raise ValueError('modified '+name)
            if read('enter','pen-data')!=b'\xff'*8:raise ValueError('solid pattern')
            if len(port)!=108 or len(pm)!=50 or pm[32:34]!=b'\x00\x08':raise ValueError('bitmap layout')
            bounds=pm[6:14]+port[16:24]+read('enter','vis')[2:10]+read('enter','clip')[2:10]+read('enter','rect')[4:12]
            before,after=read('enter','pixels'),read('return','pixels')
            if len(before)!=307200 or len(after)!=307200:raise ValueError('full screen capture')
            changes=sum(a!=b for a,b in zip(before,after))
            if changes!=[0,72,64000][f]:raise ValueError('contrasting fill coverage')
            cases.append((bounds,before,after))
    if native:
        text=native.read_text()
        from check_native_driver import check as startup
        startup(text,native_status)
        if native_status!=0 or any(s in text for s in ('FAIL','Error in','timeout')) or text.count('PASS native original PaintRect stack/register contract')!=1 or text.count('[Inferior 1 (Remote target) detached]')!=1:raise ValueError('native completion')
        if 'PR_NATIVE_BYTES 486EFFF0A8A2' not in text:raise ValueError('native original bytes')
        def nr(phase,name):return (ROOT/'tmp'/f'paintrect-native-{phase}-{name}.bin').read_bytes()
        for name in ('port','pm','rect','vis','clip','clut'):
            if nr('enter',name)!=nr('return',name):raise ValueError('native changed '+name)
        port,pm=nr('enter','port'),nr('enter','pm')
        bounds=pm[6:14]+port[16:24]+nr('enter','vis')[2:10]+nr('enter','clip')[2:10]+nr('enter','rect')[4:12]
        cases.append((bounds,nr('enter','pixels'),nr('return','pixels')))
        if not reference:raise ValueError('native comparison requires reference')
        ref=(ROOT/'tmp/paintrect-reference-return-pixels.bin').read_bytes()
        native_pixels=nr('return','pixels')
        if any(native_pixels[y*640+160:y*640+480]!=ref[y*640+160:y*640+480] for y in range(150,350)):raise ValueError('native/reference client pixels')
        # ctSeed is independently generated; flags, size and all colour entries must match.
        if nr('return','clut')[4:]!=(ROOT/'tmp/paintrect-reference-return-clut.bin').read_bytes()[4:]:raise ValueError('native/reference CLUT')
    # Independent full-buffer oracle: signed origin, clipping, empty and inverted
    # rectangles, and preservation of every pixel outside the intersection.
    mapbox=(-150,-160,330,480);portbox=(0,0,200,320)
    for r in [(5,7,11,19),(-5,-7,210,330),(2,2,2,3),(9,9,3,3),(199,319,220,350),(-32768,-32768,32767,32767)]:
        clip=(3,4,199,319);before=bytes((i*13+7)&255 for i in range(307200));after=bytearray(before)
        for y in range(480):
            ly=y-150
            for x in range(640):
                lx=x-160
                if all(t<=ly<b and l<=lx<rr for t,l,b,rr in (mapbox,portbox,portbox,clip,r)):after[y*640+x]=255
        cases.append((b''.join(rect(*b) for b in (mapbox,portbox,portbox,clip,r)),before,bytes(after)))
    with tempfile.TemporaryDirectory(prefix='aitd-fillrect-') as d:
        exe=Path(d)/'test'
        subprocess.run([os.environ.get('HOST_CXX','c++'),'-std=c++17','-Wall','-Wextra','-Werror','-fsanitize=address,undefined',str(ROOT/'tools/test_fillrect8.cpp'),'-o',str(exe)],check=True)
        for bounds,before,after in cases:
            result=subprocess.run([str(exe)],input=bounds+before,stdout=subprocess.PIPE,check=True,timeout=30).stdout
            if result!=after:raise ValueError('production fill differs from full-buffer oracle/reference')
    print(f'PASS FillRect8: {len(cases)} complete-screen comparisons, including surrounding pixels')
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--reference',type=Path);p.add_argument('--status',type=int);p.add_argument('--native',type=Path);p.add_argument('--native-status',type=int);p.add_argument('--mode',type=int,choices=(0,8),default=8);a=p.parse_args()
    try:run(a.reference,a.status,a.native,a.native_status,a.mode)
    except (ValueError,OSError) as e:raise SystemExit('FAIL FillRect8: '+str(e))
