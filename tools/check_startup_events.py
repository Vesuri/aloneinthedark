#!/usr/bin/env python3
"""Compare original startup events, their ABI, and guarded EventRecord writes."""
import argparse,re,struct
from pathlib import Path
from resource_fork import read_resource_fork
ROOT=Path(__file__).resolve().parents[1]
def rows(text,kind):
    return [dict(re.findall(r'(\w+)=([0-9A-Fa-f]+)(?: |$)',s)) for s in re.findall(r'^WNE_'+kind+r' (.*)$',text,re.M)]
def check(text,status,native):
    if status!=0 or any(x in text for x in ('FAIL','Error in','LUA ERROR','timeout')):raise ValueError('terminal completion')
    counts=re.findall(r'^PASS native startup events calls=(\d+)$',text,re.M)
    count=int(counts[0]) if native and len(counts)==1 else 8
    if native and (len(counts)!=1 or count<4):raise ValueError('native event count')
    marker=f'PASS native startup events calls={count}' if native else 'PASS WaitNextEvent original calls=8'
    end='[Inferior 1 (Remote target) detached]' if native else 'Exited via the debugger'
    if text.count(marker)!=1 or text.count(end)!=1:raise ValueError('positive completion')
    code=next(r.body for r in read_resource_fork(ROOT/'tmp/runtime-data/Alone In The Dark') if r.kind==b'CODE' and r.rid==7)
    caller='42273F3CFFFF2F2E000C42A742A7A860'
    if code[0x44e2:0x44f2].hex().upper()!=caller or re.findall(r'^WNE_BYTES (\w+)$',text,re.M)!=[caller]:raise ValueError('original/live caller')
    entries,returns=rows(text,'ENTER'),rows(text,'RETURN')
    if len(entries)!=count or len(returns)!=count:raise ValueError('call count')
    guards=re.findall(r'^WNE_GUARD phase=(ENTER|RETURN) n=(\d+) data=(\w+)$',text,re.M)
    if len(guards)!=count*2:raise ValueError('guard count')
    events=[]
    for i,(a,b) in enumerate(zip(entries,returns),1):
        if int(a['n'])!=i or a['n']!=b['n'] or a['args']!=b['args'] or a['event']!=b['event']:raise ValueError('call identity')
        # Popped arguments are dead stack storage: an interrupt may reuse them
        # before the return-PC observer. Only the result word remains live.
        before,after=bytes.fromhex(a['stack']),bytes.fromhex(b['stack'])
        if before[:8]!=bytes(8) or before[12:14]!=b'\xff\xff':raise ValueError('arguments')
        event=struct.unpack('>HIIhhH',bytes.fromhex(b['record']));what,message,when,v,h,mods=event
        expected=0x100 if what else 0
        if int.from_bytes(after[14:16],'big')!=expected or int(b['D0'],16)!=expected:raise ValueError('Boolean/D0')
        if int(b['A7'],16)!=int(a['args'],16)+14:raise ValueError('stack cleanup')
        for r in [f'D{j}' for j in range(3,8)]+[f'A{j}' for j in range(2,7)]:
            if a[r]!=b[r]:raise ValueError('preserved '+r)
        ga,gb=guards[(i-1)*2:i*2]
        if ga[:2]!=('ENTER',str(i)) or gb[:2]!=('RETURN',str(i)):raise ValueError('guard order')
        ga,gb=bytes.fromhex(ga[2]),bytes.fromhex(gb[2])
        if len(ga)!=24 or len(gb)!=24 or ga[:4]!=gb[:4] or ga[20:]!=gb[20:] or gb[4:20]!=bytes.fromhex(b['record']):raise ValueError('guarded write')
        if what!=23:
            if not int(a['ticks'],16)<=when<=int(b['ticks'],16):raise ValueError('event clock')
            if mods!=(0x81 if what==8 else 0x80):raise ValueError('idle/activation modifiers')
        events.append(event)
    kinds=[e[0] for e in events]
    if kinds!=([8,6,6]+[0]*(count-3) if native else [8,23,6,6,0,0,0,0]):raise ValueError('startup event sequence')
    if native:
        from check_native_driver import check as startup
        startup(text,status)
        states=re.findall(r'^WNE_STATE n=(\d+) mouse=(\d+)/(\d+) front=([0-9A-F]+) behind=([0-9A-F]+)$',text,re.M)
        if len(states)!=count:raise ValueError('native event sources')
        for i,(event,state) in enumerate(zip(events,states)):
            _,message,_,v,h,_=event
            if int(state[0])!=i+1 or (h,v)!=(int(state[1]),int(state[2])):raise ValueError('live mouse')
            expected=int(state[3 if i<2 else 4],16) if i<3 else 0
            if message!=expected:raise ValueError('live window/null message')
    else:
        if events[0][1]!=events[2][1] or events[3][1]==events[0][1] or any(e[1] for e in events[4:]):raise ValueError('reference window/null message')
        if events[1][1]!=0x61657674 or struct.pack('>hh',*events[1][3:5])!=b'oapp':raise ValueError('Finder launch event')
    return events
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('reference',type=Path);p.add_argument('--reference-status',required=True,type=int);p.add_argument('--native',type=Path);p.add_argument('--native-status',type=int);a=p.parse_args()
    try:
        check(a.reference.read_text(),a.reference_status,False)
        if a.native:check(a.native.read_text(),a.native_status,True)
        print('PASS startup events: activation, window updates, null event, original bytes, live sources, guarded records and ABI; Finder launch is reference-only')
    except (ValueError,KeyError,OSError) as e:raise SystemExit('FAIL startup events: '+str(e))
