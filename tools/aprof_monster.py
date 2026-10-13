"""Event-segmented monster trace decoding and repeatability checks.

Imported by aprof_report; inputs and derived reports stay in tmp/aprof.
"""
import csv
import json
import re
import shutil
import struct

PHASES = ('attic', 'entry', 'approach', 'fight')
FRAME = struct.Struct('>IIIHHhhhhHH')
KEYS = ('scene', 'ticks', 'effects', 'fields', 'song', 'carnby', 'monster',
        'monster_1c', 'monster_20', 'room', 'camera')
# A named one-off is removed with all descendants, never twice. Camera rebuild
# includes original background decompression; Dan2 is the song-change wrapper.
ONE_OFFS = ('Dark2+$5D30', 'Dan2+$1B22')
STALL_FIELDS = 25  # >=0.5 s on the pinned PAL configuration


def decode_frames(data):
    if not data or len(data) % FRAME.size:
        raise ValueError('truncated or empty monster frame buffer')
    rows = [dict(zip(KEYS, values)) for values in FRAME.iter_unpack(data)]
    for i, r in enumerate(rows):
        r['delta_fields'] = (r['fields'] - rows[i-1]['fields']) & 65535 if i else 0
        if i and (r['scene'] != rows[i-1]['scene'] + 1 or not r['delta_fields']):
            raise ValueError('missing, duplicate or nonprogressing monster frame')
    return rows


def phases_from_log(text, rows):
    starts, ends, chunks = {}, {}, {}
    current = None
    for line in text.splitlines():
        m = re.fullmatch(r'PHASE_(START|END) (\w+) row=(\d+)', line)
        if m:
            kind, phase, index = m.groups()
            if phase not in PHASES:
                raise ValueError('unknown monster phase')
            dest = starts if kind == 'START' else ends
            if phase in dest:
                raise ValueError('duplicate monster phase')
            dest[phase] = int(index)
            if kind == 'START':
                current = phase
                chunks[phase] = []
        if current:
            chunks[current].append(line)
    if set(starts) != set(PHASES) or set(ends) != set(PHASES) or 'COMPLETE' not in text.splitlines():
        raise ValueError('incomplete monster cycle')
    expected_start = 0
    for phase in PHASES:
        a, b = starts[phase], ends[phase]
        if a != expected_start or not a < b < len(rows):
            raise ValueError('noncontiguous monster phases')
        expected_start = b
    if expected_start != len(rows)-1 or rows[0]['scene'] != 200:
        raise ValueError('wrong monster trace endpoints')
    initial = rows[0]
    if (initial['song'], initial['carnby'], initial['monster'], initial['room']) != (137, 4, -1, 0):
        raise ValueError('wrong initial attic state (fresh Carnby game required)')
    if rows[ends['attic']]['song'] != 136 or rows[ends['entry']]['monster'] == -1:
        raise ValueError('missing MONSTER song or active monster')
    if rows[ends['approach']]['carnby'] != 237 or rows[ends['fight']]['song'] != 131:
        raise ValueError('missing first hit or death song')
    return [(phase, starts[phase], ends[phase], chunks[phase]) for phase in PHASES]


def signature(row):
    return {k: row[k] for k in ('song', 'effects', 'carnby', 'monster', 'monster_1c', 'monster_20', 'room', 'camera')}


def split(name, out):
    text = (out / f'{name}.log').read_text(errors='replace')
    configs = [l for l in text.splitlines() if l.startswith('CONFIG ')]
    if (len(configs) != 1 or 'CONFIG a4000-030-reference ' not in configs[0]
            or 'video=PAL' not in configs[0] or 'frequency_hz=15667200' not in configs[0]):
        raise ValueError('monster benchmark requires pinned reference-68030 PAL configuration')
    if 'MONSTER_CONFIG fixed_rng=1 deterministic=1 start_scene=200' not in text.splitlines():
        raise ValueError('missing deterministic monster configuration')
    rows = decode_frames((out / f'{name}.frames.bin').read_bytes())
    phases = phases_from_log(text, rows)
    stops = re.findall(r'^WINDOW_FRAME_STOPS (\d+)$', text, re.M)
    if len(stops) != 1:
        raise ValueError('missing observer stop count')
    result = {'window_frame_stops': int(stops[0]), 'name': name, 'config': configs[0], 'stall_threshold_fields': STALL_FIELDS, 'phases': []}
    with (out / f'{name}.frames.csv').open('w') as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0]))
        writer.writeheader(); writer.writerows(rows)
    for phase, a, b, chunk in phases:
        first, last = rows[a], rows[b]
        fields = sum(r['delta_fields'] for r in rows[a+1:b+1])
        n = b-a
        stalls = []
        for i in range(a+1, b+1):
            r, prev = rows[i], rows[i-1]
            if r['delta_fields'] < STALL_FIELDS:
                continue
            event = ('song' if r['song'] != prev['song'] else
                     'camera' if (r['room'], r['camera']) != (prev['room'], prev['camera']) else 'other')
            stalls.append(dict(scene=r['scene'], fields=r['delta_fields'], event=event,
                               before=signature(prev), after=signature(r)))
        record = dict(phase=phase, frames=n, fields=fields, start=signature(first), end=signature(last),
                      stalls=stalls, steady_frames=n-len(stalls),
                      steady_fields=fields-sum(r['fields'] for r in stalls))
        result['phases'].append(record)
        metadata = [configs[0]] + chunk + [f'DELTA fields={fields} frames={n} steps={n}',
                    f'ROOM start={first["room"]}/{first["camera"]} stop={last["room"]}/{last["camera"]}']
        (out / f'{name}-{phase}.log').write_text('\n'.join(metadata)+'\n')
        shutil.copyfile(out / f'{name}.elf', out / f'{name}-{phase}.elf')
    return result


def compare(a, b, tolerance=0.02):
    """Compare event states and ordered stall identities, not scene numbers."""
    errors = []
    if a.get('window_frame_stops', 0) or b.get('window_frame_stops', 0):
        errors.append('observer-bias control is not an acceptance measurement')
    if a['config'] != b['config']:
        errors.append('CPU/video configuration differs')
    for x, y in zip(a['phases'], b['phases']):
        phase = x['phase']
        if any(x[k] != y[k] for k in ('phase', 'start', 'end')):
            errors.append(f'{phase}: phase states differ')
        if abs(x['fields']-y['fields']) > tolerance*x['fields']:
            errors.append(f'{phase}: fields differ by more than {100*tolerance:g}%')
        key = lambda r: (r['event'], r['before'], r['after'])
        if list(map(key, x['stalls'])) != list(map(key, y['stalls'])):
            errors.append(f'{phase}: stall list differs')
    if len(a['phases']) != 4 or len(b['phases']) != 4:
        errors.append('incomplete phase list')
    return errors


def run(name, out, profile_type, steady, compare_name=None):
    result = split(name, out)
    for phase in result['phases']:
        p = profile_type(f'{name}-{phase["phase"]}')
        phase['steady_cpu'] = steady(p, ONE_OFFS, phase['steady_frames']) if phase['steady_frames'] else None
        cadence = f'{phase["steady_fields"]/phase["steady_frames"]:.3f}' if phase['steady_frames'] else 'n/a'
        print(f'{phase["phase"]}: {phase["frames"]} frames, {phase["fields"]} fields; '
              f'steady {cadence} fields/frame')
        for r in phase['stalls']:
            print(f'  stall scene {r["scene"]}: {r["fields"]} fields ({r["fields"]/50:.2f}s) '
                  f'{r["event"]} song={r["after"]["song"]} room/camera={r["after"]["room"]}/{r["after"]["camera"]}')
    (out / f'{name}.summary.json').write_text(json.dumps(result, indent=2)+'\n')
    if compare_name:
        other = json.loads((out / f'{compare_name}.summary.json').read_text())
        errors = compare(other, result)
        if errors:
            raise ValueError('; '.join(errors))
        print(f'PASS repeatability {compare_name} / {name}: same phase states and stall list; fields within 2%')
