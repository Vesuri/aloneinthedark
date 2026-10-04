#!/usr/bin/env python3
"""Verify FIGHT resources, original preflight and complete native playback."""
import argparse
from pathlib import Path
import re
import struct
from check_driver0 import check as check_driver
from check_driver22 import one, ROOT


def require(value, message):
    if not value:
        raise ValueError(message)


def check(original, host, driver, native, statuses):
    require(all(status == 0 for status in statuses), 'runner statuses')
    for label, text, marker in (
        ('original', original, 'PASS original song preflight events=1206'),
        ('host', host, 'PASS decoded song events=1206 ticks=55680'),
        ('native', native, 'PASS SONG132 full playback, interrupt progress, effect priority, resource cleanup and original MDRV absent'),
    ):
        require(text.count(marker) == 1 and not re.search(r'FAIL|TIMEOUT|LUA ERROR|Error in|Program received signal', text), label+' completion')
    require(original.count('Exited via the debugger') == 1
            and native.count('[Inferior 1 (Remote target) detached]') == 1, 'observer exits')
    check_driver(driver, statuses[2], 132, ROOT/'tmp/m3-input/driver132-reference')
    folder = ROOT/'tmp/m3-fight'
    for label, resource in (('song', 'SONG_132'), ('midi', 'MIDI_902')):
        require((folder/f'song132-events-{label}.bin').read_bytes()
                == (folder/'inputs'/resource).read_bytes(), 'original resource '+label)
    original_rows = re.findall(r'^SONG_EVENT .*$', original, re.M)
    host_rows = re.findall(r'^SONG_EVENT .*$', host, re.M)
    require(len(original_rows) == 1206 and original_rows == host_rows, '1206 exact original/decoded events')
    require('PASS song resource graph instruments=8 samples=24' in host, 'instrument/sample preparation')
    events = list(struct.iter_unpack('>10I', (folder/'song132-native-events.bin').read_bytes()))
    expected = [tuple(int(value, 16) for value in row) for row in re.findall(
        r'^SONG_EVENT n=\d+ on=(\w+) offset=(\w+) instrument=(\w+) note=(\w+) velocity=(\w+) channel=(\w+)$', original, re.M)]
    require([row[:6] for row in events] == expected, 'complete native note/instrument/order identity')
    timing = [(int(offset,16),int(pulse,16),int(step,16)) for offset,pulse,step in re.findall(
        r'^SONG_TIMED_EVENT n=\d+ offset=(\w+) pulse=(\w+) step=(\w+)$', host, re.M)]
    require([(row[1],row[6],row[7]) for row in events] == timing, 'verified sequencer timing')
    playback = one(native, r'^SONG132_PLAYBACK events=(\d+) pulses=(\d+) starts=(\d+) steals=(\d+) effects=(\d+)/(\d+) stalledTicks=(\d+) stalledEvents=(\d+) started=(\d+)$')
    total,pulses,starts,steals,effect_on,effect_off,stalled,progress,started = map(int, playback)
    require(total == 1206 and pulses >= events[-1][6] and starts == sum(row[0] for row in events)
            and steals > 0 and (effect_on,effect_off) == (1,1) and stalled >= 180 and progress > 0,
            'playback/effect/interrupt positive controls')
    delivery = list(struct.iter_unpack('>2I', (folder/'song132-native-delivery.bin').read_bytes()))
    require(len(delivery) == 1206, 'complete delivery trace')
    previous = started
    for event, (intended, actual) in zip(events, delivery):
        require(intended == started+event[6] and actual >= previous and 0 <= actual-intended <= 1,
                'interrupt note delivery clock')
        previous = actual
    print('PASS FIGHT: 1206 exact original/native note events, 8 instruments/24 samples, complete timed interrupt playback, effect priority and cleanup')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('original', 'host', 'driver', 'native'):
        parser.add_argument(name, type=Path)
        parser.add_argument('--'+name+'-status', type=int, required=True)
    args = parser.parse_args()
    try:
        check(*(getattr(args,name).read_text() for name in ('original','host','driver','native')),
              [getattr(args,name+'_status') for name in ('original','host','driver','native')])
    except (ValueError, OSError, struct.error, KeyError) as error:
        raise SystemExit('FAIL FIGHT: '+str(error))
