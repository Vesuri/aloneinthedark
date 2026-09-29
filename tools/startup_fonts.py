"""Build explicit styled placeholder NFNTs from owned glyphs and measured metrics."""
import json
from pathlib import Path
import struct
ROOT=Path(__file__).resolve().parents[1]
def definitions():
    return json.loads((ROOT/'resources/startup-fonts.json').read_text())['faces']
def bitmap(face):
    glyphs=json.loads((ROOT/'resources/placeholder-font.json').read_text())['glyphs']
    shapes=[glyphs[chr(c).upper()] for c in range(32,127)]+[[31,17,17,17,17,17,31]]
    ascent,descent,maximum=face['ascent'],face['descent'],face['widMax']
    # Other advances are explicit placeholder design, not measured Mac widths.
    advances=[face['spaceWidth'] if c==32 else maximum if c in (64,77,87,127) else face['zeroWidth'] for c in range(32,128)]
    spans=[0 if n==0 else max(1,w-1) for n,w in enumerate(advances)]
    locations=[0]
    for width in spans:locations.append(locations[-1]+width)
    row_words=(locations[-1]+15)//16;height=ascent+descent
    bits=bytearray(row_words*2*height)
    for n,(shape,width) in enumerate(zip(shapes,spans)):
        for y in range(ascent):
            row=shape[y*7//ascent]
            for x in range(width):
                slant=(ascent-1-y)*min(2,width//4)//ascent if face['style']&2 else 0
                sx=(x-slant)*5//max(1,width-min(2,width//4) if face['style']&2 else width)
                on=0<=sx<5 and bool(row&(16>>sx))
                if face['style']&1 and 0<sx<=5:on|=bool(row&(16>>(sx-1)))
                if on:
                    bit=locations[n]+x;bits[y*row_words*2+bit//8]|=128>>(bit%8)
    loc=struct.pack('>'+str(len(locations))+'H',*locations)
    widths=struct.pack('>'+str(len(advances)+1)+'H',*advances,65535)
    header=struct.pack('>HHHHhhHHHHHHH',0x1000,32,126,maximum,0,-descent,max(spans),height,(26+len(bits)+len(loc)-16)//2,ascent,descent,face['leading'],row_words)
    return header+bits+loc+widths

def resources():
    faces=definitions();families=[];bitmaps=[]
    for family in (0,3,21):
        rows=[(i,face) for i,face in enumerate(faces) if face['family']==family]
        maxima=[max(face[k]*4096//face['size'] for _,face in rows) for k in ('ascent','descent','leading','widMax')]
        header=struct.pack('>8H',0x4000,family,32,126,*maxima)+bytes(34)+struct.pack('>HH',2,len(rows)-1)
        associations=b''.join(struct.pack('>HHH',face['size'],face['style'],256+i) for i,face in rows)
        families.append((b'FOND',family,'',header+associations))
        bitmaps.extend((b'NFNT',256+i,'',bitmap(face)) for i,face in rows)
    return families,bitmaps
