#!/usr/bin/env python3
"""Verify a genuine ordinary-input original stop-effects call; no synthetic guest fixture."""
import argparse
from pathlib import Path
import re
import struct
from check_driver22 import fields, one
from resource_fork import read_resource_fork
ROOT = Path(__file__).resolve().parents[1]


def check(text, folder, status):
    if status != 0 or re.search(r'FAIL|TIMEOUT|LUA ERROR|Error in', text) or text.count('PASS original ordinary active driver22 call') != 1 or text.count('Exited via the debugger') != 1:
        raise ValueError('normal original active-stop completion')
    resources = read_resource_fork(ROOT / 'tmp/runtime-data/Alone In The Dark')
    code = next(r.body for r in resources if r.kind == b'CODE' and r.rid == 3)
    caller = code[0x1a6c:0x1a78]
    driver = (folder / 'driver.bin').read_bytes()
    if caller.hex() != '48780016206df9544e90588f' or one(text, r'^DRIVER22_ACTIVE_BYTES (\w+)$') != caller.hex().upper():
        raise ValueError('original and live caller identity')
    if len(driver) != 0x7248 or driver[:12].hex() != '202f0004222f000848e73ffe' or one(text, r'^DRIVER22_ACTIVE_ENTRY_BYTES (\w+)$') != driver[:12].hex().upper():
        raise ValueError('live driver identity')
    if driver[0x8c:0x90].hex() != '60000134' or driver[0x1c2:0x1ca].hex() != '610034426000fee2' or driver[0x3606:0x3628].hex() != '43ec22d2382c11c0e544d2c4302c11c46700000e337cffff0200584951c8fff64e75':
        raise ValueError('measured original dispatch and stop code')
    enter, leave = [fields(one(text, r'^DRIVER22_ACTIVE_' + phase + r' (.*)$')) for phase in ('ENTER', 'RETURN')]
    if enter['selector'] != 22 or leave['sp'] != enter['sp'] or leave['d0'] != 0 or leave['d1'] != enter['ignored']:
        raise ValueError('call stack and return ABI')
    for register in [f'd{i}' for i in range(2, 8)] + [f'a{i}' for i in range(7)]:
        if enter[register] != leave[register]:
            raise ValueError('preserved ' + register)
    before = (folder / 'enter-state.bin').read_bytes()
    after = (folder / 'return-state.bin').read_bytes()
    if len(before) != 0x3048 or len(after) != len(before):
        raise ValueError('complete original driver snapshots')
    word = lambda offset: struct.unpack_from('>H', before, offset)[0]
    music, effects = word(0x11c0), word(0x11c4)
    if music != 6 or effects not in (1, 2):
        raise ValueError('measured voice configuration')
    playing = [i for i in range(music, music + effects) if 0 < word(0x24d2 + i * 4) < 0x8000]
    held_music = sum(0 < word(0x24d2 + i * 4) < 0x8000 for i in range(music))
    if not playing or not held_music or enter['effects'] != len(playing) or leave['effects']:
        raise ValueError('real simultaneous music and active effect before stop')
    for slot in playing:
        if struct.unpack_from('>I', before, 0x22d2 + slot * 4)[0] & 0xffffff == 0:
            raise ValueError('real effect sample cursor')
    expected = bytearray(before)
    struct.pack_into('>IIH', expected, 0, 22, enter['ignored'], 0)
    # The actual configured DBRA includes the following unused slot.
    for slot in range(music, music + effects + 1):
        struct.pack_into('>H', expected, 0x24d2 + slot * 4, 0xffff)
    if after != expected:
        raise ValueError('exact effect stop, unchanged music/sample/configuration state')
    print(f'PASS ordinary original active driver22: effects={len(playing)} heldMusic={held_music}; exact stop, retained samples, unchanged music/configuration and preserved ABI')


def check_native(text, folder, status):
    if status != 0 or re.search(r'FAIL|TIMEOUT|LUA ERROR|Error in', text):
        raise ValueError('native completion')
    for marker in ('PASS native driver22 stop-effects ABI',
                   'PASS native ordinary active driver22 stop, DMA release and music isolation',
                   '[Inferior 1 (Remote target) detached]'):
        if text.count(marker) != 1:
            raise ValueError('missing/duplicate native completion marker')
    if one(text, r'^DRIVER22_NATIVE_BYTES (\w+)$') != '48780016206DF9544E90588F':
        raise ValueError('unchanged native original caller')
    entry = re.fullmatch(r'slot=(\d+) channel=(\d+) musicTick=(\d+) starts=(\d+) stops=(\d+)',
                         one(text, r'^AUDIO_STOP_ENTER (.*)$'))
    leave = re.fullmatch(r'stage=(\d+) stops=(\d+) dma=([0-9A-F]+)',
                         one(text, r'^AUDIO_STOP_RETURN (.*)$'))
    if not entry or not leave:
        raise ValueError('native ownership records')
    slot, channel, tick, starts, stops = map(int, entry.groups())
    if slot not in (0, 1) or channel not in range(4) or starts <= stops:
        raise ValueError('genuinely active effect')
    if int(leave[2]) != stops + 1 or int(leave[3], 16) & (1 << channel):
        raise ValueError('exact stop and DMA release')
    if int(one(text, r'^AUDIO_STOP_DURATION remaining=(-?\d+)$')) <= 0:
        raise ValueError('effect stopped before its natural end')
    before = (folder / 'enter-state.bin').read_bytes()
    after = (folder / 'return-state.bin').read_bytes()
    if len(before) != 96 or len(after) != 96:
        raise ValueError('complete native state')
    sample, assigned, active = struct.unpack_from('>IhH', before, 66 + slot * 8)
    if not sample or assigned != channel or active != 1:
        raise ValueError('native sample ownership')
    expected = bytearray(before)
    struct.pack_into('>hH', expected, 70 + slot * 8, -1, 0)
    struct.pack_into('>h', expected, 86 + channel * 2, -1)
    if after != expected:
        raise ValueError('exact native state and retained sample identity')
    for name, size in (('music', 48), ('voices', 168)):
        held = (folder / (name + '-before.bin')).read_bytes()
        if len(held) != size or held != (folder / (name + '-after.bin')).read_bytes():
            raise ValueError('unchanged native ' + name)
    held = (folder / 'music-before.bin').read_bytes()
    voices = (folder / 'voices-before.bin').read_bytes()
    sounding = 0
    for i in range(6):
        sample, assigned, active = struct.unpack_from('>IhH', held, i * 8)
        chip, allocated, end = struct.unpack_from('>III', voices, i * 28)
        if assigned >= 0:
            if assigned > 3 or assigned == channel or not sample or not chip or not allocated or (end and end <= tick) or not int(leave[3],16) & (1 << assigned):
                raise ValueError('actual music DMA survives effect stop')
            sounding += 1
    if not sounding:
        raise ValueError('simultaneous music playback required')
    print('PASS paired native active driver22: exact ownership transition, retained sample identity, unchanged music, DMA release and ABI')


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('log', type=Path)
    p.add_argument('--folder', type=Path, required=True)
    p.add_argument('--status', type=int, required=True)
    p.add_argument('--native', type=Path)
    p.add_argument('--native-folder', type=Path)
    p.add_argument('--native-status', type=int)
    a = p.parse_args()
    try:
        check(a.log.read_text(), a.folder, a.status)
        if a.native:
            if a.native_folder is None or a.native_status is None:
                raise ValueError('native folder and exit status required')
            check_native(a.native.read_text(), a.native_folder, a.native_status)
    except (ValueError, OSError, KeyError, StopIteration, struct.error) as error:
        raise SystemExit('FAIL active driver22: ' + str(error))
