#!/usr/bin/env python3
"""Paired ambient playback through original game code with isolated RAM entropy."""
import argparse
from pathlib import Path
import re
import struct
from check_driver22 import fields, one

SAMPLES = ((27115, 'E237BE27'), (21157, '235E2009'), (10806, 'F09B4483'))


def completed(folder, marker, log='run.log'):
    text = (folder/log).read_text()
    if int((folder/'exit-status').read_text()) or re.search(r'FAIL|TIMEOUT|LUA ERROR|Error in', text) or text.count(marker) != 1:
        raise ValueError('fixture completion ' + str(folder))
    return text


def check(reference, native=None):
    text = completed(reference, 'PASS original isolated ambient playback')
    case = int(one(text, r'^AMBIENT_SEED case=(\d+) .*'))
    if case not in range(3):
        raise ValueError('ambient choice')
    if one(text, r'^AMBIENT_SELECTED result=(\d+) nextSeed=16807$') != str(case):
        raise ValueError('original RNG executed with selected entropy')
    enter, leave = [fields(one(text, r'^AMBIENT_' + phase + r' (.*)$')) for phase in ('ENTER', 'RETURN')]
    enter['selector'] = int(one(text, r'^AMBIENT_ENTER .* selector=(\d+) .*'))
    if enter['selector'] != 17 or leave['sp'] != enter['sp']+4 or leave['d0'] or leave['d1'] != (enter['argument'] & 0xffff0000) | 0x7fff or leave['sr'] & 31 != 4:
        raise ValueError('original ABI')
    for reg in [f'd{i}' for i in range(2, 8)]+[f'a{i}' for i in range(7)]:
        if enter[reg] != leave[reg]:
            raise ValueError('original preserved ' + reg)
    packet = (reference/'packet.bin').read_bytes()
    sample, size, rate, start, end, counter, ident = struct.unpack('>6IH', packet)
    pcm = (reference/'source.bin').read_bytes()
    digest = 2166136261
    for byte in pcm:
        digest = ((digest ^ byte)*16777619) & 0xffffffff
    if (size, f'{digest:08X}') != SAMPLES[case] or len(pcm) != size or (start, end, ident) != (0, 0, 0x8000):
        raise ValueError('original ambient sample identity and packet')
    actors = (reference/'actors.bin').read_bytes()
    if len(actors) != 8000 or not any(struct.unpack_from('>hh', actors, i*160) == (278, -1) and struct.unpack_from('>h', actors, i*160+0x34)[0] == 528 for i in range(50)):
        raise ValueError('original attic ambient actor/life')
    before, after, finish = [(reference/(name+'-state.bin')).read_bytes() for name in ('enter', 'return', 'complete')]
    if any(len(data) != 0x3048 for data in (before, after, finish)):
        raise ValueError('complete original driver state')
    expected = bytearray(before)
    struct.pack_into('>IIH', expected, 0, 17, enter['argument'], 0)
    voice = 0x22d2 + 6*4
    longs = {0: sample, 0x40: ((rate>>5)//11127)<<5, 0x80: 0, 0x240: 0, 0x280: sample+size,
             0x2c0: 0, 0x300: 0, 0x340: enter['a0']+0x4200+0x2ca6,
             0x3c0: 0, 0x540: counter, 0x640: 0x00800080}
    for offset, value in longs.items():
        struct.pack_into('>I', expected, voice+offset, value)
    for offset, value in {0x200: 0x7ffe, 0x440: ident, 0x500: 0x7fff, 0x580: 0}.items():
        struct.pack_into('>H', expected, voice+offset, value)
    if after != expected:
        raise ValueError('exact original playback allocation')
    if struct.unpack_from('>I', finish, voice)[0] != sample+size or struct.unpack_from('>H', finish, voice+0x200)[0] != 0xffff:
        raise ValueError('complete original sample tail')
    elapsed = int(one(text, r'^AMBIENT_COMPLETE case='+str(case)+r' slot=6 elapsed=(\d+)$'))
    expected_ticks = size*60*65536/rate
    if not expected_ticks <= elapsed <= expected_ticks+4:
        raise ValueError('original playback duration')
    if native:
        nt = completed(native, 'PASS native isolated ambient playback, DMA, cleanup and ABI')
        if '[Inferior 1 (Remote target) detached]' not in nt:
            raise ValueError('native debugger completion')
        np = struct.unpack('>6IH', (native/'packet.bin').read_bytes())
        if np[1:5] != (size, rate, 0, 0) or np[6] != ident or (native/'source.bin').read_bytes() != pcm:
            raise ValueError('paired complete PCM and packet')
        chip = bytes(byte^128 for byte in pcm)+bytes((size & 1)+2)
        if (native/'chip.bin').read_bytes() != chip:
            raise ValueError('signed native PCM, odd tail and silence reload')
        row = one(nt, r'^AMBIENT_NATIVE_PLAY (.*)$')
        data = {k: int(v, 16 if k == 'rate' else 10) for k,v in re.findall(r'(\w+)=([\dA-F]+)', row)}
        period = (3546895*65536+rate//2)//rate
        duration = (((size+1)&~1)*period*60+3546894)//3546895
        if data['size'] != size or data['rate'] != rate or data['period'] != period or data['duration'] != duration or data['allocated'] != len(chip) or data['selected'] != 2:
            raise ValueError('native pitch, duration and ownership')
        ne = int(one(nt, r'^AMBIENT_NATIVE_COMPLETE elapsed=(\d+)$'))
        if ne < duration+1:
            raise ValueError('premature native cleanup')
        rows = re.findall(r'^AMBIENT_DMA_IRQ n=(\d+) clocks=(\d+) hz=(\d+)$', nt, re.M)
        if len(rows) != 4 or [int(r[0]) for r in rows] != list(range(4)) or {int(r[2]) for r in rows} != {709379}:
            raise ValueError('four actual Paula interrupt timestamps')
        clocks = [int(r[1]) for r in rows]
        if not 0 < clocks[0] < 709.379 or clocks != sorted(set(clocks)):
            raise ValueError('Paula initial DMA start')
        seconds = ((size+1)&~1)*period/3546895
        if abs((clocks[1]-clocks[0])/709379-seconds) > .003:
            raise ValueError('complete ambient attack duration')
        for before_irq, after_irq in zip(clocks[1:], clocks[2:]):
            if abs((after_irq-before_irq)/709379-2*period/3546895) > .0001:
                raise ValueError('ambient silent-word reloads')
        if abs(seconds*60-expected_ticks)>1:
            raise ValueError('paired actual playback duration')
        print(f'Native DMA attack duration={seconds:.6f}s; main-thread cleanup tick={ne}, deadline={duration+1}')
        na = (native/'actors.bin').read_bytes()
        if len(na) != 8000 or not any(struct.unpack_from('>hh', na, i*160) == (278, -1) and struct.unpack_from('>h', na, i*160+0x34)[0] == 528 for i in range(50)):
            raise ValueError('native attic ambient actor/life')
    print(f'PASS ambient case {case}: original script/RNG, sample identity, exact allocation, ABI and complete playback'+('; paired native PCM, pitch, DMA and cleanup' if native else ''))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('reference', type=Path)
    parser.add_argument('--native', type=Path)
    args = parser.parse_args()
    try:
        check(args.reference, args.native)
    except (ValueError, OSError, KeyError, struct.error) as error:
        raise SystemExit('FAIL ambient: '+str(error))
