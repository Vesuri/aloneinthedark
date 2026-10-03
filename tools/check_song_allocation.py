#!/usr/bin/env python3
"""Replay four-channel allocation from original MIDI plus observed effect timing.

Checks the documented oldest-note policy and sample-duration/release ownership.
This does not measure analog output, host audio, or uninterrupted onset jitter.
"""
import argparse
from collections import defaultdict
from pathlib import Path
import re
import struct

from resource_fork import read_resource_fork

ROOT = Path(__file__).resolve().parents[1]


def require(ok, message):
    if not ok:
        raise ValueError(message)


def replay(events, notes, clocks, effects, started, duration):
    voices = [None]*4
    changes = defaultdict(list)
    previous = (-1, -1)
    for row in effects:
        count, tick, operation, channel, slot, identifier, game_tick, end = row
        require(0 <= count <= len(events) and tick >= started and operation <= 2
                and channel < 4 and slot < 2, 'effect row ranges')
        require((count, tick) >= previous, 'effect ordering')
        previous = count, tick
        changes[count].append(row)
    serviced = started
    starts = steals = 0

    def expire(tick):
        nonlocal serviced
        require(tick >= serviced, 'serviced clock ordering')
        if tick == serviced:
            return
        for channel, voice in enumerate(voices):
            if voice and voice['kind'] == 'song' and voice['end'] and voice['end'] <= tick:
                voices[channel] = None
        serviced = tick

    def choose():
        nonlocal steals
        free = [c for c, v in enumerate(voices) if v is None]
        if free:
            return free[0]
        songs = [c for c, v in enumerate(voices) if v['kind'] == 'song']
        require(songs, 'all channels occupied by effects')
        steals += 1
        return min(songs, key=lambda c: voices[c]['serial'])

    for count in range(len(events)+1):
        last_stop = None
        for _, tick, operation, channel, slot, identifier, game_tick, end in changes[count]:
            expire(tick)
            if operation == 0:
                require(voices[channel] is not None
                        and voices[channel]['kind'] == 'effect'
                        and voices[channel]['slot'] == slot, 'effect stop ownership')
                voices[channel] = None
                last_stop = (tick, channel, slot, game_tick)
            else:
                if operation == 2:
                    require(count == 0 and voices[channel] is None, 'initial effect ownership')
                elif (last_stop is not None and last_stop[:3] == (tick, channel, slot)
                      and 0 <= game_tick-last_stop[3] <= 1):
                    # Replacement explicitly retains its former channel. The
                    # capture records its paired stop/start, not an operation
                    # flag; this proves policy consistency, not unique intent.
                    require(voices[channel] is None, 'replacement channel free')
                else:
                    require(choose() == channel, f'effect allocation at event {count}')
                voices[channel] = {'kind': 'effect', 'slot': slot}
                last_stop = None
        if count == len(events):
            break
        on, offset, instrument, note, velocity, midi, pulse, step = events[count]
        tick, actual = clocks[count]
        require(started+pulse <= actual <= started+pulse+1 and tick <= actual,
                f'event delivery at {count}')
        expire(tick)
        if not on:
            for voice in voices:
                if (voice and voice['kind'] == 'song' and voice['active']
                        and (voice['note'], voice['midi']) == (note, midi)):
                    voice['active'] = False
                    voice['end'] = min(voice['end'] or actual+5, actual+5)
            continue
        require(starts < len(notes), 'note capture count')
        row = notes[starts]
        require((row[0], row[1], row[6], row[7]) ==
                (started+pulse, actual, instrument, note), f'note identity at {starts}')
        channel = choose()
        require(channel == row[4], f'note {starts}: expected channel {channel}, captured {row[4]}')
        length = duration(instrument, note, row[5])
        voices[channel] = dict(kind='song', serial=starts, note=note, midi=midi,
                               active=True, end=actual+length+1 if length else 0)
        starts += 1
    require(starts == len(notes), 'complete note allocation')
    return starts, steals


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('log', type=Path)
    parser.add_argument('prefix', type=Path, help='capture prefix for -notes/-events/-effects.bin')
    parser.add_argument('--status', type=int, required=True)
    args = parser.parse_args()
    log = args.log.read_text()
    require(args.status == 0 and not re.search(r'FAIL|[Tt]imeout|Error in', log)
            and sum(log.count(marker) for marker in (
                'PASS original demo timing complete',
                'PASS uninterrupted intro hardware note capture')) == 1
            and '[Inferior 1 (Remote target) detached]' in log, 'complete intro observer')
    meta = re.findall(r'AUDIO_OWNERSHIP starts=(\d+) steals=(\d+) effects=(\d+) overflow=(\d+) started=(\d+) source=(\d+)', log)
    require(len(meta) == 1, 'ownership metadata')
    starts, steals, effect_count, overflow, started, source = map(int, meta[0])
    require(starts == 1868 and not overflow and source in (1, 2), 'complete CIA capture')
    reference = (ROOT/'tmp/m2-song-clock-reference.log').read_text()
    require(reference.count('PASS original song clock events=3736 steps=8785') == 1,
            'original event reference')
    raw = re.findall(r'^SONG_CLOCK_EVENT n=(\d+) on=(\w+) offset=(\w+) instrument=(\w+) note=(\w+) velocity=(\w+) channel=(\w+) sequence=(\w+) tick=\w+ step=(\w+) countdown=\w+$', reference, re.M)
    require([int(r[0]) for r in raw] == list(range(1, 3737)), 'complete original events')
    events = [tuple(int(v, 16) for v in r[1:]) for r in raw]
    def capture(suffix, words, count):
        data = Path(str(args.prefix)+suffix+'.bin').read_bytes()
        require(len(data) == count*words*4, 'capture size '+suffix)
        return list(struct.iter_unpack('>'+str(words)+'I', data))
    notes = capture('-notes', 8, starts)
    clocks = capture('-events', 2, len(events))
    effects = capture('-effects', 8, effect_count)
    resources = {(r.kind, r.rid): r.body for r in
                 read_resource_fork(ROOT/'tmp/runtime-data/Alone In The Dark')}
    pitches = struct.unpack_from('>128I', (ROOT/'tmp/song-live-initial-state.bin').read_bytes(), 0x29bc)
    def duration(iid, note, period):
        ins = resources[b'INST', iid]
        root = int.from_bytes(ins[2:4], 'big')
        adjusted = note-root+60 if root else note
        sid = int.from_bytes(ins[:2], 'big')
        for i in range(int.from_bytes(ins[12:14], 'big')):
            row = ins[14+i*8:22+i*8]
            if (not row[0] or adjusted >= row[0]) and (row[1] >= 127 or adjusted <= row[1]):
                sid = int.from_bytes(row[2:4], 'big') or sid
                break
        sample = resources[b'snd ', sid]
        size, rate, start, end = struct.unpack_from('>4I', sample, 18)
        require(rate == 11025 << 16, 'reference sample rate')
        pitch = pitches[adjusted+60-sample[35]]
        if pitch & 65535 < 4:
            pitch &= 0xffff0000
        denominator = pitch*0x56ee8ba3
        stride = 1
        while ((3546895*stride << 33)+denominator//2)//denominator < 124:
            stride *= 2
            require(stride <= 16, 'sample stride')
        require(period == ((3546895*stride << 33)+denominator//2)//denominator, 'original pitch')
        if start and end and end != 0xffffffff and ((end-start) & 65535) >= 100:
            return 0
        attack = ((size+stride-1)//stride+1) & ~1
        return (attack*period*60+3546894)//3546895
    observed_starts, predicted_steals = replay(events, notes, clocks, effects, started, duration)
    require(predicted_steals == steals, 'complete oldest-note stealing count')
    print(f'PASS allocation: {observed_starts} original notes, {effect_count} effect transitions, '
          f'{steals} predicted steals; all channel assignments follow the policy')
    print('Immediate paired effect stop/start may retain its channel; replacement intent is not separately traced.')
    print('Ownership/release-policy check only; not analog or host-output fidelity.')


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError, KeyError, IndexError, struct.error) as error:
        raise SystemExit('FAIL allocation: '+str(error))
