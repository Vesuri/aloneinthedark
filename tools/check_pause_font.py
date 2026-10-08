#!/usr/bin/env python3
"""Require a paired original/native pause draw, physical publication and resume."""
import argparse,re,struct
from pathlib import Path
from check_menu_keyboard import require

def check(folder,prefix,run,status):
    require(status==0,'native runner status')
    log=(folder/(prefix+'-gdb.log')).read_text()
    terminal=(run/'run.log').read_text()
    require('[Inferior 1 (Remote target) detached]' in terminal and 'FAIL FULLPLAY' not in terminal,'clean native completion')
    require(not re.search(r'FAIL|TIMEOUT|Error in|Program received signal',log),'observer error')
    require(log.count('PAUSE_FONT_ENTRY font=20 size=36 style=0 mode=1 pen=13,81 fraction=32768 count=19')==1,'reached text state')
    require(log.count('PAUSE_FONT_RETURN pen=307 spDelta=8')==1,'native pen and Pascal stack')
    completion=f'PASS paired original DrawText {prefix} input/state matched; pen=307; original pixels restored\n'
    require((folder/(prefix+'-mac-check.txt')).read_text()==completion,'original replay completion')
    before=(folder/(prefix+'-before.bin')).read_bytes()
    after=(folder/(prefix+'-after.bin')).read_bytes()
    original=(folder/(prefix+'-mac-after.bin')).read_bytes()
    require(len(before)==len(after)==len(original)==307200,'buffer extents')
    require(after==original,'paired original/native complete screen bytes')
    require(sum(a!=b for a,b in zip(before,after))>500,'positive text coverage')
    port=(folder/(prefix+'-port.bin')).read_bytes();require(len(port)==108,'port extent')
    require(struct.unpack_from('>hhhh',port,16)==(0,0,200,320),'window coordinates')
    planes=(folder/(prefix+'-scanout.bin')).read_bytes();require(len(planes)==64000,'physical extent')
    screen=(run/'screen-6.bin').read_bytes();require(len(screen)==307200,'published screen extent')
    logical=b''.join(screen[y*640+160:y*640+480] for y in range(150,350))
    physical=bytes(sum(((planes[y*320+p*40+x//8]>>(7-x%8))&1)<<p for p in range(8)) for y in range(200) for x in range(320))
    require(physical==logical,'physical/logical pause publication')
    require(screen==after,'published complete draw')
    frames={int(n):int(f) for n,f in re.findall(r'FULLPLAY_STATE sequence=(\d+) tick=\d+ status=\d+ frames=(\d+)',log)}
    require(frames[5]==frames[6] and frames[8]>frames[6],'paused publication stable and gameplay resumes')
    states=[(run/f'world-{i}.bin').read_bytes() for i in (4,5,6,7,8)]
    require(all(len(b)==75616 for b in states),'world capture extents')
    anchor=75616-0xb292+160
    identity=lambda b:tuple(struct.unpack_from('>h',b,anchor+o)[0] for o in (0,2,28,30,32,40,42,44,46,48))
    require(all(identity(b)==identity(states[0]) for b in states),'unchanged room and hero position through pause/resume')
    print(f'PASS {prefix}: paired Times36 draw exact (307200 bytes); physical pause matches; ordinary resume publishes gameplay')

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--capture-dir',type=Path,required=True);p.add_argument('--prefix',required=True);p.add_argument('--run',type=Path,required=True);p.add_argument('--status',type=int,required=True);a=p.parse_args()
    try:check(a.capture_dir,a.prefix,a.run,a.status)
    except (ValueError,OSError,KeyError) as error:raise SystemExit('FAIL pause font: '+str(error))
