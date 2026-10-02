#!/usr/bin/env python3
"""Verify selected PAL/NTSC geometry, field timing and native effect evidence."""
import argparse
from pathlib import Path
import re
import struct

ROOT = Path(__file__).resolve().parents[1]


def check(text, status, video, case):
    if status != 0 or any(x in text for x in ('FAIL', 'Error in', 'TIMEOUT', 'Program received signal')) or text.count('[Inferior 1 (Remote target) detached]') != 1:
        raise ValueError('normal native completion')
    pal = int(video == 'PAL')
    clock = 3546895 if pal else 3579545
    expected = (pal, clock, 0x4881 if pal else 0x2c81, 0x10c1 if pal else 0xf4c1, 0x2100 if pal else 0x2000)
    records = re.findall(r'^VIDEO_MODE pal=(\d+) clock=(\d+) diwstrt=([0-9A-F]+) diwstop=([0-9A-F]+) diwhigh=([0-9A-F]+) fields=(\d+) ticks=(\d+)$', text, re.M)
    if len(records) != 2:
        raise ValueError('before/after video register captures')
    for row in records:
        if tuple(int(v, 10 if i < 2 else 16) for i, v in enumerate(row[:5])) != expected:
            raise ValueError('selected hardware mode/clock')
    if case == 'display':
        rows = re.findall(r'^PASS native video timing pal=(\d+) fields=(\d+) ticks=(\d+)$', text, re.M)
        if len(rows) != 1 or int(rows[0][0]) != pal:
            raise ValueError('field clock completion')
        fields, ticks = map(int, rows[0][1:])
        if fields != (int(records[1][5])-int(records[0][5])) & 65535 or ticks != int(records[1][6])-int(records[0][6]) or fields < 10:
            raise ValueError('observed field/tick deltas')
        if not fields+(fields//5 if pal else 0) <= ticks <= fields+((fields+4)//5 if pal else 0):
            raise ValueError('60 Hz Mac clock conversion')
        if text.count('PASS AGA fixture frames=5 restored=1') != 1:
            raise ValueError('display fixture/restoration completion')
    else:
        rows = re.findall(r'^VIDEO_EFFECT pal=(\d+) clock=(\d+) hz=(\d+) bytes=(\d+) period=(\d+) duration=(\d+)$', text, re.M)
        if len(rows) != 1:
            raise ValueError('effect observation')
        mode, rate_clock, hz, size, period, ticks = map(int, rows[0])
        packet = (ROOT/'tmp/driver17-native-packet.bin').read_bytes()
        original = (ROOT/'tmp/driver17-reference-packet.bin').read_bytes()
        pcm = (ROOT/'tmp/driver17-reference-sample.bin').read_bytes()
        if len(packet) != 26 or packet[4:20] != original[4:20] or packet[24:] != original[24:]:
            raise ValueError('original effect request')
        if (mode, rate_clock) != (pal, clock) or hz != struct.unpack_from('>I', packet, 8)[0] >> 16 or size != (len(pcm)+1) & ~1:
            raise ValueError('effect source/selected clock')
        if period != (clock+hz//2)//hz or ticks != (size*period*60+clock-1)//clock:
            raise ValueError('integer pitch/duration')
        programming = re.findall(r'^VIDEO_AUDIO_PROGRAM period=(\d+) channel=(\d+)$', text, re.M)
        if len(programming) != 1 or tuple(map(int, programming[0])) != (period, 0):
            raise ValueError('selected period passed to Paula programming')
        if (ROOT/'tmp/driver17-native-sample.bin').read_bytes() != pcm or (ROOT/'tmp/driver17-native-chip.bin').read_bytes() != bytes(b ^ 0x80 for b in pcm)+bytes(size-len(pcm)+2):
            raise ValueError('paired raw PCM, padding and reload')
        end = re.findall(r'^PASS native video effect pal=(\d+) period=(\d+) duration=(\d+) stopTick=(\d+) scheduled=(\d+)$', text, re.M)
        if len(end) != 1 or tuple(map(int, end[0][:3])) != (pal, period, ticks) or int(end[0][3]) < int(end[0][4]) or text.count('PASS native driver17 play-effect ABI and publication') != 1:
            raise ValueError('original effect ABI/natural completion')
    print(f'PASS native {video} {case}: selected clock, centred geometry and '+('field conversion' if case == 'display' else 'paired PCM, exact pitch/duration and DMA cleanup'))


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('log', type=Path)
    p.add_argument('--status', type=int, required=True)
    p.add_argument('--video', choices=('PAL', 'NTSC'), required=True)
    p.add_argument('--case', choices=('display', 'effect'), required=True)
    a = p.parse_args()
    try:
        check(a.log.read_text(), a.status, a.video, a.case)
    except (ValueError, OSError, struct.error) as error:
        raise SystemExit('FAIL video mode: '+str(error))
