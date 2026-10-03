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
    needed=set()
    for on,offset,iid,note,velocity,channel,sequence,step in expected:
        if not on: continue
        instrument=resources[b'INST',iid];root=int.from_bytes(instrument[2:4],'big')
        adjusted=note-root+60 if root else note
        sid=int.from_bytes(instrument[:2],'big')
        for i in range(int.from_bytes(instrument[12:14],'big')):
            row=instrument[14+i*8:22+i*8]
            if (not row[0] or adjusted>=row[0]) and (row[1]>=127 or adjusted<=row[1]):
                sid=int.from_bytes(row[2:4],'big') or sid;break
        sample=resources[b'snd ',sid];pitch=pitches[adjusted+60-sample[35]]
        if pitch&65535<4:pitch&=0xffff0000
        denominator=pitch*0x56ee8ba3;stride=1
        while ((3546895*stride<<33)+denominator//2)//denominator<124 and stride<16:stride*=2
        needed.add((sid,stride))
    cached=re.findall(r'^SONG_PROBE_CACHE sample=(\d+) stride=(\d+) allocated=(\d+)$',text,re.M)
    keys=[(int(sid),int(stride)) for sid,stride,size in cached]
    if len(keys)!=len(set(keys)) or set(keys)!=needed:raise ValueError('complete retained sample/stride set')
    total_bytes=0
    for sid,stride,allocated in cached:
        sid,stride,allocated=map(int,(sid,stride,allocated));sample=resources[b'snd ',sid]
        size,rate,start,end=struct.unpack_from('>4I',sample,18);pcm=sample[36:36+size]
        loop=bool(start and end and end!=0xffffffff and ((end-start)&65535)>=100)
        attack=(((end if loop else size)+stride-1)//stride+1)&~1
        cycle=(end-start)//math.gcd(end-start,stride) if loop else 2
        reload=cycle*2 if cycle&1 else cycle
        cursor=0;result=bytearray()
        for i in range(attack+reload):
            result.append(pcm[cursor]^128 if cursor<size else 0)
            for k in range(stride):
                cursor+=1
                if loop and cursor==end:cursor=start
        result+=b'\0\0'
        actual=(ROOT/f'tmp/song-cache-{sid}-{stride}.bin').read_bytes()
        if allocated!=len(result) or actual!=result:raise ValueError('retained PCM bytes, padding or loop phase')
        total_bytes+=allocated
    if text.count(f'SONG_PROBE_CACHE_TOTAL entries={len(needed)} bytes={total_bytes}')!=1:
        raise ValueError('retained PCM memory accounting')
    print(f'PASS native song playback: 3736 exact timed events, {len(needed)} retained PCM variants ({total_bytes} bytes), effect priority, natural completion and resource/voice cleanup')

def check_interrupt(text):
    rows=re.findall(r'^SONG_PROBE_INTERRUPT stalledTicks=(\d+) events=(\d+) started=(\d+)$',text,re.M)
    if len(rows)!=1:raise ValueError('interrupt progress record')
    stalled,progress,started=map(int,rows[0])
    if stalled<180 or not progress:raise ValueError('music did not progress during CPU-only work')
    events=list(struct.iter_unpack('>10I',(ROOT/'tmp/song-probe-events.bin').read_bytes()))
    raw=(ROOT/'tmp/song-probe-delivery.bin').read_bytes()
    if len(raw)!=len(events)*8:raise ValueError('complete note delivery trace')
    deliveries=list(struct.iter_unpack('>2I',raw));previous=started;maximum=0
    for event,(intended,actual) in zip(events,deliveries):
        if intended!=started+event[6] or actual<previous:raise ValueError('note delivery clock/order')
        late=actual-intended
        # PAL converts 50 fields into 60 logical ticks. The earlier of a
        # two-tick field can arrive one logical tick late, never in a later VBI.
        if late<0 or late>1:raise ValueError(f'note delivery late by {late} ticks')
        maximum=max(maximum,late);previous=actual
    print(f'PASS interrupt music: {progress} events during {stalled} CPU-only ticks; {len(events)} deliveries, maximum lateness {maximum} tick')

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('reference',type=Path);p.add_argument('native',type=Path)
    p.add_argument('--reference-status',type=int,required=True);p.add_argument('--status',type=int,required=True)
    p.add_argument('--interrupt',action='store_true',help='Require CPU-stall progress and actual note-delivery checks')
    a=p.parse_args()
    try:
        text=a.native.read_text()
        check(a.reference.read_text(),a.reference_status,text,a.status)
        if a.interrupt:check_interrupt(text)
    except (ValueError,OSError,KeyError,struct.error) as error:raise SystemExit('FAIL song playback: '+str(error))
