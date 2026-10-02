#!/usr/bin/env python3
"""Verify complete native demo frames against matched-input Mac renderer runs."""
import argparse
import hashlib
import re
import struct
from pathlib import Path
from check_demo_frames import records
from check_aga_capture import check_frame, read, require

ROOT = Path(__file__).resolve().parents[1]


def check(native, native_status, replays, statuses, folder):
    captures = records(native, native_status, True, folder)
    transfer = read(folder, 'video-transfer-lut16.bin', 65536)
    require(hashlib.sha256(transfer).hexdigest() ==
            'bf0a6433c155a61989e5dc0571bae1357066ab476a24d0afaf2e2aa7094fe2aa',
            'colour transfer reference')
    for index, (kind, camera, actor_id, model_id, size, slot) in enumerate((
            ('car', 0, 286, 266, 6452, 0), ('frog', 3, 289, 267, 2040, 2))):
        row, prefix, world, pixels, clut = captures[index]
        text = replays[index]
        require(statuses[index] == 0 and not re.search(
            r'FAIL|TIMEOUT|Error in|LUA ERROR|Program received signal', text),
            kind+' replay completion')
        require(text.count('PASS original '+kind+
            ' render with captured native model and transform inputs') == 1 and
            text.count('Exited via the debugger') == 1, kind+' positive replay exit')
        pairs = re.findall(r'^DEMO_RENDER_PAIR kind='+row[0]+
                           r' renderFrame=(\d+) captureFrame=(\d+)$', native, re.M)
        require(bool(pairs) and int(pairs[-1][0])+1 == int(pairs[-1][1]) == int(row[1]),
                kind+' actual draw immediately precedes captured frame')
        args = read(folder, prefix+'-render-args.bin', 16)
        actor = read(folder, prefix+'-render-actor.bin', 160)
        model = read(folder, prefix+'-render-body.bin', size)
        draw_world = read(folder, prefix+'-render-a5.bin', 79392)
        word = lambda offset: struct.unpack_from('>h', actor, offset)[0]
        require((word(0), word(2)) == (actor_id, model_id), kind+' draw identity')
        require(model[:2] == b'\0\3' and model[14:16] == b'\0\12', kind+' model layout')
        start = 75616-0xb292+slot*160
        require(draw_world[start:start+160] == actor, kind+' actual draw actor/world')
        require(struct.unpack_from('>H', draw_world, 75616-0xcd68)[0] == 0 and
                struct.unpack_from('>H', draw_world, 75616-0xcd70)[0] == camera,
                kind+' draw camera matches presented scene')
        values = [(word(p)+word(s)) & 65535 for p, s in ((0x22,0x5a),(0x24,0x5c),(0x26,0x5e))]
        values += [word(p) & 65535 for p in (0x28,0x2a,0x2c)]
        require(args[:12] == struct.pack('>6H', *values), kind+' actual transform arguments')
        inputs = re.findall(r'^REPLAY_MODEL_INPUT kind='+kind+
                            r' args=([0-9A-F]{32}) body=([0-9A-F]{128})$', text, re.M)
        require(len(inputs) == 1, kind+' replay input record')
        replay_args, header = map(bytes.fromhex, inputs[0])
        require(replay_args[:12] == args[:12], kind+' replay transform equality')
        # The renderer skips bytes 16..25: retain the Mac allocation's animation
        # pointer/time header while the fixture copies the native model geometry.
        require(header[:16]+header[26:] == model[:16]+model[26:64], kind+' replay model header')
        replay_prefix = 'demo-reference-'+kind+'-model-replay'
        reference = read(folder, replay_prefix+'-screen.bin', 307200)
        reference_clut = read(folder, replay_prefix+'-clut.bin', 2056)
        reference_world = read(folder, replay_prefix+'-a5.bin', 79392)
        require(struct.unpack_from('>H', reference_world, 75616-0xcd68)[0] == 0 and
                struct.unpack_from('>H', reference_world, 75616-0xcd70)[0] == camera,
                kind+' replay scene')
        require(all(clut[10+i*8:16+i*8] == reference_clut[10+i*8:16+i*8]
                    for i in range(256)), kind+' all 256 palette colours')
        changes = sum(pixels[(y+150)*640+x+160] != reference[(y+150)*640+x+160]
                      for y in range(200) for x in range(320))
        require(changes == 0, f'{kind}: {changes} unexplained replay pixels')
        publications = re.findall(r'^DEMO_PUBLICATION kind='+row[0]+
            r' front=([0-9A-F]+) queued=(\d+) presented=(\d+) pending=(\d+)'
            r' pixelsDirty=(\d+) rects=(\d+) control=([0-9A-F]+) inverse=([01])'
            r' left=(-?\d+) top=(-?\d+)$', native, re.M)
        require(bool(publications), kind+' publication record')
        p = publications[-1]
        require(int(p[1]) > 0 and p[1] == p[2] and p[3:7] == ('0','0','0','010F'),
                kind+' complete pointer-mode publication')
        require(read(folder, prefix+'-published-screen.bin', 307200) == pixels and
                read(folder, prefix+'-published-clut.bin', 2056) == clut,
                kind+' unchanged logical frame through publication')
        masks = struct.unpack('>16H', read(folder, prefix+'-inversion.bin', 32))
        overlay = (int(p[8]), int(p[9]), masks) if p[7] == '1' else None
        check_frame(folder, prefix, pixels, clut, 160, 150, int(p[0],16), transfer, 1, overlay)
        print(f'PASS {kind}: actual draw inputs, 64000 Mac pixels, 256 colours and native AGA publication')
    print('PASS matched-input car/frog frame fidelity; natural sequence acceptance is separate')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('native', type=Path)
    parser.add_argument('car', type=Path)
    parser.add_argument('frog', type=Path)
    parser.add_argument('--native-status', type=int, required=True)
    parser.add_argument('--car-status', type=int, required=True)
    parser.add_argument('--frog-status', type=int, required=True)
    parser.add_argument('--folder', type=Path, default=ROOT/'tmp')
    args = parser.parse_args()
    try:
        check(args.native.read_text(), args.native_status,
              [args.car.read_text(), args.frog.read_text()],
              [args.car_status, args.frog_status], args.folder)
    except (OSError, ValueError, struct.error) as error:
        raise SystemExit('FAIL demo model replay: '+str(error))
