#!/usr/bin/env python3
"""Verify installed placeholder definitions against independent Mac measurements."""
import os
from pathlib import Path
import struct
import subprocess
import tempfile
from startup_fonts import resources,definitions
from check_font_metrics import CASES,STYLES
ROOT=Path(__file__).resolve().parents[1]
def main():
    faces=definitions();expected=[]
    for family,size,values in CASES:
        for style,metrics in zip(STYLES,values):expected.append((family,size,style,*metrics))
    actual=[tuple(face[k] for k in ('family','size','style','ascent','descent','widMax','leading','zeroWidth','spaceWidth')) for face in faces]
    assert actual==expected
    families,bitmaps=resources()
    with tempfile.TemporaryDirectory(prefix='aitd-startup-font-') as work:
        work=Path(work)
        for kind,rid,_,body in families+bitmaps:(work/(kind.decode().lower()+str(rid))).write_bytes(body)
        (work/'system-widths').write_bytes(bytes(faces[0]['printableWidths']))
        (work/'cases').write_bytes(b''.join(struct.pack('>10H',f,sz,st,256+i,*m) for i,(f,sz,st,*m) in enumerate(expected)))
        exe=work/'check'
        subprocess.run([os.environ.get('HOST_CXX','c++'),'-std=c++17','-Wall','-Wextra','-Werror','-fsanitize=address,undefined',str(ROOT/'tools/test_startup_fonts.cpp'),'-o',str(exe)],check=True)
        subprocess.run([str(exe),str(work)],check=True,timeout=60)
if __name__=='__main__':main()
