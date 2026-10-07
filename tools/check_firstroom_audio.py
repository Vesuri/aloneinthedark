#!/usr/bin/env python3
"""Compare first-room effect packets by their captured game trigger, not wall-clock counts."""
import argparse
from collections import Counter
from pathlib import Path
import re
import struct

FOOTSTEPS = {'171F8B11', '53D73494', '4873D55C', 'B3655384', '2C00645F', '8767831D'}
DOOR = '1A9EDE1F'
AMBIENT = {'E237BE27', '235E2009', 'F09B4483'}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def actors(path):
    data = path.read_bytes()
    require(len(data) == 8000, 'complete 50-actor snapshot')
    return [tuple(struct.unpack_from('>h', data, i*160+offset)[0]
                  for offset in (0, 2, 0x1c, 0x20, 0x2e, 0x30, 0x34, 0x3e, 0x4a, 0x4e))
            for i in range(50)]


def records(folder, native):
    text = (folder / ('capture.log' if native else 'run.log')).read_text()
    status = int((folder / 'exit-status').read_text())
    marker = ('PASS SOUTH ROOM first-floor room5 manual gameplay through ordinary keys'
              if native else 'PASS original first-room audio route')
    require(status == 0 and text.count(marker) == 1, 'completed route')
    require(not re.search(r'FAIL|TIMEOUT|LUA ERROR|Error in|Program received signal', text), 'clean route')
    result = []
    started = native
    for line in text.splitlines():
        if line.startswith('EXPLORE phase=initial '):
            started = True
        prefix = 'AUDIO_NATIVE_EFFECT ' if native else 'AUDIO_EFFECT '
        if not line.startswith(prefix) or not started:
            continue
        values = dict(re.findall(r'(\w+)=([^ ]+)', line))
        event = int(values['event'])
        if native:
            pcm = (folder / f'effect-{event}.bin').read_bytes()
            require(len(pcm) == int(values['bytes']), 'complete native source PCM')
            digest = 2166136261
            for byte in pcm:
                digest = ((digest ^ byte)*16777619) & 0xffffffff
            values['pcm'] = f'{digest:08X}'
        packet = tuple(values[k] for k in ('pcm', 'bytes', 'rate', 'loop', 'id'))
        snapshot = actors(folder / (f'effect-{event}-actors.bin' if native else f'audio-effect-{event}-actors.bin'))
        hero = snapshot[1]
        identity = values['pcm']
        if identity in FOOTSTEPS:
            require(hero[0] == 1 and hero[1] in (11, 12) and hero[9] == 1, 'hero animation-frame event')
            trigger = ('step', hero[6], hero[7], hero[8])
        elif identity == DOOR:
            door = snapshot[17]
            require((door[0], door[1], door[6]) in ((24, -1, 27), (31, -1, 38)), 'measured door object/life trigger')
            trigger = ('door', door[0], door[6])
        elif identity in AMBIENT:
            require(any(a[0] in (278, 279) and a[1] == -1 and a[6] in (528, 529) for a in snapshot), 'ambient script present')
            trigger = ('ambient',)
        else:
            raise ValueError('unclassified effect ' + identity)
        result.append((event, packet, trigger, hero[2:6]))
    require(result, 'nonempty effect trace')
    return result


def check(mac, native):
    reference, actual = records(mac, False), records(native, True)
    prototypes = {(packet, trigger) for _, packet, trigger, _ in reference if trigger != ('ambient',)}
    for event, packet, trigger, position in actual:
        if trigger == ('ambient',):
            continue
        require((packet, trigger) in prototypes, f'native event {event}: original packet/animation trigger')
    ref_doors = [(packet, trigger) for _, packet, trigger, _ in reference if trigger[0] == 'door']
    actual_doors = [(packet, trigger) for _, packet, trigger, _ in actual if trigger[0] == 'door']
    require(len(ref_doors) == 2 and actual_doors == ref_doors, 'both exact door events in order')
    ref_stairs = [(packet, trigger) for _, packet, trigger, _ in reference if trigger[:2] == ('step', 550)]
    actual_stairs = [(packet, trigger) for _, packet, trigger, _ in actual if trigger[:2] == ('step', 550)]
    require(len(ref_stairs) == 10 and actual_stairs == ref_stairs, 'ten exact stair events in order')
    for name, rows in [('Mac', reference), ('Amiga', actual)]:
        counts = Counter(trigger[0] for _, _, trigger, _ in rows)
        print(name, dict(counts))
    print('PASS first-room movement/door audio: exact packets by animation/object trigger, both doors and ten stair events')
    print('Ambient events are classified separately; this check does not establish paired ambient playback or identical route step counts.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mac', type=Path)
    parser.add_argument('native', type=Path)
    args = parser.parse_args()
    try:
        check(args.mac, args.native)
    except (ValueError, OSError, KeyError, struct.error) as error:
        raise SystemExit('FAIL first-room audio: ' + str(error))
