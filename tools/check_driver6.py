#!/usr/bin/env python3
"""Check original music-voice stop, distinguishing isolated RAM fixtures."""
import argparse
import re
import struct
from pathlib import Path
from check_driver22 import fields, one


def check(folder, status):
    text = (folder / 'run.log').read_text()
    mode = one(text, r'^DRIVER6_FIXTURE mode=(natural|active|empty) .*')
    if status != 0 or re.search(r'FAIL|TIMEOUT|LUA ERROR|Error in', text):
        raise ValueError('reference completion')
    for marker in ('PASS original driver6 ' + mode + ' contract', 'Exited via the debugger'):
        if text.count(marker) != 1:
            raise ValueError('missing/duplicate completion')
    fixture = fields(one(text, r'^DRIVER6_FIXTURE (.*)$'))
    original = 6 if mode == 'natural' else 4
    if fixture['originalSelector'] != original:
        raise ValueError('fixture selector provenance')
    driver = (folder / 'driver.bin').read_bytes()
    instructions = {0: '202f0004222f000848e73ffe', 0x4c: '60000322',
                    0x370: '61002d526000fd34',
                    0x30c4: '302c11c06710534041ec24d220fcffffffff51c8fff84e75',
                    0xaa: '7000302c00084cdf7ffc4e75'}
    if len(driver) != 0x7248:
        raise ValueError('complete driver capture')
    for offset, value in instructions.items():
        if driver[offset:offset+len(value)//2].hex() != value:
            raise ValueError('original driver instructions')
    caller = (folder / 'caller.bin').read_bytes()
    if len(caller) != 16 or caller[2:14].hex() != f'487800{original:02x}206df9544e90588f':
        raise ValueError('unchanged original caller')
    enter, leave = [fields(one(text, r'^DRIVER6_' + phase + r' (.*)$')) for phase in ('ENTER', 'RETURN')]
    if enter['selector'] != 6 or leave['sp'] != enter['sp'] + 4 or leave['d0'] or leave['d1'] != enter['argument'] or leave['sr'] & 31 != 4:
        raise ValueError('return ABI')
    for register in [f'd{i}' for i in range(2, 8)] + [f'a{i}' for i in range(7)]:
        if enter[register] != leave[register]:
            raise ValueError('preserved ' + register)
    before = (folder / 'enter-state.bin').read_bytes()
    after = (folder / 'return-state.bin').read_bytes()
    if len(before) != 0x3048 or len(after) != len(before):
        raise ValueError('complete state captures')
    if struct.unpack_from('>H', before, 0x11c0)[0] != 6:
        raise ValueError('music configuration')
    active = lambda data, first, last: sum(0 < struct.unpack_from('>H', data, 0x24d2 + 4*i)[0] < 0x8000 for i in range(first, last))
    music, effects = active(before, 0, 6), active(before, 6, 8)
    if mode == 'active' and (not music or not effects) or mode == 'empty' and music:
        raise ValueError('fixture starting state')
    if enter['music'] != music or enter['effects'] != effects or leave['music'] or leave['effects'] != effects:
        raise ValueError('voice transition')
    expected = bytearray(before)
    struct.pack_into('>IIH', expected, 0, 6, enter['argument'], 0)
    for index in range(6):
        struct.pack_into('>I', expected, 0x24d2 + index*4, 0xffffffff)
    if after != expected:
        raise ValueError('exact music stop and retained sequencer/effect/resource state')
    print(f'PASS original driver6 {mode}: {music} music voices stopped, {effects} effects retained; exact full-state transition and ABI')


def check_native(folder, status):
    text = (folder / 'run.log').read_text()
    if status != 0 or re.search(r'FAIL|TIMEOUT|Error in', text) or text.count('PASS native driver6 return ABI') != 1 or text.count('[Inferior 1 (Remote target) detached]') != 1:
        raise ValueError('native completion')
    def record(label):
        return {k: int(v, 16 if k in ('sp', 'argument', 'dma') else 10)
                for k, v in re.findall(r'(\w+)=([0-9A-Fa-f]+)', one(text, '^DRIVER6_NATIVE_' + label + ' (.*)$'))}
    enter, leave, layout = [record(label) for label in ('ENTER', 'RETURN', 'LAYOUT')]
    if enter['musicTick'] != leave['musicTick'] or enter['effectTick'] != leave['effectTick']:
        raise ValueError('interrupt changed state during fixture; repeat capture')
    driver = (folder / 'driver-before.bin').read_bytes()
    expected = bytearray(driver)
    if len(driver) != 96 or layout['driverSize'] != 96:
        raise ValueError('driver layout')
    music_channels = []
    for i in range(6):
        sample, channel, active = struct.unpack_from('>IhH', driver, 18+i*8)
        if channel >= 0:
            if channel > 3 or not sample or not active or not enter['dma'] & (1 << channel):
                raise ValueError('actual sounding music')
            music_channels.append(channel)
            struct.pack_into('>h', expected, 86+channel*2, -1)
        struct.pack_into('>hH', expected, 22+i*8, -1, 0)
    effects = []
    for i in range(2):
        sample, channel, active = struct.unpack_from('>IhH', driver, 66+i*8)
        if active:
            if not sample or channel not in range(4) or channel in music_channels or not enter['dma'] & leave['dma'] & (1 << channel):
                raise ValueError('retained physical effect playback')
            effects.append(channel)
    if not music_channels or not effects:
        raise ValueError('simultaneous music/effect fixture')
    if any(leave['dma'] & (1 << channel) for channel in music_channels):
        raise ValueError('music DMA still enabled')
    if expected != (folder / 'driver-after.bin').read_bytes():
        raise ValueError('exact driver ownership transition')
    song = bytearray((folder / 'song-before.bin').read_bytes())
    if len(song) != layout['songSize'] or layout['voiceSize'] != 28:
        raise ValueError('song layout')
    for i in range(6):
        struct.pack_into('>III', song, layout['voices']+i*28, 0, 0, 0)
    if song != (folder / 'song-after.bin').read_bytes():
        raise ValueError('unchanged sequencer/resources and exact voice transition')
    effects_before = (folder / 'effects-before.bin').read_bytes()
    if len(effects_before) != 72 or effects_before != (folder / 'effects-after.bin').read_bytes():
        raise ValueError('unchanged effect stream state')
    print('PASS native driver6: music DMA stopped, effect DMA retained, exact full-state transition, sequencer/resources retained and ABI')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('folder', type=Path)
    parser.add_argument('--status', type=int, required=True)
    parser.add_argument('--native', action='store_true')
    args = parser.parse_args()
    try:
        (check_native if args.native else check)(args.folder, args.status)
    except (ValueError, OSError, KeyError, struct.error) as error:
        raise SystemExit('FAIL driver6: ' + str(error))
