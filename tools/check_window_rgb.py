#!/usr/bin/env python3
"""Check main-device window RGB matching and paired original state transitions."""
import argparse, os, re, struct, subprocess
import local_temp as tempfile
from pathlib import Path
from check_rgb_colors import check,ROOT,rows
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('reference',type=Path);p.add_argument('--status',type=int,required=True)
p.add_argument('--native',type=Path);p.add_argument('--native-status',type=int)
p.add_argument('--helper',action='store_true');a=p.parse_args()
try:
    text=a.reference.read_text();reference=check(text,a.status,'reference',True)
    inv=(ROOT/'tmp/window-rgb-reference-inverse.bin').read_bytes()
    device=re.findall(r'^RGB_DEVICE handle=([0-9A-F]+) body=([0-9A-F]+) inverse=([0-9A-F]+) resolution=(\d+) seed=([0-9A-F]+) tableSeed=([0-9A-F]+)$',text,re.M)
    if len(device)!=1 or device[0][3]!='4' or len(inv)!=4620:raise ValueError('main device capture')
    for _,r in reference:
        if int(r['a1'],16)!=int(device[0][2],16)+4102:raise ValueError('reference inverse pointer')
    if a.helper:
        inputs=[]
        for _,r in reference:
            values=struct.unpack('>3H',bytes.fromhex(r['rgb']))
            index=int(r['fore' if r['trap']=='AA14' else 'back'],16)
            inputs.append(' '.join(f'{v:x}' for v in (*values,index)))
        with tempfile.TemporaryDirectory(prefix='aitd-window-rgb-') as work:
            work=Path(work);lookup=work/'lookup';builder=work/'builder';out=work/'inverse.bin'
            for source,target in [('test_rgb_lookup.cpp',lookup),('test_gworld8.cpp',builder)]:
                subprocess.run([os.environ.get('HOST_CXX','c++'),'-std=c++17','-Wall','-Wextra','-Werror','-fsanitize=address,undefined',str(ROOT/'tools'/source),'-o',str(target)],check=True)
            subprocess.run([str(builder),str(ROOT/'tmp/window-rgb-reference-clut.bin'),str(out)],check=True,timeout=30)
            if out.read_bytes()[:4364]!=inv[:4364]:raise ValueError('built inverse table/collision links')
            subprocess.run([str(lookup),str(ROOT/'tmp/window-rgb-reference-clut.bin'),str(out)],input='\n'.join(inputs)+'\n',text=True,check=True,timeout=30)
    if a.native:
        text=a.native.read_text();native=check(text,a.native_status,'native',True)
        from check_native_driver import check as startup
        startup(text,a.native_status)
        for (e,r),(me,mr) in zip(native,reference):
            for k in ('rgb','fore','back','fields'):
                if e[k]!=me[k] or r[k]!=mr[k]:raise ValueError('paired '+k)
        colors=(ROOT/'tmp/window-rgb-native-clut.bin').read_bytes()
        if colors!=(ROOT/'tmp/window-rgb-native-clut-before.bin').read_bytes() or colors[4:]!=(ROOT/'tmp/window-rgb-reference-clut.bin').read_bytes()[4:]:raise ValueError('preserved/paired device palette')
        actual=(ROOT/'tmp/window-rgb-native-inverse.bin').read_bytes()
        if len(actual)!=4620 or actual[:4]!=colors[:4] or actual[4:4364]!=inv[4:4364]:raise ValueError('native inverse table')
        pointer=re.findall(r'^WRGB_INVERSE valid=1 base=([0-9A-F]+)$',text,re.M)
        if len(pointer)!=1 or any(int(r['a1'],16)!=int(pointer[0],16)+4102 for _,r in native):raise ValueError('native inverse pointer')
    print('PASS window RGB: original calls, port/index mutations, unchanged palette/patterns, measured inverse table and ABI')
except (ValueError,OSError,KeyError) as e:raise SystemExit('FAIL window RGB: '+str(e))
