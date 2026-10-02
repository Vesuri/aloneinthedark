#!/usr/bin/env python3
"""Check captured demo state identities, then compare logical and AGA pixels."""
import argparse
import hashlib
from pathlib import Path
import re
import struct
from check_aga_capture import check_frame, read, require

ROOT = Path(__file__).resolve().parents[1]
STATE = (r'^DEMO_STATE kind=(\w+) segment=4 offset=5658 frame=(\d+) '
         r'ticks=(\d+) random=(\d+) room=(\d+) camera=(\d+) actor0=([0-9A-F]{320})$')


def records(log, status, native, folder):
    name = 'native' if native else 'original'
    require(status == 0 and not re.search(r'FAIL|TIMEOUT|Error in|LUA ERROR|Program received signal', log), name+' completion')
    require(log.count('PASS '+name+' near car and first completed pond camera frame') == 1, name+' endpoint')
    end = '[Inferior 1 (Remote target) detached]' if native else 'Exited via the debugger'
    require(log.count(end) == 1, name+' normal exit')
    rows = re.findall(STATE, log, re.M)
    keys = ('1','2') if native else ('car','pond')
    require(rows and rows[-1][0] == keys[1] and sum(r[0] == keys[1] for r in rows) == 1, name+' pond ordering')
    require(all(r[0] in keys for r in rows), name+' capture kinds')
    selected = []
    for key, camera in zip(keys, (0,3)):
        candidates = [r for r in rows if r[0] == key]
        require(bool(candidates), name+' '+key+' missing')
        row = candidates[-1]
        require(row[3:6] == ('1','0',str(camera)), name+' original scene/entropy key')
        prefix = ('demo-native-' if native else 'demo-reference-')+key
        world = read(folder, prefix+'-a5.bin', 79392)
        actor = world[75616-0xb292:75616-0xb292+160]
        require(actor.hex().upper() == row[6], name+' actor/log identity')
        word = lambda offset: struct.unpack_from('>H',world,75616+offset)[0]
        require((word(-0xcd68),word(-0xcd70),word(-0xd8f2)) == (0,camera,0), name+' saved scene/choice')
        require(struct.unpack_from('>HH',actor) == (286,266), name+' car identity/body')
        if camera == 0:
            l,t,r,b = struct.unpack_from('>4h',actor,0x14)
            require(r-l >= 80 and l < 320 and r > 0 and t < 200 and b > 0, name+' near-camera car')
        pixels = read(folder,prefix+'-screen.bin',307200)
        clut = read(folder,prefix+'-clut.bin',2056)
        selected.append((row,prefix,world,pixels,clut))
    require(int(selected[0][0][1]) < int(selected[1][0][1]), name+' car precedes pond')
    return selected


def check(reference, reference_status, folder, native=None, native_status=None):
    original = records(reference,reference_status,False,folder)
    if native is None:
        print('PASS original demo captures: car/pond scene keys and saved actor identities')
        return
    actual = records(native,native_status,True,folder)
    pattern = (r'^DEMO_PUBLICATION kind=(\d+) front=([0-9A-F]+) queued=(\d+) '
               r'presented=(\d+) pending=(\d+) pixelsDirty=(\d+) rects=(\d+) '
               r'control=([0-9A-F]+) inverse=([01]) left=(-?\d+) top=(-?\d+)$')
    publications = re.findall(pattern,native,re.M)
    transfer = read(folder,'video-transfer-lut16.bin',65536)
    require(hashlib.sha256(transfer).hexdigest() == 'bf0a6433c155a61989e5dc0571bae1357066ab476a24d0afaf2e2aa7094fe2aa','colour transfer reference')
    differences = 0
    for ref, port in zip(original,actual):
        row,prefix,world,pixels,clut = port
        candidates = [p for p in publications if p[0] == row[0]]
        require(bool(candidates),'native publication record')
        p = candidates[-1]
        require(int(p[2]) > 0 and p[2] == p[3] and p[4:8] == ('0','0','0','010F'),'native complete pointer-mode publication')
        require(read(folder,prefix+'-published-screen.bin',307200) == pixels and
                read(folder,prefix+'-published-clut.bin',2056) == clut,
                'captured logical frame unchanged through native publication')
        masks = struct.unpack('>16H',read(folder,prefix+'-inversion.bin',32))
        overlay = (int(p[9]),int(p[10]),masks) if p[8] == '1' else None
        check_frame(folder,prefix,pixels,clut,160,150,int(p[1],16),transfer,1,overlay)
        require(all(clut[10+i*8:16+i*8] == ref[4][10+i*8:16+i*8] for i in range(256)),prefix+' paired palette')
        changed = [(x,y) for y in range(200) for x in range(320)
                   if pixels[(y+150)*640+x+160] != ref[3][(y+150)*640+x+160]]
        print(f'{prefix}: {len(changed)} differing pixels; palette and AGA publication exact')
        if changed:
            xs,ys = zip(*changed)
            print(f'  difference bounds={min(xs)},{min(ys)}..{max(xs)},{max(ys)}')
            for i in range(100):
                start = 75616-0xb292+i*160
                a,b = ref[2][start:start+160],world[start:start+160]
                if a != b and (a[:2] != b'\xff\xff' or b[:2] != b'\xff\xff'):
                    def pose(data):
                        w = lambda offset: struct.unpack_from('>h',data,offset)[0]
                        return tuple(w(offset) for offset in (0,2,0x1c,0x1e,0x20,0x2a,0x30,0x34,0x3e,0x4a,0x54,0x56,0x58))
                    print(f'  actor {i} (id,body,x,y,z,angle,room,life,animation,animationFrame,word54,word56,track): Mac={pose(a)} native={pose(b)}')
        differences += len(changed)
    require(differences == 0,'demo differences require state pairing or a measured, documented explanation')
    print('PASS paired car/pond frames: exact pixels, palettes and native publication')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('reference',type=Path)
    parser.add_argument('--reference-status',type=int,required=True)
    parser.add_argument('--native',type=Path)
    parser.add_argument('--native-status',type=int)
    parser.add_argument('--folder',type=Path,default=ROOT/'tmp')
    args = parser.parse_args()
    try:
        check(args.reference.read_text(),args.reference_status,args.folder,
              args.native.read_text() if args.native else None,args.native_status)
    except (OSError,ValueError,struct.error) as error:
        raise SystemExit('FAIL demo frames: '+str(error))
