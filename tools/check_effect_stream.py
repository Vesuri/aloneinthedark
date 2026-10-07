#!/usr/bin/env python3
"""Pair native DMA fragments and loop-counter behavior with original fixtures."""
import argparse
from pathlib import Path
import re
import struct
from check_effect_packet import check as check_original
from check_driver22 import one,fields

def check(folder,status,native_folder,native_status):
    check_original(folder,status)
    text=(native_folder/'native-capture.log').read_text()
    if native_status or re.search(r'FAIL|TIMEOUT|Error in|Program received signal',text) or text.count('PASS native effect loop ABI, bounded streaming, counter and DMA/memory cleanup')!=1 or text.count('[Inferior 1 (Remote target) detached]')!=1:
        raise ValueError('normal native completion')
    if text.count('PASS native driver17 play-effect ABI and publication')!=1:
        raise ValueError('actual selector-17 preserved ABI')
    count,elapsed,remaining,release,records,size=map(int,one(text,r'^EFFECT_LOOP_COMPLETE count=(\d+) elapsed=(\d+) counter=(\d+) release=(\d+) records=(\d+) bytes=(\d+)$'))
    original=(folder/'mac.log').read_text();mode=one(original,r'^EFFECT_FIXTURE_CASE (\w+)$')
    if count!={'loop0':0,'loop1':1,'loop3':3,'loopnegative':65535}[mode] or remaining:
        raise ValueError('paired counter identity')
    packet=(folder/'packet.bin').read_bytes();native_packet=(native_folder/'native-packet.bin').read_bytes()
    if native_packet[4:20]!=packet[4:20] or native_packet[24:]!=packet[24:]:raise ValueError('paired packet layout')
    raw=(folder/'sample.bin').read_bytes()
    if (native_folder/'native-sample.bin').read_bytes()!=raw:raise ValueError('identical original PCM source')
    pcm=bytes(v^128 for v in raw);output=(native_folder/'native-pcm.bin').read_bytes()
    trace=list(struct.iter_unpack('>7I',(native_folder/'native-trace.bin').read_bytes()))
    if len(trace)!=records or len(output)!=size or sum(row[4] for row in trace)!=size or not trace or trace[-1][4]:
        raise ValueError('complete bounded-fragment capture')
    if any(row[4]>128 or row[5]!=0 for row in trace) or any(row[1]>len(raw) for row in trace):raise ValueError('bounded PCM reads/channel')
    if mode=='loopnegative':
        repeats=(size-len(raw))//512
        if size-len(raw)!=repeats*512 or repeats<10 or not 60<=release<=64:raise ValueError('sustained negative loop and live release')
    else:
        repeats=2 if count==3 else 0
        if release:raise ValueError('unexpected fixture release')
    expected=pcm[:1024]+pcm[512:1024]*repeats+pcm[1024:]
    if output!=expected:raise ValueError('exact repeated PCM and complete tail')
    if trace[-1][2]!=repeats+1 or trace[-1][3]:raise ValueError('exact loop boundary/counter progression')
    expected_counts={65535,0} if count==65535 else set(range(count+1))
    if {row[3] for row in trace}!=expected_counts:raise ValueError('all counter states observed')
    original_end=fields(one(original,r'^DRIVER17_COMPLETE (.*)$'))['elapsed']
    if abs(elapsed-original_end)>4:raise ValueError(f'paired completion timing: native {elapsed}, Mac {original_end}')
    # IRQ 0 begins block 0 and queues block 1. Every subsequent IRQ queues
    # another fragment one block ahead. A missed full block cannot hide here.
    hz=709379;period=443;clock=3546895
    if not 0<(trace[1][6]-trace[0][6])/hz<.005:raise ValueError('first queued fragment at DMA startup')
    worst=0
    for i in range(2,len(trace)):
        expected_seconds=((trace[i-2][4]+1)&~1)*period/clock
        actual_seconds=(trace[i][6]-trace[i-1][6])/hz
        relative=abs(actual_seconds-expected_seconds)/expected_seconds
        worst=max(worst,relative)
        if relative>.25:raise ValueError('late/repeated DMA fragment')
    print(f'PASS paired {mode}: {size} exact PCM bytes, {repeats} repeats, live counters, completion within {abs(elapsed-original_end)} ticks of Mac, bounded IRQ intervals (worst {worst:.1%}), preserved ABI and full cleanup')

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('folder',type=Path);p.add_argument('native_folder',type=Path);p.add_argument('--status',type=int,required=True);p.add_argument('--native-status',type=int,required=True);a=p.parse_args()
    try:check(a.folder,a.status,a.native_folder,a.native_status)
    except (ValueError,OSError,struct.error) as e:p.exit(1,f'FAIL effect stream: {e}\n')
