"""Port-owned 14-point bitmap placeholder, encoded as classic FOND/NFNT."""
import json
from pathlib import Path
import struct

SOURCE=Path(__file__).resolve().parents[1]/'resources/placeholder-font.json'
FAMILY=20
BITMAP=128

def build():
    glyphs=json.loads(SOURCE.read_text())['glyphs']
    for char,rows in glyphs.items():
        if len(char)!=1 or len(rows)!=7 or any(type(v)!=int or not 0<=v<32 for v in rows):
            raise ValueError('FONT / INVALID SOURCE GLYPH')
    # ASCII and the reached MacRoman symbols; gaps use the missing box.
    missing=[31,17,17,17,17,17,31]
    shapes=[glyphs.get(bytes([c]).decode("mac_roman").upper(),missing)
            for c in range(32,251)]+[missing]
    width=5*len(shapes);row_words=(width+15)//16;height=14
    bitmap=bytearray(row_words*2*height)
    for n,shape in enumerate(shapes):
        # Keep the capital ink within the measured Times caption band:
        # baseline-10 through baseline-1, with unchanged ascent/descent.
        for y in range(2,12):
            row=shape[(y-2)*7//10]
            for x in range(5):
                if row&(16>>x):
                    bit=n*5+x;bitmap[y*row_words*2+bit//8]|=128>>(bit%8)
    locations=struct.pack('>'+str(len(shapes)+1)+'H',*(n*5 for n in range(len(shapes)+1)))
    width_offset=26+len(bitmap)+len(locations)
    header=struct.pack('>HHHHhhHHHHHHH',0x3000,32,250,6,0,-2,5,height,(width_offset-16)//2,12,2,0,row_words)
    nfnt=header+bitmap+locations+struct.pack('>H',6)*len(shapes)+b'\xff\xff'
    # FamRec (52 bytes), no optional tables; one plain 14-point association.
    fond=struct.pack('>8H',0xc000,FAMILY,32,250,12*4096//14,2*4096//14,0,6*4096//14)
    fond+=bytes(34)+struct.pack('>HHHHH',2,0,14,0,BITMAP)
    assert len(fond)==60
    return fond,nfnt
