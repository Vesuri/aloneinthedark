#!/usr/bin/env python3
"""Pair native selector-zero return and owned resources with the original capture."""
import argparse,re
from pathlib import Path
from check_driver0 import check as original_check
from resource_fork import read_resource_fork
ROOT=Path(__file__).resolve().parents[1]

def check(reference,reference_status,native,status,clock=None,clock_status=None):
    original_check(reference,reference_status)
    if status!=0 or any(x in native for x in ('FAIL','Cannot execute this command','Error in sourced command','Remote connection closed','timeout','Program received signal')):
        raise ValueError('native completion')
    if native.count('[Inferior 1 (Remote target) detached]')!=1: raise ValueError('normal native debugger completion')
    if native.count('PASS native song return and owned resources')!=1 or native.count('PASS menu-list checkpoint original-MDRV=absent')!=1:
        raise ValueError('positive native ABI/ownership/absence checks')
    if native.count('SONG_NATIVE_BYTES 2F2E000842A7206DF9544E90508F')!=1: raise ValueError('original native caller bytes')
    states=re.findall(r'^SONG_NATIVE_RETURN song=135 midi=905 playing=1 owned=41 samples=28 voices=6/3/1 events=(\d+) pulse=(\d+) step=(\w+)$',native,re.M)
    if len(states)!=1: raise ValueError('native song state')
    events,pulse=int(states[0][0]),int(states[0][1]);step=int(states[0][2],16)
    if not events:
        if pulse or step!=0x423: raise ValueError('initial armed clock')
    else:
        if clock_status!=0 or clock is None or clock.count('PASS original song clock events=3736 steps=8785')!=1 or clock.count('Exited via the debugger')!=1 or any(x in clock for x in ('FAIL','LUA ERROR','timeout','Error in')):
            raise ValueError('advanced playback needs completed original clock evidence')
        rows=re.findall(r'^SONG_CLOCK_EVENT n=(\d+).* sequence=(\w+) tick=\w+ step=(\w+) countdown=\w+$',clock,re.M)
        if len(rows)!=3736 or [int(row[0]) for row in rows]!=list(range(1,3737)): raise ValueError('original event sequence')
        due=[row for row in rows if int(row[1],16)<=pulse]
        if len(due)!=events or events>=len(rows): raise ValueError('advanced event count at original pulse')
        # This captured interval has the same tempo at both bounding notes.
        if int(due[-1][2],16)!=step or int(rows[events][2],16)!=step: raise ValueError('unmeasured tempo boundary')
    resources={(r.kind,r.rid):r.body for r in read_resource_fork(ROOT/'tmp/runtime-data/Alone In The Dark')}
    order=[(b'SONG',135),(b'MIDI',905)]+[(b'SMOD',i) for i in range(4)]
    samples=[]
    for iid in (0,1,11,22,26,28,31):
        order.append((b'INST',iid));inst=resources[b'INST',iid]
        ids=[int.from_bytes(inst[:2],'big')]+[int.from_bytes(inst[16+8*i:18+8*i],'big') for i in range(int.from_bytes(inst[12:14],'big'))]
        for sid in ids:
            if sid and sid not in samples:samples.append(sid);order.append((b'snd ',sid))
    records=re.findall(r'^SONG_NATIVE_RESOURCE n=(\d+) type=(\w+) id=(\d+) handle=(\w+) body=(\w+) bytes=(\d+) flags=(\w+)$',native,re.M)
    if len(records)!=len(order): raise ValueError('owned resource count')
    handles=set();bodies=set()
    for index,(record,key) in enumerate(zip(records,order)):
        n,kind,rid,handle,body,size,flags=record
        if int(n)!=index or (int(kind,16).to_bytes(4,'big'),int(rid))!=key: raise ValueError('owned resource order')
        if int(flags,16)!=0x81 or handle in handles or body in bodies: raise ValueError('unique locked/nonpurgeable resource ownership')
        handles.add(handle);bodies.add(body)
        data=(ROOT/f'tmp/song-native-resource-{index}.bin').read_bytes()
        if int(size)!=len(data) or data!=resources[key]: raise ValueError('complete retained resource payload')
    print('PASS native song start: original ABI, armed MIDI 905, 41 detached locked resources, exact complete payloads, MDRV absent')

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('reference',type=Path);p.add_argument('native',type=Path)
    p.add_argument('--reference-status',type=int,required=True);p.add_argument('--status',type=int,required=True)
    p.add_argument('--clock',type=Path);p.add_argument('--clock-status',type=int)
    a=p.parse_args()
    try:check(a.reference.read_text(),a.reference_status,a.native.read_text(),a.status,a.clock.read_text() if a.clock else None,a.clock_status)
    except (ValueError,OSError,KeyError) as error:raise SystemExit('FAIL song start: '+str(error))
