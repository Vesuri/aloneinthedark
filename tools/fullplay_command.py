#!/usr/bin/env python3
"""Queue ordinary keys at a paused fullplay.gdb checkpoint; read original state."""
import argparse,json,os,re,struct,time
from pathlib import Path
KEYS=('up','down','left','right','space','return','escape','f','o','shift','p','amiga','s')
def state(folder,index):
    data=(folder/f'world-{index}.bin').read_bytes()
    variables=(folder/f'vars-{index}.bin').read_bytes()
    if len(data)!=75616 or len(variables)!=400:raise ValueError('incomplete capture')
    word=lambda offset:struct.unpack_from('>h',data,75616+offset)[0]
    actor=-0xb292+160
    result={name:word(actor+offset) for name,offset in
            (('actor',0),('body',2),('x',28),('z',32),('beta',42),('floor',46),('room',48),('animation',62),('track',82))}
    values=struct.unpack('>200h',variables)
    count=word(-0xd8a6)
    if not 0<=count<=30:raise ValueError('invalid inventory count')
    result.update(sequence=index,health=values[21],action=values[90],
                  inventory=[word(-0xd8a4+2*i) for i in range(count)])
    return result

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('folder',type=Path);p.add_argument('--keys',default='')
    p.add_argument('--ticks',type=int,default=30);p.add_argument('--read',action='store_true')
    p.add_argument('--until',help='state condition, e.g. x<=-4000 or beta~=768')
    p.add_argument('--timeout',type=int,default=60)
    p.add_argument('--guest-command',type=Path,default=Path('amiga/.run-m6-fullplay/dh1/M6Control'))
    a=p.parse_args();folder=a.folder.resolve()
    indices=[int(x.name[6:]) for x in folder.glob('ready-*') if x.name[6:].isdigit()]
    if not indices:raise ValueError('no initial fullplay checkpoint')
    previous=max(indices)
    if a.read:print(json.dumps(state(folder,previous)));return
    names=a.keys.split(',') if a.keys else []
    if any(k not in KEYS for k in names) or not 1<=a.ticks<=3600:raise ValueError('invalid keys or duration')
    mask=sum(1<<KEYS.index(k) for k in set(names));index=previous+1
    field=mode=target=0
    if a.until:
        match=re.fullmatch(r'(x|z|beta|floor|room|animation)(>=|<=|~=)(-?\d+)',a.until)
        if not match:raise ValueError('invalid state condition')
        name,operator,value=match.groups();target=int(value)
        field=('x','z','beta','floor','room','animation').index(name)+1
        mode={'>=':1,'<=':2,'~=':3}[operator]
        if not -32768<=target<=32767 or (mode==3 and field!=3):raise ValueError('invalid condition target')
    command=dict(sequence=index,keys=names,mask=mask,ticks=a.ticks,condition=a.until)
    # Never overwrite a pending command or replay a command from another run.
    with (folder/f'command-{index}.json').open('x') as f:json.dump(command,f)
    destination=a.guest_command.resolve()
    temporary=destination.with_suffix('.tmp')
    temporary.write_bytes(struct.pack('>IIIIiI',index,mask,a.ticks,field,target,mode))
    temporary.replace(destination)
    message='continue\n'
    fd=os.open(folder/'commands',os.O_WRONLY|os.O_NONBLOCK)
    try:os.write(fd,message.encode('ascii'))
    finally:os.close(fd)
    deadline=time.monotonic()+a.timeout
    while not (folder/f'ready-{index}').exists():
        if time.monotonic()>deadline:raise TimeoutError(f'command {index} remains pending; inspect runner log')
        time.sleep(.1)
    result=state(folder,index);(folder/f'state-{index}.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result))
if __name__=='__main__':
    try:main()
    except (ValueError,OSError,TimeoutError) as error:raise SystemExit('FAIL fullplay command: '+str(error))
