#!/usr/bin/env python3
"""Check four exposed release deadlines in the retained idle-host PCM fixture.

This is a targeted waveform check, not a full polyphonic synthesis oracle.
Requires NumPy. Run hardware and allocation checks on the same capture first.
"""
import argparse
from pathlib import Path
import re
import struct
import wave
import numpy as np


def require(ok, message):
    if not ok:
        raise SystemExit('FAIL ' + message)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('prefix', type=Path)
    parser.add_argument('reference', type=Path)
    parser.add_argument('--origin', type=float, required=True,
                        help='independently aligned first-note PCM time in seconds')
    args = parser.parse_args()
    notes = list(struct.iter_unpack('>8I', Path(str(args.prefix)+'-notes.bin').read_bytes()))
    clocks = list(struct.iter_unpack('>2I', Path(str(args.prefix)+'-events.bin').read_bytes()))
    rows = re.findall(r'^SONG_CLOCK_EVENT n=\w+ on=(\w+) offset=\w+ instrument=(\w+) '
                      r'note=(\w+) velocity=\w+ channel=(\w+) sequence=\w+ tick=\w+ '
                      r'step=\w+ countdown=\w+$', args.reference.read_text(), re.M)
    events = [tuple(int(v, 16) for v in row) for row in rows]
    attacks = [i for i, event in enumerate(events) if event[0]]
    require(len(events) == len(clocks) == 3736 and len(attacks) == len(notes) == 1868,
            'complete intro event fixtures')
    with wave.open(str(args.prefix)+'.wav') as wav:
        require((wav.getframerate(), wav.getnchannels(), wav.getsampwidth()) == (44100, 2, 2),
                '44.1 kHz signed-16 stereo fixture')
        pcm = np.frombuffer(wav.readframes(wav.getnframes()), '<i2').reshape(-1, 2)
    silent = np.all(pcm == 0, axis=1)
    edges = np.diff(np.r_[False, silent, False].astype(np.int8))
    gaps = [(s/44100, e/44100) for s, e in
            zip(np.flatnonzero(edges == 1), np.flatnonzero(edges == -1)) if e-s > 882]

    def beam(value):
        first = notes[0][2]
        return ((((value >> 9)-(first >> 9)) & 65535)*313
                +(value & 511)-(first & 511))*227/3546895

    times = [(beam(n[2])+beam(n[3]))/2 for n in notes]
    # These four rests expose the last surviving voice's five-tick cutoff.
    # The complete ownership replay independently checks other voices/effects.
    for index in (408, 1130, 1265, 1344):
        event_index = attacks[index]
        _, instrument, note, midi = events[event_index]
        require((instrument, note) == tuple(notes[index][6:8]), 'reference note identity')
        off = next(i for i in range(event_index+1, len(events))
                   if not events[i][0] and events[i][2:] == (note, midi))
        stop = (clocks[off][1]-notes[0][0]+5)/60
        restart = next(t for t in times[index+1:] if t > stop)
        expected = restart-stop
        require(.09 < expected < .53, 'selected exposed rest')
        candidates = [(s, e) for s, e in gaps if abs(s-args.origin-stop) < .03]
        require(len(candidates) == 1, 'unique nearby PCM silence')
        start, end = candidates[0]
        error = (end-start)-expected
        require(abs(error) < .002, 'release-to-restart duration within 2 ms')
        print(f'PASS note {index}: expected rest {expected*1000:.3f} ms, '
              f'PCM {(end-start)*1000:.3f} ms, error {error*1000:+.3f} ms')
    print('Four exposed five-tick releases only; excludes masked tails, stereo fidelity and host dropouts.')


if __name__ == '__main__':
    main()
