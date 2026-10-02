#!/usr/bin/env python3
"""Compare the production LineTo raster with original complete-buffer captures."""
import argparse,os,re,struct,subprocess,tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def rect(*v):return struct.pack('>4h',*v)
def run(reference=None,status=None,native=None,native_status=None):
    bounds=rect(0,0,401,648)*4
    before=bytes([7])*(652*401)
    cases=[]
    for end,points in [((20,20),[(20,20)]),((23,20),[(x,20) for x in range(20,24)]),((20,23),[(20,y) for y in range(20,24)]),((23,23),[(i,i) for i in range(20,24)]),((27,23),[(20,20),(21,21),(22,21),(23,22),(24,22),(25,22),(26,23),(27,23)]),((13,21),[(20,20),(19,20),(18,20),(17,21),(16,21),(15,21),(14,21),(13,21)]),((27,19),[(27,19),(26,19),(25,19),(24,20),(23,20),(22,20),(21,20),(20,20)])]:
        after=bytearray(before)
        for x,y in points:after[y*652+x]=26
        cases.append((bounds+rect(20,20,*end),before,after))
    window=rect(-150,-160,330,480)+rect(0,0,200,320)+rect(0,0,200,320)
    for clip,ends,points in [
        (rect(-32767,-32767,32767,32767),(260,0,260,200),[(420,y) for y in range(150,350)]),
        (rect(0,0,200,320),(-10,0,5,0),[(x,150) for x in range(160,166)]),
        (rect(0,0,0,0),(260,0,260,200),[])]:
        before=bytes([7])*(640*480);after=bytearray(before)
        for x,y in points:after[y*640+x]=16
        cases.append((window+clip+rect(*ends),before,after))
    if reference:
        log=reference.read_text()
        fixture_counts=re.findall(r'^PASS original intro LineTo fixtures=(48|80)$',log,re.M)
        if status!=0 or any(s in log for s in ('FAIL','LUA ERROR','Error in')) or len(fixture_counts)!=1 or log.count('Exited via the debugger')!=1:raise ValueError('reference completion')
        fixture_count=int(fixture_counts[0])
        code=(ROOT/'tmp/segments/CODE_6_Dark3').read_bytes()
        if code[0x3376:0x3380].hex()!='3f2effc63f2effc4a891' or 'LINE_BYTES 3F2EFFC63F2EFFC4A891' not in log:raise ValueError('original caller bytes')
        for n in range(fixture_count+1):
            stem='lineto-reference-'+(f'fixture{n}-' if n else '')
            def read(phase,kind):return (ROOT/'tmp'/f'{stem}{phase}-{kind}.bin').read_bytes()
            from check_driver22 import fields,one
            e,r=[fields(one(log,r'^LINE_'+phase+rf' fixture={n} (.*)$')) for phase in ('ENTER','RETURN')]
            if r['sp']!=e['sp']+4 or r['d0']:raise ValueError('original stack/result')
            for reg in [f'd{i}' for i in range(1,8)]+[f'a{i}' for i in range(1,7)]:
                if e[reg]!=r[reg]:raise ValueError('original preserved '+reg)
            port=read('enter','port');pm=read('enter','pm');returned=read('return','port')
            v0,h0=struct.unpack_from('>hh',port,48);v1,h1=struct.unpack_from('>hh',returned,48)
            if returned[48:52]!=read('enter','args')[4:8]:raise ValueError('original requested pen position')
            expected=bytearray(port);expected[48:52]=struct.pack('>hh',v1,h1)
            if returned!=expected:raise ValueError('port preservation')
            for kind in ('pm','vis','clip','clut','pen','pen-map','pen-data'):
                if read('enter',kind)!=read('return',kind):raise ValueError('modified '+kind)
            b=pm[6:14]+port[16:24]+read('enter','vis')[2:10]+read('enter','clip')[2:10]+rect(h0,v0,h1,v1)
            images=[]
            for phase in ('enter','return'):
                pixels=read(phase,'pixels')
                if n:
                    whole=bytearray(652*401)
                    for y in range(64):whole[y*652:y*652+64]=pixels[y*64:y*64+64]
                    pixels=whole
                images.append(pixels)
            cases.append((b,*images))
    if native:
        if not reference:raise ValueError('native comparison needs reference')
        log=native.read_text()
        if native_status!=0 or any(s in log for s in ('FAIL','Error in','TIMEOUT','Program received signal')) or log.count('PASS native original LineTo caller stack registers and pen position')!=1 or log.count('[Inferior 1 (Remote target) detached]')!=1:raise ValueError('native completion')
        def nr(phase,kind):return (ROOT/'tmp'/f'lineto-native-{phase}-{kind}.bin').read_bytes()
        def rr(phase,kind):return (ROOT/'tmp'/f'lineto-reference-{phase}-{kind}.bin').read_bytes()
        for kind in ('pm','vis','clip','clut'):
            if nr('enter',kind)!=nr('return',kind):raise ValueError('native changed '+kind)
        port=nr('enter','port');pm=nr('enter','pm');returned=nr('return','port')
        if port[:48]+port[52:]!=returned[:48]+returned[52:]:raise ValueError('native changed port')
        if port[48:58]!=rr('enter','port')[48:58] or returned[48:58]!=rr('return','port')[48:58]:raise ValueError('paired pen state')
        v0,h0=struct.unpack_from('>hh',port,48);v1,h1=struct.unpack_from('>hh',returned,48)
        b=pm[6:14]+port[16:24]+nr('enter','vis')[2:10]+nr('enter','clip')[2:10]+rect(h0,v0,h1,v1)
        cases.append((b,nr('enter','pixels'),nr('return','pixels')))
        if nr('return','clut')[4:]!=rr('return','clut')[4:]:raise ValueError('paired CLUT')
        for phase in ('enter','return'):
            a,b=nr(phase,'pixels'),rr(phase,'pixels')
            if len(a)!=652*401 or len(b)!=652*401:raise ValueError('complete buffers')
            if any(a[y*652:y*652+648]!=b[y*652:y*652+648] for y in range(401)):raise ValueError('paired full-buffer pixels '+phase)
    with tempfile.TemporaryDirectory(prefix='aitd-line8-') as d:
        exe=Path(d)/'test'
        subprocess.run([os.environ.get('HOST_CXX','c++'),'-std=c++17','-Wall','-Wextra','-Werror','-fsanitize=address,undefined',str(ROOT/'tools/test_line8.cpp'),'-o',str(exe)],check=True)
        for i,(b,before,after) in enumerate(cases):
            result=subprocess.run([str(exe)]+(['window'] if len(before)==307200 else []),input=b+before,stdout=subprocess.PIPE,check=True,timeout=30).stdout
            if result!=after:raise ValueError(f'case {i}: production raster differs from original/oracle')
    print('PASS Line8: 7 host buffer cases and 3 window-origin/dirty fixtures'+(f'; original full buffer and {fixture_count} clipped slope/reversal fixtures' if reference else '')+('; paired native full buffer/CLUT and ABI' if native else ''))
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--reference',type=Path);p.add_argument('--status',type=int);p.add_argument('--native',type=Path);p.add_argument('--native-status',type=int);a=p.parse_args()
    try:run(a.reference,a.status,a.native,a.native_status)
    except (ValueError,OSError) as e:raise SystemExit('FAIL Line8: '+str(e))
