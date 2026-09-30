#!/usr/bin/env python3
"""Compare original/native offscreen initialization bytes, ABI and pixels."""
from pathlib import Path
import re,sys,hashlib
import argparse
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('reference',type=Path);p.add_argument('native',type=Path)
p.add_argument('--reference-status',type=int,required=True);p.add_argument('--native-status',type=int,required=True)
a=p.parse_args()
assert a.reference_status==a.native_status==0, 'normal run exits required'
from resource_fork import read_resource_fork
steps=[0x8e,0x98,0xa8,0xb0,0xbe,0xcc,0xd4,0x114]
code=next(r.body for r in read_resource_fork(Path('tmp/runtime-data/Alone In The Dark')) if r.kind==b'CODE' and r.rid==10)[0x76:0x116]
assert hashlib.sha256(code).hexdigest()=='6c1c59823b41b3d2087b587439adc5b81dc63377ef8dab2eaed88b5813ed8b70'
records={};captures={}
for side,log in [('reference',a.reference),('native',a.native)]:
 text=Path(log).read_text()
 assert not any(x in text for x in ('FAIL ','Error in','LUA ERROR','TIMEOUT','Program received signal'))
 assert text.count('PASS '+('original' if side=='reference' else 'native')+' offscreen initialization')==1
 assert text.count('Exited via the debugger' if side=='reference' else '[Inferior 1 (Remote target) detached]')==1
 assert Path(f'tmp/gworld-init-{side}-original-code.bin').read_bytes()==code
 records[side]={};captures[side]={}
 for step in steps:
  rr=[]
  for phase in ['before','after']:
   matches=re.findall(rf'^GWINIT offset={step:X} phase={phase} (.*)$',text,re.M);assert len(matches)==1
   r={k:int(v,16) for k,v in re.findall(r'(\w+)=([\dA-Fa-f]+)',matches[0])};rr.append(r)
   captures[side][step,phase]={obj:Path(f'tmp/gworld-init-{side}-{step:03x}-{phase}-{obj}.bin').read_bytes() for obj in ['port','pm','device-pm','device','clip','pixels','stack']}
  e,r=rr;records[side][step]=rr
  if side=='native':
   assert r['currentPort']==(e['world'] if step!=0x114 else r['A0']), 'bound drawing port'
  assert r['sp']-e['sp']==(8 if step in [0x8e,0x114] else 4)
  for reg in ['D3','D4','D5','D6','D7','A2','A3','A4','A5','A6']:assert e[reg]==r[reg],(side,step,reg)
  before=captures[side][step,'before'];after=captures[side][step,'after']
  arg=int.from_bytes(before['stack'][:4],'big')
  if step==0x8e:
   assert arg==0 and int.from_bytes(before['stack'][4:8],'big')==e['world']
   assert r['D0']==0x8c001
  elif step in [0x98,0xbe]:assert arg==e['world']+16 and r['D0']==0
  elif step in [0xa8,0xcc]:assert arg==e['world'] and r['A0']==e['world'] and r['D0']==0x40017
  elif step in [0xb0,0xd4]:assert arg==e['pmh']
  elif step==0x114:
   assert arg==r['A1'] and int.from_bytes(before['stack'][4:8],'big')==r['A0'] and r['D0']==0x8c000
  if step!=0xbe:
   assert e['D1']==r['D1'] and e['D2']==r['D2'], (side,step,'preserved scratch')

  for obj in ['port','device','device-pm']:assert before[obj]==after[obj],(side,step,obj)
  if step!=0xbe:assert before['pixels']==after['pixels'],(side,step,'pixels')
  if step in [0xb0,0xd4]:
   assert r['D0']==0 and r['A0']==r['pixelh']
   assert int.from_bytes(after['pm'][14:16],'big')==(1 if step==0xb0 else 2)
  if step in [0xa8,0xcc]:assert int.from_bytes(after['stack'][:4],'big')==r['pmh']
  if step==0xb0:assert after['stack'][0]==1
 for y in range(401):
  before=captures[side][0xbe,'before']['pixels'];after=captures[side][0xbe,'after']['pixels']
  assert after[y*652:y*652+648]==bytes(648)
  assert after[y*652+648:(y+1)*652]==before[y*652+648:(y+1)*652]
for step in steps:
 for phase in ['before','after']:
  for obj,ptrs in [('port',[2,8,24,28,32,58,62]),('pm',[0,42]),('device-pm',[0,42]),('device',[6,22]),('clip',[])]:
   vals=[]
   for side in ['reference','native']:
    data=bytearray(captures[side][step,phase][obj])
    for i in ptrs:data[i:i+4]=bytes(4)
    vals.append(data)
   assert vals[0]==vals[1],(step,phase,obj,[(i,x,y) for i,(x,y) in enumerate(zip(*vals)) if x!=y])
assert Path('tmp/gworld-init-native-screen-before.bin').read_bytes()==Path('tmp/gworld-init-native-screen-after.bin').read_bytes()
print('PASS paired initialization: original bytes, eight call returns, records, 259848 cleared pixels, preserved padding and unchanged native screen')

text=a.native.read_text()
assert re.findall(r'^GWLOCK state=([0-9A-F]+)$',text,re.M)==['1','1','1','81','81','81','1','1']
assert 'GWINIT_NEXT trap=AB1D selector=F segment=10 offset=2DA manager=QUICKDRAW routine=GETPIXBASEADDR' in text
print('PASS native real heap lock states and named GetPixBaseAddr progression')
