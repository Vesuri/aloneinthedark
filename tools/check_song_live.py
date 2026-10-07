#!/usr/bin/env python3
"""Validate complete ordinary-input original music and optional native playback."""
import argparse
from pathlib import Path
import re
import struct
from check_song_inputs import check_voices
from check_driver22 import one

TOTALS = {131: 1338, 132: 1206, 135: 3736, 136: 602, 137: 2250}


def check_native(text, folder, status, song, decoded, original_state):
    total = TOTALS[song]
    marker = f'PASS SONG{song} full playback, interrupt progress, effect priority, resource cleanup and original MDRV absent'
    if status != 0 or text.count(marker) != 1 or re.search(r'FAIL|TIMEOUT|Error in|Program received signal', text):
        raise ValueError('native completion')
    if text.count('[Inferior 1 (Remote target) detached]') != 1:
        raise ValueError('normal native observer exit')
    events = list(struct.iter_unpack('>10I', (folder/'native-events.bin').read_bytes()))
    expected = [tuple(int(v, 16) for v in row) for row in re.findall(
        r'^SONG_EVENT n=\d+ on=(\w+) offset=(\w+) instrument=(\w+) note=(\w+) velocity=(\w+) channel=(\w+)$', decoded, re.M)]
    timing = [tuple(int(v, 16) for v in row) for row in re.findall(
        r'^SONG_TIMED_EVENT n=\d+ offset=(\w+) pulse=(\w+) step=(\w+)$', decoded, re.M)]
    if len(events) != total or [r[:6] for r in events] != expected or [(r[1],r[6],r[7]) for r in events] != timing:
        raise ValueError('complete native event identity and sequencer timing')
    row = one(text, rf'^SONG{song}_PLAYBACK events=(\d+) pulses=(\d+) starts=(\d+) steals=(\d+) effects=(\d+)/(\d+) stalledTicks=(\d+) stalledEvents=(\d+) started=(\d+)$')
    count,pulses,starts,steals,effect_on,effect_off,stalled,progress,started = map(int,row)
    if count != total or pulses < events[-1][6] or starts != sum(r[0] for r in events) or (effect_on,effect_off)!=(1,1) or stalled < 180 or not progress:
        raise ValueError('complete playback and interrupt/effect controls')
    delivery = list(struct.iter_unpack('>2I', (folder/'native-delivery.bin').read_bytes()))
    if len(delivery) != total:
        raise ValueError('complete interrupt delivery trace')
    previous = started
    for event,(intended,actual) in zip(events,delivery):
        if intended != started+event[6] or actual < previous or not 0 <= actual-intended <= 1:
            raise ValueError('interrupt note delivery')
        previous = actual
    from check_song_allocation import replay, sample_duration, ROOT
    from resource_fork import read_resource_fork
    resources = {(r.kind,r.rid):r.body for r in read_resource_fork(ROOT/'tmp/runtime-data/Alone In The Dark')}
    pitches = struct.unpack_from('>128I', original_state, 0x29bc)
    notes = list(struct.iter_unpack('>8I', (folder/'native-notes.bin').read_bytes()))
    clocks = list(struct.iter_unpack('>2I', (folder/'native-clocks.bin').read_bytes()))
    effects = list(struct.iter_unpack('>8I', (folder/'native-effects.bin').read_bytes()))
    if len(clocks) != total or len(notes) != starts or len(effects) != 2:
        raise ValueError('complete native hardware allocation captures')
    allocated,predicted,endings = replay([e[:8] for e in events],notes,clocks,effects,started,sample_duration(resources,pitches),lambda iid: bool(int.from_bytes(resources[b'INST',iid][6:8],'big')&0x0400))
    if predicted != steals or allocated != starts:
        raise ValueError('complete four-channel allocation policy')
    print(f'PASS SONG {song} allocation: {allocated} notes, {predicted} independently predicted steals, all channels and note lifetimes verified')
    print(f'PASS native SONG {song}: {total} matching timed events, trapless IRQ progress, effect priority and cleanup')


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('song',type=int,choices=TOTALS)
    p.add_argument('original',type=Path)
    p.add_argument('decoded',type=Path)
    p.add_argument('--state',type=Path,required=True)
    p.add_argument('--status',type=int,required=True)
    p.add_argument('--native',type=Path)
    p.add_argument('--native-folder',type=Path)
    p.add_argument('--native-status',type=int)
    a=p.parse_args()
    original=a.original.read_text();decoded=a.decoded.read_text()
    if f'SONG_LIVE_BEGIN song={a.song} midi={a.song+770} ' not in original:
        raise ValueError('original song identity')
    check_voices(original,a.status,decoded,song_id=a.song,total=TOTALS[a.song],state_path=a.state)
    if a.native:
        if a.native_folder is None or a.native_status is None:
            raise ValueError('native folder and actual exit status required')
        check_native(a.native.read_text(),a.native_folder,a.native_status,a.song,decoded,a.state.read_bytes())


if __name__=='__main__':
    try:main()
    except (ValueError,OSError,KeyError,struct.error) as error:
        raise SystemExit('FAIL live song: '+str(error))
