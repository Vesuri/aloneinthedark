#!/usr/bin/env python3
"""Pair the original background ShowHide with the native window service."""
import argparse
import hashlib
from pathlib import Path
import struct
from check_choice_services import one
from check_getgworld import fields
from check_ctable import preserved
from resource_fork import read_resource_fork


def require(ok, message):
    if not ok:
        raise ValueError(message)


def spans(region):
    words=struct.unpack('>'+str(len(region)//2)+'h',region)
    require(words[0]==len(region) and len(region)>10,'complex region extent')
    events={};at=5
    while words[at]!=32767:
        y=words[at];at+=1;edges=[]
        while words[at]!=32767:
            edges.append(words[at]);at+=1
        at+=1;require(y not in events and edges==sorted(set(edges)),'canonical region transitions')
        events[y]=edges
    require(at==len(words)-1,'region terminator')
    active=set()
    for y in range(481):
        active.symmetric_difference_update(events.get(y,()))
        edges=sorted(active);require(len(edges)%2==0,'paired region edges')
        if y==480:
            require(not edges,'closed region');break
        for left,right in zip(edges[::2],edges[1::2]):
            require(0<=left<right<=640,'screen region extent')
            yield y,left,right


def check(reference,native,reference_status,native_status,folder,resource):
    code=next(r.body for r in read_resource_fork(resource) if r.kind==b'CODE' and r.rid==9)[0xfb4:0xfc8]
    require(hashlib.sha256(code).hexdigest()=='6ff795aa43796be5965f16c5109e7e26f3d7966698fbeb435d57da5a9c80ba2c','original ShowHide instructions')
    captures={}
    for side,text,status in [('reference',reference,reference_status),('native',native,native_status)]:
        require(status==0 and all(s not in text for s in ('FAIL','Error in','LUA ERROR','TIMEOUT','Program received signal')),side+' run')
        marker='PASS original ShowHide calls=1' if side=='reference' else 'PASS native ShowHide state capture'
        ending='Exited via the debugger' if side=='reference' else '[Inferior 1 (Remote target) detached]'
        require(text.count(marker)==text.count(ending)==1,side+' completion')
        label=' label=showhide' if side=='reference' else ''
        require(bytes.fromhex(one(text,r'SH_BYTES'+label+r' data=([0-9A-F]+)'))==code,side+' live original bytes')
        entered=fields(one(text,r'SH_ENTER'+label+r' (.*)'))
        returned=fields(one(text,r'SH_RETURN'+label+r' (.*)'))
        preserved(entered,returned,6)
        args=bytes.fromhex(one(text,r'SH_ENTER'+label+r' .*args=([0-9A-F]+) .*'))
        require(args[0]==1 and int.from_bytes(args[2:6],'big')!=0,side+' visible window argument')
        for phase in ('before','after'):
            prefix=folder/f'showhide-{side}-showhide-{phase}'
            captures[side,phase]={name:Path(str(prefix)+'-'+name+'.bin').read_bytes() for name in (
                'window','windowpm','palette','private','gd','pm','clut','physical','gray','front','visibility','clip','structure','content','update')}
        a,b=(captures[side,p] for p in ('before','after'))
        window=bytearray(a['window']);require(len(window)==156 and window[110]==0,side+' initially hidden')
        window[110]=1;require(window==b['window'],side+' visibility-only window record change')
        require(struct.unpack_from('>4h',window,16)==(0,0,16000,16000),side+' local background coordinates')
        for name in ('windowpm','palette','private','gd','pm','clut','gray','front','clip'):
            require(a[name]==b[name],side+' preserved '+name)
        for name in ('visibility','structure','content','update'):
            require(a[name]==bytes.fromhex('000a0000000000000000'),side+' initially empty '+name)
    for phase in ('before','after'):
        for name in ('visibility','clip','structure','content','update','gray'):
            require(captures['reference',phase][name]==captures['native',phase][name],'paired '+phase+'/'+name)
    require(captures['native','after']['clut'][4:]==captures['reference','after']['clut'][4:],'paired complete CLUT')
    region=captures['reference','after']['update']
    expected=bytearray(captures['native','before']['physical']);count=0
    require(len(expected)==307200,'logical screen size')
    reference_after=captures['reference','after']['physical']
    for y,left,right in spans(region):
        require(not (150<=y<350 and left<480 and right>160),'no viewport exposure')
        expected[y*640+left:y*640+right]=bytes([255])*(right-left);count+=right-left
        require(reference_after[y*640+left:y*640+right]==bytes([255])*(right-left),'reference exposed pixels are black')
    require(expected==captures['native','after']['physical'],'exact native region clear and preservation outside it')
    for side in ('reference','native'):
        a,b=(captures[side,phase]['physical'] for phase in ('before','after'))
        require(all(a[y*640+160:y*640+480]==b[y*640+160:y*640+480] for y in range(150,350)),side+' viewport unchanged')
    a=fields(one(native,r'SH_NATIVE_STATE phase=before (.*)'));b=fields(one(native,r'SH_NATIVE_STATE phase=after (.*)'))
    require(a==b and a['queued']==1 and a['dirty']==a['count']==0,'unchanged native palette binding and presentation')
    for name in ('copper','pending'):
        require((folder/f'showhide-native-showhide-before-{name}.bin').read_bytes()==(folder/f'showhide-native-showhide-after-{name}.bin').read_bytes(),'unchanged '+name)
    require(native.count('PASS native ShowHide next-stop original-MDRV=absent')==1,'native progression and MDRV guard')
    next_stop=one(native,r'SH_NEXT (state=3 trap=A8AB segment=13 offset=1DA manager=QUICKDRAW routine=UNIONRECT windows=(?:81|107) services=(?:143/143|151/151))')
    print(f'PASS paired ShowHide: original bytes/ABI, complete regions, {count} exposed black pixels, unchanged viewport/palette; '+next_stop)


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('reference',type=Path);p.add_argument('native',type=Path)
    p.add_argument('--reference-status',type=int,required=True);p.add_argument('--native-status',type=int,required=True)
    p.add_argument('--folder',type=Path,default=Path('tmp'))
    p.add_argument('--resource',type=Path,default=Path('tmp/runtime-data/Alone In The Dark'))
    a=p.parse_args();check(a.reference.read_text(),a.native.read_text(),a.reference_status,a.native_status,a.folder,a.resource)
