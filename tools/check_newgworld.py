#!/usr/bin/env python3
"""Compare owned eight-bit GWorld records, lookup tables and untouched screen."""
import argparse
import hashlib
import re
import struct
from pathlib import Path
from check_choice_services import one, PRESERVED
from check_getgworld import fields
from resource_fork import read_resource_fork

NAMES=['pixmap','pixels','ctable','visibility','clip','grafvars','backpat','penpat','fillpat','backpat-map','backpat-data','backpat-xdata','backpat-xmap','penpat-map','penpat-data','penpat-xdata','penpat-xmap','fillpat-map','fillpat-data','fillpat-xdata','fillpat-xmap','grafvars-child','backpat-table','penpat-table','fillpat-table','device-map','device-inverse']
POINTERS={'port':{2:'pixmap',8:'grafvars',24:'visibility',28:'clip',32:'backpat',58:'penpat',62:'fillpat'},'pixmap':{0:'pixels',42:'ctable'},'device-map':{0:'pixels',42:'ctable'},'grafvars':{26:'grafvars-child'},'grafvars-child':{6:'device-inverse',22:'device-map'}}
for name in ('backpat','penpat','fillpat'):
    POINTERS[name]={2:name+'-map',6:name+'-data',10:name+'-xdata',16:name+'-xmap'}
    POINTERS[name+'-map']={42:name+'-table'}


def u32(data,at=0):
    return struct.unpack_from('>I',data,at)[0]


def check(reference,native,reference_status,native_status,resource,folder,device_table=False):
    segment,start,end,digest=(13,0x216,0x236,"c55b6fcf3393bf4e7adbffd132760d18fd9ed1225fc5da8b19077b29a5c5baad") if device_table else (10,0x50,0x76,'4a24b196d92950126c330581d9d5c728c555769313b05bcbfd61cd0c9699d5a5')
    code=next(r.body for r in read_resource_fork(resource) if r.kind==b'CODE' and r.rid==segment)[start:end]
    assert hashlib.sha256(code).hexdigest()==digest,'original constructor bytes'
    def capture(side,name):
        prefix='gworld-device-reference' if device_table and side=='reference' else f'gworld-{side}'
        return (folder/f'{prefix}-{name}.bin').read_bytes()
    captures={};records={}
    for side,text,status in [('reference',reference,reference_status),('native',native,native_status)]:
        assert status==0 and not any(x in text for x in ('FAIL','Error in','LUA ERROR','TIMEOUT','Program received signal')),side+' bounded run'
        marker='PASS original NewGWorld ownership' if side=='reference' else ('PASS native device-table NewGWorld allocation' if device_table else 'PASS native NewGWorld next-stop original-MDRV=absent')
        ending='Exited via the debugger' if side=='reference' else '[Inferior 1 (Remote target) detached]'
        assert text.count(marker)==text.count(ending)==1,side+' positive normal completion'
        e=fields(one(text,r'GW_ENTER (.*)'));r=fields(one(text,r'GW_RETURN (.*)'))
        live=bytearray(code)
        if device_table:live[4:8]=((u32(code,4)+e['a5'])&0xffffffff).to_bytes(4,'big')
        assert bytes.fromhex(one(text,r'GW_BYTES data=([0-9A-F]+)'))==live,side+' live bytes'
        assert (e['flags'],e['device'],e['depth'])==(8,0,8) and e['ctable'] and e['output'],side+' original arguments'
        assert r['sp']==e['sp']+22 and r['result']==0 and r['world'] and r['d0']==r['d1']==r['d2']==0 and r['a0']==e['output'],side+' return contract'
        assert all(e[k]==r[k] for k in PRESERVED),side+' preserved registers'
        records[side]={name:fields(one(text,rf'GW_AUX label={name} (.*)')) for name in NAMES}
        assert len(set(v['handle'] for v in records[side].values()))==27,side+' independent owned handles'
        assert r['clutHandle']!=e['ctable'],side+' distinct copied colour handle'
        assert r['a1']==records[side]['visibility']['body'],side+' returned visibility scratch pointer'
        captures[side]={name:capture(side,'aux-'+name) for name in NAMES}
        captures[side]['port']=capture(side,'port')
        for name,record in records[side].items():
            assert len(captures[side][name])==record['size'],side+'/'+name+' complete body'
        bounds=capture(side,'bounds')
        assert bounds==bytes.fromhex('00000000021e008a' if device_table else '0000000001910288'),side+' bounds'
        assert captures[side]['ctable']==capture(side,'input-clut'),side+' independent exact colour copy'
        if device_table:assert capture(side,'input-clut-after')==capture(side,'input-clut'),side+' input table preservation'
        assert captures[side]['device-inverse'][:4]==captures[side]['ctable'][:4],side+' inverse seed matches copied colours'
        assert records[side]['pixels']['size']==(144*542 if device_table else 652*401),side+' pixel extent'
        for name in ('device','pixels'):
            assert capture(side,'before-'+name)==capture(side,'after-'+name),side+' unchanged screen '+name
        for name,data in captures[side].items():
            for at,target in POINTERS.get(name,{}).items():
                assert u32(data,at)==records[side][target]['handle'],side+'/'+name+' owned '+target
        assert r['base']==records[side]['pixels']['handle'] and r['baseLong']==records[side]['pixels']['body'],side+' unlocked pixel handle'
        if side=='reference':
            for name in NAMES:
                flags=fields(one(text,rf'GW_FLAGS label={name} (.*)'));owner=fields(one(text,rf'GW_OWNER label={name} (.*)'))
                assert flags=={'flags':0,'memerr':0} and owner['owner']==owner['zone']==e['zone'] and owner['memerr']==0,'reference '+name+' ownership'
        else:
            heap=(folder/'gworld-native-heap.bin').read_bytes();zone=e['zone'];masters={};at=64
            while at<len(heap)-16:
                span,logical,owner,kind,_,_=struct.unpack_from('>6I',heap,at)
                assert span>=24 and at+span<=len(heap)-16,'heap block chain'
                if kind==3:
                    for i in range(owner):masters[zone+at+24+i*4]=(u32(heap,at+24+i*4),heap[at+24+owner*4+i])
                at+=span
            for name,v in records[side].items():
                assert masters[v['handle']]==(v['body'],1),name+' active unlocked nonpurgeable master'
                assert v['kind']==2 and v['owner']==v['handle']-zone,name+' owning block'
                assert u32(heap,v['body']-zone-20)==v['size'],name+' logical size'
            assert u32(heap,r['world']-zone-20)==108 and u32(heap,r['world']-zone-12)==1,'owned fixed port pointer'
    for name in NAMES+['port']:
        if name=='pixels':continue # NewGWorld pixel contents are uninitialized, not a frame.
        normalized=[]
        for side in ('reference','native'):
            data=bytearray(captures[side][name])
            for at in POINTERS.get(name,{}):data[at:at+4]=bytes(4)
            if name in ('ctable','device-inverse'):data[:4]=bytes(4)
            if name=='device-inverse':data=data[:4364] # Exclude undefined tail scratch bytes.
            normalized.append(data)
        assert normalized[0]==normalized[1],'paired '+name+' defined bytes'
    if device_table:
        from check_native_driver import check as startup_check
        startup_check(native,native_status)
        print('PASS paired device-table NewGWorld: 27 owned handles, exact unchanged colour table, 78048 pixel bytes, all defined records and inverse entries')
    else:
        print('PASS paired NewGWorld: 27 owned handles, port/PixMaps/patterns/device, 4096 inverse entries and collision links, exact colour copy, 261452 pixel bytes; '+one(native,r'GW_NEXT (state=3 trap=A8EC selector=FFFFFFFF segment=10 offset=24D2 manager=QUICKDRAW routine=COPYBITS windows=(?:128|154) services=(?:463/463|471/471))'))


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('reference',type=Path);p.add_argument('native',type=Path)
    p.add_argument('--reference-status',type=int,required=True);p.add_argument('--native-status',type=int,required=True)
    p.add_argument('--resource',type=Path,default=Path('tmp/runtime-data/Alone In The Dark'))
    p.add_argument('--folder',type=Path,default=Path('tmp'))
    p.add_argument('--device-table',action='store_true')
    a=p.parse_args();check(a.reference.read_text(),a.native.read_text(),a.reference_status,a.native_status,a.resource,a.folder,a.device_table)
