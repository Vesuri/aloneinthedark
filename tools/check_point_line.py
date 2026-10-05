#!/usr/bin/env python3
"""Check the measured particle point against natural and matched Mac calls."""
import argparse,re
from pathlib import Path
from check_driver22 import fields,one,ROOT

def require(value,message):
    if not value:raise ValueError(message)

def check(original,paired,native,statuses,folder):
    require(all(status==0 for status in statuses),'runner statuses')
    for label,text,marker in (("Mac",original,"PASS original point line"),
                              ("paired Mac",paired,"PASS original point line"),
                              ("native",native,"PASS native point2 pixel capture and trap ABI preserved=13 result=0 stack=4")):
        require(text.count(marker)==1 and not re.search(r"FAIL|TIMEOUT|Error in|LUA ERROR|Program received signal",text),label+" normal completion")
    require(native.count('[Inferior 1 (Remote target) detached]')==1,'native detach')
    raw=(ROOT/'tmp/segments/CODE_13_Dan2').read_bytes()[0x3fe4:0x3fee]
    require(raw.hex()=='3f2effeca89342a7a892','original caller bytes')
    for text in (original,paired):
        require(one(text,r'^LINE_BYTES (\w+)$')==raw.hex().upper(),'live original caller')
        e,r=[fields(one(text,r'^LINE_'+phase+r' fixture=0 (.*)$')) for phase in ('ENTER','RETURN')]
        require(e['target']==0 and r['sp']==e['sp']+4 and r['d0']==0,'original ABI/result')
        for register in [f'd{i}' for i in range(1,8)]+[f'a{i}' for i in range(1,7)]:
            require(e[register]==r[register],'original preserved '+register)
    expected=[78*652+161,78*652+162,79*652+161,79*652+162]
    for side in ('point-reference-reference','point-paired-reference','point-native'):
        old=(folder/f'{side}-enter-pixels.bin').read_bytes();new=(folder/f'{side}-return-pixels.bin').read_bytes()
        p=(folder/f'{side}-enter-port.bin').read_bytes();q=(folder/f'{side}-return-port.bin').read_bytes()
        require(len(old)==len(new)==261452,'complete buffer extent')
        require([i for i,(a,b) in enumerate(zip(old,new)) if a!=b]==expected
                and all(new[i]==85 for i in expected),'exact four pixels and untouched padding/background')
        require(p==q and len(p)==108 and p[48:58].hex()=='004e00a1000200020008'
                and int.from_bytes(p[80:84],'big')==85,'complete port preservation and measured pen')
    require('POINT_NATIVE_INPUT bytes=261452 pen=004E00A1000200020008 fore=00000055' in paired,'matched input positive control')
    for phase in ('enter','return'):
        require((folder/f'point-native-{phase}-pixels.bin').read_bytes()==
                (folder/f'point-paired-reference-{phase}-pixels.bin').read_bytes(),'whole matched '+phase+' pixel buffer')
    print('PASS point line: original Dan2+$3FEC, exact four pixels, all 261452 paired bytes, complete port and 13-register/stack ABI preservation')

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    for name in ('original','paired','native'):
        p.add_argument(name,type=Path);p.add_argument('--'+name+'-status',type=int,required=True)
    p.add_argument('--folder',type=Path,default=ROOT/'tmp/m3-death');a=p.parse_args()
    try:check(*(getattr(a,name).read_text() for name in ('original','paired','native')),
              [getattr(a,name+'_status') for name in ('original','paired','native')],a.folder)
    except (ValueError,OSError,KeyError) as e:raise SystemExit('FAIL point line: '+str(e))
