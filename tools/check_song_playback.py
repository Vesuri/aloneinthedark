#!/usr/bin/env python3
"""Compare a complete native song fixture with live original events and PCM."""
import argparse,math,re,struct
from pathlib import Path
from resource_fork import read_resource_fork
ROOT=Path(__file__).resolve().parents[1]

def check(reference,reference_status,text,status):
    if reference_status!=0 or any(x in reference for x in ('FAIL','LUA ERROR','timeout','Error in')) or reference.count('PASS original song clock events=3736 steps=8785')!=1 or reference.count('Exited via the debugger')!=1:
        raise ValueError('original completion')
    if status!=0 or any(x in text for x in ('FAIL','Error in','Cannot execute this command','TIMEOUT','Program received signal')) or text.count('PASS native full song: playback, effect priority, PCM variants, cleanup and original MDRV absent')!=1 or text.count('[Inferior 1 (Remote target) detached]')!=1:
        raise ValueError('native completion')
    trace=(ROOT/'tmp/song-probe-events.bin').read_bytes()
    if len(trace)!=3736*40: raise ValueError('complete native event trace')
    events=list(struct.iter_unpack('>10I',trace))
    raw=re.findall(r'^SONG_CLOCK_EVENT n=(\d+) on=(\w+) offset=(\w+) instrument=(\w+) note=(\w+) velocity=(\w+) channel=(\w+) sequence=(\w+) tick=\w+ step=(\w+) countdown=\w+$',reference,re.M)
    if len(raw)!=3736 or [int(row[0]) for row in raw]!=list(range(1,3737)): raise ValueError('complete ordered original events')
    expected=[tuple(int(value,16) for value in row[1:]) for row in raw]
    if [e[:8] for e in events]!=expected: raise ValueError('exact original note/instrument/order/clock')
    result=re.findall(r'^SONG_PROBE_PLAYBACK events=(\d+) pulses=(\d+) starts=(\d+) steals=(\d+) dropped=(\d+) effects=(\d+)/(\d+) tick=(\d+)$',text,re.M)
    if len(result)!=1: raise ValueError('playback completion record')
    total,pulses,starts,steals,dropped,effect_on,effect_off,tick=map(int,result[0])
    if total!=3736 or starts!=1868 or dropped or (effect_on,effect_off)!=(1,1) or pulses<8785 or not steals:
        raise ValueError('complete native voices and effect priority')
    if events[-1][8:]!=(starts,steals): raise ValueError('final voice counters')
    for before,after in zip([(0,)*10]+events,events):
        if after[8]!=before[8]+after[0] or after[9]<before[9] or after[9]-before[9]>2: raise ValueError('event voice accounting')
    resources={(r.kind,r.rid):r.body for r in read_resource_fork(ROOT/'tmp/runtime-data/Alone In The Dark')}
    state=(ROOT/'tmp/song-live-initial-state.bin').read_bytes()
    pitches=struct.unpack_from('>128I',state,0x29bc)
    pcm_records=re.findall(r'^SONG_PROBE_PCM stride=(\d+) period=(\d+) sample=(\d+) note=(\d+) instrument=(\d+) midiChannel=(\d+) channel=(\d+) allocated=(\d+) chip=(\w+) dma=(\w+)$',text,re.M)
    if len(pcm_records)!=2 or [int(r[0]) for r in pcm_records]!=[1,2]: raise ValueError('both PCM variants')
    for row in pcm_records:
        stride,period,sid,note,iid,midi_channel,channel,allocated=map(int,row[:8]);dma=int(row[9],16)
        if channel>3 or not(dma&(1<<channel)): raise ValueError('Paula DMA enabled')
        instrument=resources[b'INST',iid];root=int.from_bytes(instrument[2:4],'big')
        adjusted=note-root+60 if root else note
        selected=int.from_bytes(instrument[:2],'big')
        for row_index in range(int.from_bytes(instrument[12:14],'big')):
            limits=instrument[14+row_index*8:22+row_index*8]
            if (not limits[0] or adjusted>=limits[0]) and (limits[1]>=127 or adjusted<=limits[1]):
                selected=int.from_bytes(limits[2:4],'big') or selected;break
        if sid!=selected or (iid,note,midi_channel) not in [(e[2],e[3],e[5]) for e in expected if e[0]]: raise ValueError('original note/sample selection')
        sample=resources[b'snd ',sid];size,rate,start,end=struct.unpack_from('>4I',sample,18)
        if rate!=11025<<16: raise ValueError('original sample rate')
        pcm=sample[36:36+size];step=pitches[adjusted+60-sample[35]]
        if step&65535<4:step&=0xffff0000
        denominator=step*0x56ee8ba3
        if period!=((3546895*stride<<33)+denominator//2)//denominator or period<124: raise ValueError('measured pitch / legal DMA rate')
        loop=bool(start and end and end!=0xffffffff and ((end-start)&65535)>=100)
        if loop:
            attack=((end+stride-1)//stride+1)&~1
            cycle=(end-start)//math.gcd(end-start,stride);reload=cycle*2 if cycle&1 else cycle
            needed=(attack+reload)*stride
            stream=pcm[:end]+pcm[start:end]*((needed+end-start-1)//(end-start))
            result=bytes(v^128 for v in stream[:needed:stride])+b'\0\0'
        else:
            result=bytes(v^128 for v in pcm[::stride]);result+=b'\0'*(len(result)%2)+b'\0'*4
        actual=(ROOT/f'tmp/song-probe-pcm-{stride}.bin').read_bytes()
        if len(actual)!=allocated or actual!=result: raise ValueError('complete Paula PCM / loop phase / release silence')
    print('PASS native song playback: 3736 exact timed events, two complete PCM/DMA variants, effect priority, natural completion and resource/voice cleanup')

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('reference',type=Path);p.add_argument('native',type=Path)
    p.add_argument('--reference-status',type=int,required=True);p.add_argument('--status',type=int,required=True)
    a=p.parse_args()
    try:check(a.reference.read_text(),a.reference_status,a.native.read_text(),a.status)
    except (ValueError,OSError,KeyError,struct.error) as error:raise SystemExit('FAIL song playback: '+str(error))
