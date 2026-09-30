#!/usr/bin/env python3
"""Compare Dark2 palette construction with the larger clut 129 source."""
import argparse,re
from pathlib import Path
from resource_fork import read_resource_fork
from check_palette import check
p=argparse.ArgumentParser(description=__doc__);p.add_argument('reference',type=Path);p.add_argument('--status',type=int,required=True);p.add_argument('--native',type=Path);p.add_argument('--native-status',type=int);p.add_argument('--ids',type=Path);p.add_argument('--ids-status',type=int);a=p.parse_args()
try:
    resources=read_resource_fork(Path('tmp/runtime-data/Alone In The Dark'))
    code=next(r.body for r in resources if r.kind==b'CODE' and r.rid==5)[0x2010:0x201e]
    if code.hex()!='42a73f3c01002f0c4878000aaa91':raise ValueError('original Dark2 caller bytes')
    clut=next(r.body for r in resources if r.kind==b'clut' and r.rid==129)
    check(a.reference.read_text(),a.status,Path('tmp'),code,clut,True,False,prefix='palette129',palette_id=3)
    if a.ids:
        text=a.ids.read_text()
        if a.ids_status!=0 or any(v in text for v in ('FAIL','Error in','timeout','unknown command')) or text.count('PASS palette creation serial after disposal')!=1 or text.count('Exited via the debugger')!=1:raise ValueError('identifier capture completion')
        rows=re.findall(r'PAL129_SERIAL n=([135]) handle=([0-9A-F]+) header=01000000/([0-9A-F]+)/00000000',text)
        if [(int(n),int(value,16)) for n,handle,value in rows]!=[(1,4),(3,4),(5,3)] or rows[0][1]!=rows[1][1] or rows[1][1]==rows[2][1]:raise ValueError('identifier slot reuse')
        for marker in ('PAL129_ORIGINAL header=01000000/00000003/00000000','PAL129_DISPOSE d0=0 mem=0','PAL129_DISPOSE_ORIGINAL d0=0 mem=0','PAL129_RETAINED header=00000004'):
            if text.count(marker)!=1:raise ValueError('identifier disposal/preservation')
    if a.native:
        text=a.native.read_text()
        check(text,a.native_status,Path('tmp'),code,clut,False,True,prefix='palette129',endpoint=False,palette_id=3)
        from check_native_driver import check as startup
        startup(text,a.native_status)
        # Private handle addresses differ; every other returned byte must match.
        ref=Path('tmp/palette129-reference-body.bin').read_bytes();native=Path('tmp/palette129-native-body.bin').read_bytes()
        if ref[:12]+ref[16:]!=native[:12]+native[16:]:raise ValueError('paired palette bytes')
        if Path('tmp/palette129-native-private.bin').read_bytes()!=bytes(4):raise ValueError('native private block')
    print('PASS palette129: original arguments/ABI, complete palette/private records, unchanged 2064-byte source, 12 Mac ownership/disposal fixtures')
except (ValueError,KeyError,OSError) as e:raise SystemExit('FAIL palette129: '+str(e))
