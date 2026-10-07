#!/usr/bin/env python3
"""Sanitized song-format fixtures and optional original preflight comparison."""
import argparse,os,re,subprocess,tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def check_clock(text,status,decoded):
    if status!=0 or any(x in text for x in ('FAIL','LUA ERROR','timeout','Error in')) or text.count('PASS original song clock events=3736 steps=8785')!=1 or text.count('Exited via the debugger')!=1:
        raise ValueError('original clock completion')
    notes=re.findall(r'^SONG_CLOCK_EVENT n=(\d+) on=(\w+) offset=(\w+) instrument=(\w+) note=(\w+) velocity=(\w+) channel=(\w+) sequence=(\w+) tick=\w+ step=(\w+) countdown=\w+$',text,re.M)
    events=re.findall(r'^SONG_EVENT n=(\d+) on=(\w+) offset=(\w+) instrument=(\w+) note=(\w+) velocity=(\w+) channel=(\w+)$',decoded,re.M)
    timed=re.findall(r'^SONG_TIMED_EVENT n=(\d+) offset=(\w+) pulse=(\w+) step=(\w+)$',decoded,re.M)
    if len(notes)!=3736 or [n[:7] for n in notes]!=events or [(n[0],n[2],n[7],n[8]) for n in notes]!=timed:
        raise ValueError('complete timed note stream')
    print('PASS song clock: 3736 exact live notes at original sequencer steps through pulse 8785')

def check_voices(text,status,decoded,*,song_id=135,total=3736,state_path=None):
    if status!=0 or any(x in text for x in ('FAIL','LUA ERROR','timeout','Error in')) or text.count(f'PASS original song live events={total}')!=1 or text.count('Exited via the debugger')!=1:
        raise ValueError('original voice completion')
    import struct
    state=(state_path or ROOT/'tmp/song-live-initial-state.bin').read_bytes()
    if len(state)!=0x3048 or int.from_bytes(state[0x60:0x62],'big')!=185 or state[0x68:0x6a]!=b'\0\0': raise ValueError('original mixer rate')
    if state[0x11ee:0x11fa].hex()!='000100080000000156ee8ba3': raise ValueError('original output sample clock')
    sample_count=len(re.findall(r'^SONG_SAMPLE id=',decoded,re.M))
    samples={struct.unpack_from('>H',state,0xd7c+2*i)[0]:struct.unpack_from('>I',state,0x57c+4*i)[0]+36 for i in range(sample_count)}
    voices={}
    for line in re.findall(r'^SONG_VOICE .*$',text,re.M):
        fields=dict(re.findall(r'(\w+)=([0-9A-F]+)',line));n=int(fields.pop('n'))
        row={k:int(v,16) for k,v in fields.items()}
        loop=re.search(r' loop=(\w+)/(\w+)',line)
        row['loopStart'],row['loopEnd']=(int(x,16) for x in loop.groups())
        voices.setdefault(n,[]).append(row)
    if set(voices)!=set(range(1,total+1)) or any([v['slot'] for v in rows]!=list(range(6)) for rows in voices.values()): raise ValueError('complete six-voice snapshots')
    events=re.findall(r'^SONG_LIVE_EVENT (n=\d+ on=\w+ offset=\w+ instrument=\w+ note=\w+ velocity=\w+ channel=\w+) ',text,re.M)
    original=re.findall(r'^SONG_EVENT (.*)$',decoded,re.M)
    if events!=original or len(events)!=total: raise ValueError('complete live event identity')
    plans={}
    for n,sample,step,size,start,end,period in re.findall(r'^SONG_PLAN n=(\d+) sample=(\d+) step=(\w+) bytes=(\d+) loop=(\d+)/(\d+) period=(\d+)$',decoded,re.M):
        plans[int(n)]=(int(sample),int(step,16),int(size),int(start),int(end),int(period))
    pitches=[(int(i),int(v,16)) for i,v in re.findall(r'^SONG_PITCH index=(\d+) step=(\w+)$',decoded,re.M)]
    table=struct.unpack_from('>128I',state,0x29bc)
    expected=[(i,v&0xffff0000 if (v&65535)<4 else v) for i,v in enumerate(table)]
    if pitches!=expected: raise ValueError('complete original pitch ratios')
    played=0;dropped=[]
    for n,line in enumerate(events,1):
        fields={k:int(v,16) for k,v in re.findall(r'(\w+)=(\w+)',line) if k!='n'}
        if not fields['on']:
            if any(v['note']==fields['note'] and v['channel']==fields['channel'] and 0<v['active']<0x8000 for v in voices[n]): raise ValueError('note-off release')
            continue
        sample,step,size,start,end,period=plans[n];base=samples[sample]
        matching=[v for v in voices[n] if v['sample']==base and v['instrument']==fields['instrument'] and v['note']==fields['note'] and v['channel']==fields['channel'] and v['active']==0x2710]
        if not matching:
            if not all(0<v['active']<0x8000 for v in voices[n]): raise ValueError('unexplained unallocated note')
            dropped.append(n);continue
        played+=1
        for v in matching:
            if (v['step'],v['start'],v['loopStart'],v['loopEnd'],v['volume'])!=(step,base+size-1,base+start if end else 0,base+end if end else 0,0): raise ValueError('sample pitch/extent/loop/amplitude')
        denominator=step*0x56ee8ba3
        if period!=((3546895<<33)+denominator//2)//denominator: raise ValueError('Paula integer period')
    if song_id==135 and (len(plans)!=1868 or played!=1860 or dropped!=[1813,1817,1821,1825,3683,3687,3691,3695]): raise ValueError('complete original note allocation')
    if played+len(dropped)!=len(plans): raise ValueError('complete note allocation accounting')
    held={n:sum(0<v['active']<0x8000 for v in rows) for n,rows in voices.items()}
    peak=max(held.values());first=next(n for n,count in held.items() if count==peak)
    if song_id==135 and (peak,first)!=(6,74): raise ValueError('original peak held-note voice state')
    print(f'PASS original SONG {song_id} polyphony: peak held notes={peak} first event={first}; release tails excluded')
    print(f'PASS song voices: {played} original sample/pitch/loop plans, {len(dropped)} measured full-voice drops, {total-len(plans)} note-off releases')

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--reference',type=Path);p.add_argument('--status',type=int)
    p.add_argument('--driver',type=Path);p.add_argument('--driver-status',type=int)
    p.add_argument('--clock',type=Path);p.add_argument('--clock-status',type=int)
    p.add_argument('--voices',type=Path);p.add_argument('--voices-status',type=int)
    a=p.parse_args()
    if a.voices and not a.reference: raise ValueError('voices require original inputs')
    if a.clock and not a.reference: raise ValueError('clock requires original inputs')
    with tempfile.TemporaryDirectory(prefix='aitd-song-') as directory:
        work=Path(directory);exe=work/'check'
        subprocess.run([os.environ.get('HOST_CXX','c++'),'-std=c++17','-Wall','-Wextra','-Werror','-fsanitize=address,undefined',str(ROOT/'tools/test_song_inputs.cpp'),'-o',str(exe)],check=True)
        if not a.reference:
            subprocess.run([str(exe)],check=True,timeout=30);return
        text=a.reference.read_text()
        if a.status!=0 or any(x in text for x in ('FAIL','LUA ERROR','timeout','Error in')) or text.count('PASS original song preflight events=3736')!=1 or text.count('Exited via the debugger')!=1:
            raise ValueError('original event completion')
        from check_driver0 import check
        if not a.driver: raise ValueError('missing original ownership capture')
        check(a.driver.read_text(),a.driver_status)
        from resource_fork import read_resource_fork
        resources={(r.kind,r.rid):r.body for r in read_resource_fork(ROOT/'tmp/runtime-data/Alone In The Dark')}
        song=ROOT/'tmp/song-events-song.bin';midi=ROOT/'tmp/song-events-midi.bin'
        if song.read_bytes()!=resources[b'SONG',135] or midi.read_bytes()!=resources[b'MIDI',905]: raise ValueError('captured song/MIDI payload')
        for (kind,rid),body in resources.items():
            if kind in (b'INST',b'snd '): (work/f'{kind.decode().strip()}_{rid}').write_bytes(body)
        run=subprocess.run([str(exe),str(song),str(midi),str(work)],text=True,capture_output=True,timeout=30)
        if run.returncode: raise ValueError(run.stderr.strip() or 'native host fixture failed')
        result=run.stdout
        reference=re.findall(r'^SONG_EVENT .*$',text,re.M);decoded=re.findall(r'^SONG_EVENT .*$',result,re.M)
        if len(reference)!=3736 or reference!=decoded: raise ValueError('complete note/instrument event stream')
        if a.clock: check_clock(a.clock.read_text(),a.clock_status,result)
        if a.voices: check_voices(a.voices.read_text(),a.voices_status,result)
        ids=list(map(int,re.findall(r'^SONG_INSTRUMENT id=(\d+)',result,re.M)))
        state=(ROOT/'tmp/song-events-state.bin').read_bytes()
        if len(state)!=0x3048 or bytes(0 if i in ids else 255 for i in range(128))!=state[0x72:0xf2]: raise ValueError('instrument-use map')
        samples=list(map(int,re.findall(r'^SONG_SAMPLE id=(\d+)',result,re.M)))
        driver=a.driver.read_text();calls=re.findall(r'^DRIVER0_SERVICE_ENTER .*?trap=A9A0 .*?args=(\w+)',driver,re.M)
        original=[int(raw[:4],16) for raw in calls if bytes.fromhex(raw[4:12])==b'snd ']
        if len(samples)!=28 or samples!=original: raise ValueError('sample dependency order')
        if result.count('PASS song resource graph instruments=7 samples=28')!=1: raise ValueError('complete resource graph')
        print('PASS song inputs: 3736 exact original note events, original payloads, 7 instruments/28 samples and bounded format fixtures')
if __name__=='__main__':
    try:main()
    except (ValueError,OSError,KeyError,subprocess.SubprocessError) as error:raise SystemExit('FAIL song inputs: '+str(error))
