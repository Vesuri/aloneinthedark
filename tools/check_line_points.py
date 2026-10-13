#!/usr/bin/env python3
"""Check real assembly particle calls: complete pixels, port and trap ABI."""
import argparse,re,struct
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('log',type=Path);p.add_argument('--status',type=int,required=True)
p.add_argument('--folder',type=Path,default=Path('tmp/line-points'));a=p.parse_args();text=a.log.read_text()
assert a.status==0 and 'PASS native assembly particle points' in text
assert not re.search('FAIL|TIMEOUT|Error in|Program received signal',text)
rows=re.findall(r'^POINTABI_(ENTER|RETURN) (.+)$',text,re.M);assert len(rows)==64
visible=0
for i in range(32):
    n=i+1;e,r=[dict(re.findall(r'(\w+)=(\w+)',rows[2*i+j][1])) for j in range(2)]
    assert rows[2*i][0]=='ENTER' and rows[2*i+1][0]=='RETURN'
    assert int(e['n'])==int(r['n'])==n and int(r['sp'],16)==int(e['sp'],16)+4
    for k in e:
        if k not in ('n','sp'):assert e[k]==r[k],(n,k)
    def read(phase,kind):return (a.folder/f'{n}-{phase}-{kind}.bin').read_bytes()
    for kind in ('port','pm','region24','region28'):assert read('enter',kind)==read('return',kind)
    port=read('enter','port');pm=read('enter','pm');before=read('enter','pixels');after=read('return','pixels')
    mt,ml,mb,mr=struct.unpack_from('>4h',pm,6);stride=int.from_bytes(pm[4:6],'big')&0x3fff
    y,x,h,w=struct.unpack_from('>4h',port,48);ink=int.from_bytes(port[80:84],'big');assert ink<256
    assert len(before)==len(after)==stride*(mb-mt)
    t,l,b,r=y,x,y+h,x+w
    for limits in (pm[6:14],port[16:24],read('enter','region24')[2:],read('enter','region28')[2:]):
        a0,a1,a2,a3=struct.unpack('>4h',limits);t=max(t,a0);l=max(l,a1);b=min(b,a2);r=min(r,a3)
    expected=bytearray(before)
    for yy in range(t,b):
        for xx in range(l,r):expected[(yy-mt)*stride+xx-ml]=ink
    assert expected==after,(n,'pixels');visible+=before!=after
assert visible>0
print(f'PASS 32 assembly particle calls: {visible} visible, exact full buffers/ports, 13 registers, CCR and stack')
