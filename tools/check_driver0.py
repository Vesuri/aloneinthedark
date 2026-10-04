#!/usr/bin/env python3
"""Check original selector-zero loading, owned resources and armed-song state."""
import argparse,re,struct
from pathlib import Path
from check_driver22 import fields,one,ROOT
from resource_fork import read_resource_fork

def check(text,status,song=135,prefix=None):
    measured={135:(285,73,905,[0,1,11,22,26,28,31]),
              136:(203,53,906,[0,1,11,13,23,28]),
              137:(237,62,907,[0,1,2,3,10,11,28])}
    if song not in measured: raise ValueError('unsupported reference song')
    services,requests_expected,midi,used=measured[song]
    prefix=prefix or ROOT/'tmp/driver0-reference'
    capture=lambda name:Path(str(prefix)+'-'+name+'.bin').read_bytes()
    if status!=0 or any(x in text for x in ('FAIL','LUA ERROR','timeout','Error in')) or text.count(f'PASS original driver0 call and service contracts calls={services}')!=1 or text.count('Exited via the debugger')!=1:
        raise ValueError('reference completion')
    resources={(r.kind,r.rid):r.body for r in read_resource_fork(ROOT/'tmp/runtime-data/Alone In The Dark')}
    code=resources[b'CODE',3]
    raw=code[0x1382:0x1390]
    if raw.hex()!='2f2e000842a7206df9544e90508f' or one(text,r'^DRIVER0_BYTES (\w+)$')!=raw.hex().upper(): raise ValueError('original/live caller')
    driver=capture('driver')
    original=(ROOT/'tmp/plan/MDRV_11.bin').read_bytes()
    if driver[:0x41a8]!=original[:0x41a8] or driver[0x34:0x38].hex()!='600001d0': raise ValueError('original driver instructions')
    e,r=[fields(one(text,r'^DRIVER0_'+phase+r' (.*)$')) for phase in ('ENTER','RETURN')]
    if e['selector']!=0 or e['argument']!=song or r['sp']!=e['sp'] or r['d0']!=0: raise ValueError('call ABI/result')
    for reg in [f'd{i}' for i in range(2,8)]+[f'a{i}' for i in range(7)]:
        if e[reg]!=r[reg]: raise ValueError('preserved '+reg)
    entries=[fields(s) for s in re.findall(r'^DRIVER0_SERVICE_ENTER (.*)$',text,re.M)]
    returns=[fields(s) for s in re.findall(r'^DRIVER0_SERVICE_RETURN (.*)$',text,re.M)]
    if len(entries)!=services or len(returns)!=services: raise ValueError('service pairs')
    # n is printed decimal; fields parses hex, so compare the original token sequence.
    for phase in ('ENTER','RETURN'):
        if list(map(int,re.findall(r'^DRIVER0_SERVICE_'+phase+r' n=(\d+)',text,re.M)))!=list(range(1,services+1)): raise ValueError('service order')
    handles={};bodies={};detached=set();locked=set();nonpurge=set();requests=[]
    for a,b in zip(entries,returns):
        trap=a['trap'];offset=a['offset'];args=a['args'].to_bytes(20,'big')
        if a['n']!=b['n'] or trap!=b['trap'] or int.from_bytes(driver[offset:offset+2],'big')!=trap: raise ValueError('service identity/bytes')
        if trap==0xa9a0:
            key=(args[2:6],int.from_bytes(args[:2],'big',signed=True));requests.append(key)
            handle=b['args']>>(16*8)
            if bool(handle)!=(key in resources): raise ValueError('resource presence')
            if b['sp']!=a['sp']+6: raise ValueError('resource stack')
            if handle:
                if handle in handles: raise ValueError('owned resource alias')
                handles[handle]=key
        elif trap==0xa992:
            handle=int.from_bytes(args[:4],'big')
            if handle: detached.add(handle)
            if b['sp']!=a['sp']+4: raise ValueError('detach stack')
        elif trap==0xa064: nonpurge.add(a['a0'])
        elif trap==0xa029: locked.add(a['a0'])
        elif trap==0xa055:
            if b['d0']!=a['d0']&0xffffff or a['a0'] not in handles: raise ValueError('clean owned body')
            bodies[handles[a['a0']]]=b['d0']
    expected=[(b'SONG',song),(b'MIDI',midi)]
    if song==135: expected += [(b'SMOD',i) for i in range(4)]
    samples=[]
    for instrument in used:
        expected.append((b'INST',instrument));data=resources[b'INST',instrument]
        ids=[int.from_bytes(data[:2],'big')]+[int.from_bytes(data[16+8*i:18+8*i],'big') for i in range(int.from_bytes(data[12:14],'big'))]
        for rid in ids:
            if rid not in samples: samples.append(rid);expected.append((b'snd ',rid))
    if list(handles.values())!=expected or len(requests)!=requests_expected: raise ValueError('resource dependency order')
    if set(handles)!=detached or set(handles)!=locked or set(handles)!=nonpurge: raise ValueError('detached/locked/nonpurgeable ownership')
    state=capture('return-state')
    if len(state)!=0x3048: raise ValueError('complete state')
    word=lambda o:struct.unpack_from('>H',state,o)[0]
    long=lambda o:struct.unpack_from('>I',state,o)[0]
    nested=[fields(row) for row in re.findall(r'^DRIVER0_NESTED (.*)$',text,re.M)]
    if any(row['selector']!=20 for row in nested): raise ValueError('unmeasured nested driver selector')
    command,argument=(nested[-1]['selector'],nested[-1]['argument']) if nested else (0,song)
    if (long(0),long(4),word(8),long(0x10),word(0x36),word(0x38),word(0x2f74))!=(command,argument,0,0xffffffff,0xff00,0,song): raise ValueError('armed song state')
    if [i for i,v in enumerate(state[0x72:0xf2]) if v!=255]!=used: raise ValueError('preflight instrument use')
    if [word(o) for o in (0x11c0,0x11c2,0x11c4)]!=[6,3,1] or word(0x11ba)!=0x2205: raise ValueError('SONG configuration')
    if long(0x6a)!=bodies[b'SONG',song] or long(0x6e)!=bodies[b'MIDI',midi]: raise ValueError('song/MIDI ownership')
    for i in range(4):
        expected=bodies[b'SMOD',i] if song==135 else struct.unpack_from('>I',capture('enter-state'),0x2ef0+4*i)[0]
        if not expected or long(0x2ef0+4*i)!=expected: raise ValueError('modifier ownership')
    for i,rid in enumerate(samples):
        if word(0xd7c+2*i)!=rid or long(0x57c+4*i)!=bodies[b'snd ',rid]: raise ValueError('sample ownership')
    if long(0x57c+4*len(samples))!=0 or word(0xd7c+2*len(samples))!=0: raise ValueError('sample terminator')
    for i in range(128):
        expected=bodies[b'INST',i] if i in used else 0
        if long(0x174+8*i)!=expected: raise ValueError('instrument ownership')
    if state[0x1a28]!=0x46 or word(0x2132)!=midi or long(0x1c68)!=bodies[b'MIDI',midi]+22: raise ValueError('initial MIDI track')
    print(f'PASS original driver0: ABI, {services} service pairs, {len(handles)} owned resources, {len(used)} instruments/{len(samples)} samples, armed MIDI {midi}')
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('reference',type=Path);p.add_argument('--status',type=int,required=True);p.add_argument('--song',type=int,default=135);p.add_argument('--prefix',type=Path);a=p.parse_args()
    try: check(a.reference.read_text(),a.status,a.song,a.prefix)
    except (ValueError,OSError,KeyError) as e: raise SystemExit('FAIL driver0: '+str(e))
