#!/usr/bin/env python3
"""Validate an emulator-local SDL2 capture; optionally export its committed PCM.

Callback spacing is host delivery evidence, not musical-onset or analog proof.
"""
import argparse
import mmap
from pathlib import Path
import statistics
import struct
import wave


def require(ok, message):
    if not ok:
        raise SystemExit('FAIL '+message)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('capture', type=Path)
    parser.add_argument('--wav', type=Path)
    args = parser.parse_args()
    with args.capture.open('rb') as stream, mmap.mmap(stream.fileno(), 0, access=mmap.ACCESS_READ) as data:
        magic, version, rate, fmt, channels, samples, device, size, count, overflow, offset, capacity = struct.unpack_from('<8s6I5Q', data)
        require(magic == b'AITDPCM1' and version == 1 and device != 0, 'capture device/header')
        require(rate == 44100 and fmt == 0x8010 and channels == 2, '44.1 kHz signed little-endian stereo')
        require(0 < count <= 65536 and not overflow and 0 < size <= capacity, 'complete bounded capture')
        require(offset == 4096+65536*24 and offset+capacity == len(data), 'mapping extent')
        expected = 0
        clocks = []
        for index in range(count):
            ns, at, length, reserved = struct.unpack_from('<QQII', data, 4096+index*24)
            require(at == expected and length == samples*channels*2 and not reserved, 'contiguous callback data')
            require(not clocks or ns > clocks[-1], 'monotonic callback clock')
            expected += length
            clocks.append(ns)
        require(expected == size, 'all committed PCM accounted for')
        gaps = [(b-a)/1e6 for a, b in zip(clocks, clocks[1:])]
        require(gaps, 'multiple callbacks')
        ordered = sorted(gaps)
        print(f'PASS {count} contiguous callbacks, {size} PCM bytes, {size/(rate*channels*2):.6f} seconds, zero overflow')
        print(f'Host callback gap ms: median={statistics.median(gaps):.3f}, p99={ordered[int(.99*(len(ordered)-1))]:.3f}, max={max(gaps):.3f}')
        if args.wav:
            require(not args.wav.exists(), 'new WAV destination')
            with wave.open(str(args.wav), 'wb') as out:
                out.setnchannels(channels)
                out.setsampwidth(2)
                out.setframerate(rate)
                for start in range(0, size, 1024*1024):
                    out.writeframesraw(data[offset+start:offset+min(size,start+1024*1024)])
            print('WAV '+str(args.wav))
        print('PCM handed to SDL only; musical onsets/releases and physical speaker output require separate evidence.')


if __name__ == '__main__':
    main()
