#!/usr/bin/env python3
"""Check actual native thin-line calls against the original-paired fixed-point rule."""
import argparse,re,struct
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('log',type=Path);p.add_argument('--status',type=int,required=True)
p.add_argument('--folder',type=Path,default=Path('tmp/thin-lines'));a=p.parse_args();text=a.log.read_text()
assert a.status==0 and text.count('PASS native assembly thin lines')==1
assert not re.search('FAIL|TIMEOUT|Error in|Program received signal',text)
rows=re.findall(r'^THINABI_(ENTER|RETURN) (.+)$',text,re.M);assert len(rows)==64
ends=re.findall(r'^THIN_TARGET n=(\d+) op=([A-F0-9]+) target=([A-F0-9]+)$',text,re.M);assert len(ends)==32
visible=0;ops={0xa891:0,0xa892:0}
for i in range(32):
    n=i+1;e,r=[dict(re.findall(r'(\w+)=(\w+)',rows[2*i+j][1])) for j in range(2)]
    assert rows[2*i][0]=='ENTER' and rows[2*i+1][0]=='RETURN'
    assert int(e['n'])==int(r['n'])==n and int(r['sp'],16)==int(e['sp'],16)+4
    for k in e:
        if k not in ('n','sp'):assert e[k]==r[k],(n,k)
    assert int(ends[i][0])==n;op=int(ends[i][1],16);ops[op]+=1
    target=int(ends[i][2],16).to_bytes(4,'big')
    def read(phase,kind):return (a.folder/f'{n}-{phase}-{kind}.bin').read_bytes()
    for kind in ('pm','region24','region28'):assert read('enter',kind)==read('return',kind)
    port=read('enter','port');pm=read('enter','pm');before=read('enter','pixels');after=read('return','pixels')
    wanted=bytearray(port);wanted[48:52]=target;assert wanted==read('return','port')
    y0,x0,h,w=struct.unpack_from('>4h',port,48);y1,x1=struct.unpack('>hh',target);assert h==w==1
    mt,ml,mb,mr=struct.unpack_from('>4h',pm,6);stride=int.from_bytes(pm[4:6],'big')&0x3fff
    ink=int.from_bytes(port[80:84],'big');assert ink<256
    assert len(before)==len(after)==stride*(mb-mt)
    t,l,b,r=mt,ml,mb,mr
    for limits in (port[16:24],read('enter','region24')[2:],read('enter','region28')[2:]):
        tt,ll,bb,rr=struct.unpack('>4h',limits);t=max(t,tt);l=max(l,ll);b=min(b,bb);r=min(r,rr)
    expected=bytearray(before)
    if y1<y0:x0,x1,y0,y1=x1,x0,y1,y0
    delta=x1-x0;dx=abs(delta);dy=y1-y0
    slope=(dx<<16)//dy if dy else 0
    start=32768+slope//2-(delta<0 and dx>dy)
    for row in range(dy+1):
        if not t<=y0+row<b:continue
        if not dx or not dy:lo,hi=min(x0,x1),max(x0,x1)+1
        else:
            begin=((start-slope if dx>dy else start)+row*slope)//65536
            if dx==dy:begin=row
            end=(start+row*slope)//65536 if dx>dy else begin+1
            begin=max(0,begin);end=min(dx+1,end)
            lo,hi=(x0-end+1,x0-begin+1) if delta<0 else (x0+begin,x0+end)
        lo=max(lo,l);hi=min(hi,r)
        for x in range(lo,hi):expected[(y0+row-mt)*stride+x-ml]=ink
    assert expected==after,(n,'pixels');visible+=before!=after
assert visible>0 and ops=={0xa891:16,0xa892:16}
print(f'PASS 32 thin-line calls: {visible} visible, full buffers/ports, 13 registers, CCR and stack')
