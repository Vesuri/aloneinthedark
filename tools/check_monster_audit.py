#!/usr/bin/env python3
"""Read a debugger-free monster-whd.bin or monster-amigaos.bin audit.

The report records raw CACR and Exec AttnFlags; emulator results must never be
labelled real hardware results. No external profile or original game data is needed.
"""
import argparse
import json
from pathlib import Path
import struct
from aprof_monster import PHASES, FRAME, decode_frames, phases_from_log, signature

HEADER = struct.Struct('>16I')


def read_audit(data):
    if len(data) < HEADER.size:
        raise ValueError('truncated audit header')
    h = HEADER.unpack_from(data)
    if h[:3] != (0x41495444, 0x4d4f4e31, 1):
        raise ValueError('wrong audit magic/version')
    count, phase, pal, whd, cpu, start_cacr, end_cacr, cleanup = h[3:11]
    if phase != 5 or cleanup != 1:
        raise ValueError(f'incomplete audit or failed cleanup: phase={phase}, cleanup={cleanup}')
    if not 2 <= count <= 16384 or pal not in (0,1) or whd not in (0,1):
        raise ValueError('invalid audit metadata')
    if len(data) != HEADER.size + count*FRAME.size:
        raise ValueError('truncated or trailing frame data')
    rows = decode_frames(data[HEADER.size:])
    boundaries = h[11:16]
    text = ''.join(f'PHASE_START {p} row={boundaries[i]}\nPHASE_END {p} row={boundaries[i+1]}\n'
                   for i,p in enumerate(PHASES)) + 'COMPLETE\n'
    phases_from_log(text,rows)
    hz = 50 if pal else 60
    result = dict(format=1, backend='WHDLoad' if whd else 'AmigaOS', video='PAL' if pal else 'NTSC',
                  attn_flags=cpu, cacr_start=start_cacr, cacr_end=end_cacr, phases=[])
    for i,p in enumerate(PHASES):
        a,b=boundaries[i:i+2]
        intervals=rows[a+1:b+1]
        stalls=[dict(scene=r['scene'],fields=r['delta_fields'],seconds=r['delta_fields']/hz,
                     state=signature(r)) for r in intervals if r['delta_fields'] >= hz//2]
        steady=[r['delta_fields'] for r in intervals if r['delta_fields'] < hz//2]
        fields=sum(r['delta_fields'] for r in intervals)
        result['phases'].append(dict(phase=p,frames=b-a,fields=fields,
            fields_per_frame=fields/(b-a),steady_fields_per_frame=sum(steady)/len(steady) if steady else None,
            steady_fps=hz*len(steady)/sum(steady) if steady else None,
            start=signature(rows[a]),end=signature(rows[b]),stalls=stalls))
    return result


def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('report', type=Path)
    ap.add_argument('--json', type=Path, help='optional decoded report output')
    args=ap.parse_args()
    try:
        result=read_audit(args.report.read_bytes())
    except (OSError,ValueError,struct.error) as error:
        raise SystemExit(f'FAIL monster audit: {error}')
    print(f'{result["backend"]} {result["video"]}; AttnFlags=${result["attn_flags"]:X}; '
          f'CACR=${result["cacr_start"]:08X} -> ${result["cacr_end"]:08X}')
    for p in result['phases']:
        fps=f'{p["steady_fps"]:.2f}' if p['steady_fps'] is not None else 'n/a'
        print(f'{p["phase"]}: {p["frames"]} frames / {p["fields"]} fields, '
              f'{p["fields_per_frame"]:.3f} fields/frame; nonstall {fps} FPS')
        for s in p['stalls']:
            print(f'  stall scene={s["scene"]} fields={s["fields"]} seconds={s["seconds"]:.2f} '
                  f'song={s["state"]["song"]} effects={s["state"]["effects"]}')
    if args.json:
        args.json.write_text(json.dumps(result,indent=2)+'\n')
    print('PASS complete monster audit, all four event phases and normal cleanup')


if __name__ == '__main__':
    main()
