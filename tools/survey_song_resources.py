#!/usr/bin/env python3
"""Survey all original song formats; this does not establish driver/playback fidelity."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import struct
from resource_fork import read_resource_fork

ROOT = Path(__file__).resolve().parents[1]


def survey(resource, output):
    resources = read_resource_fork(resource)
    songs = sorted((r for r in resources if r.kind == b'SONG'), key=lambda r: r.rid)
    if [r.rid for r in songs] != list(range(130, 138)):
        raise ValueError('expected eight original songs 130 through 137')
    output.mkdir(parents=True, exist_ok=True)
    inputs = output / 'inputs'
    inputs.mkdir(exist_ok=True)
    for item in resources:
        if item.kind in (b'SONG', b'MIDI', b'INST', b'snd '):
            (inputs / (item.kind.decode().strip() + '_' + str(item.rid))).write_bytes(item.body)
    decoder = output / 'decoder'
    subprocess.run([os.environ.get('HOST_CXX', 'c++'), '-std=c++17', '-Wall', '-Wextra', '-Werror',
                    '-fsanitize=address,undefined', str(ROOT / 'tools/test_song_inputs.cpp'),
                    '-o', str(decoder)], check=True)
    rows = []
    for song in songs:
        midi = struct.unpack_from('>H', song.body)[0]
        run = subprocess.run([str(decoder.resolve()), str(inputs / ('SONG_' + str(song.rid))),
                              str(inputs / ('MIDI_' + str(midi))), str(inputs)],
                             capture_output=True, text=True, timeout=120)
        log = run.stdout + run.stderr
        (output / ('song' + str(song.rid) + '.log')).write_text(log)
        events = re.findall(r'^PASS decoded song events=(\d+) ticks=(\d+)$', log, re.M)
        graph = re.findall(r'^PASS song resource graph instruments=(\d+) samples=(\d+)$', log, re.M)
        if run.returncode or len(events) != 1 or len(graph) != 1 or re.search(r'FAIL|runtime error:|ERROR: AddressSanitizer', log):
            raise ValueError('song ' + str(song.rid) + ' failed; see its log')
        rows.append(dict(song=song.rid, name=song.name, midi=midi, status=run.returncode,
                         events=int(events[0][0]), midi_ticks=int(events[0][1]),
                         instruments=int(graph[0][0]), samples=int(graph[0][1]),
                         log_sha256=hashlib.sha256(log.encode()).hexdigest()))
        print('PASS resource survey ' + song.name + ': ' + str(rows[-1]['events']) + ' events', flush=True)
    (output / 'survey.json').write_text(json.dumps(dict(
        scope='Host decoding and PCM preparation only; original driver events and native playback remain required.',
        resource_sha256=hashlib.sha256(resource.read_bytes()).hexdigest(), songs=rows), indent=2) + '\n')


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--resource', type=Path, default=ROOT / 'tmp/runtime-data/Alone In The Dark')
    p.add_argument('--output', type=Path, default=ROOT / 'tmp/m4-song-resource-survey')
    args = p.parse_args()
    try:
        survey(args.resource, args.output)
    except (ValueError, OSError, subprocess.SubprocessError) as error:
        raise SystemExit('FAIL song resource survey: ' + str(error))
