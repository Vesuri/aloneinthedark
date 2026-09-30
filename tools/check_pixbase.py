#!/usr/bin/env python3
"""Compare original pixel-address contracts and the ensuing original row copy."""
from pathlib import Path
import re
import argparse,hashlib,re
from resource_fork import read_resource_fork
p=argparse.ArgumentParser();p.add_argument('reference',type=Path);p.add_argument('native',type=Path);p.add_argument('--reference-status',type=int,required=True);p.add_argument('--native-status',type=int,required=True);a=p.parse_args()
assert a.reference_status==a.native_status==0
code=next(r.body for r in read_resource_fork(Path('tmp/runtime-data/Alone In The Dark')) if r.kind==b'CODE' and r.rid==10)
assert hashlib.sha256(code[0x2ac:0x2dc]).hexdigest()=='1a629f339fc613c783d30253999e7d72daa777d10837e76747eb0dc21c86ba2a'
def read(side,name):return Path(f'tmp/pixbase-{side}-{name}.bin').read_bytes()
rows={}
for side,path in [('reference',a.reference),('native',a.native)]:
 text=path.read_text();assert not any(x in text for x in ['FAIL','Error in','LUA ERROR','TIMEOUT','Program received signal'])
 marker='PASS original GetPixBaseAddr locked and unlocked' if side=='reference' else 'PASS native GetPixBaseAddr original-MDRV=absent'
 assert text.count(marker)==1
 assert text.count('Exited via the debugger' if side=='reference' else '[Inferior 1 (Remote target) detached]')==1
 assert read(side,'original-code')==code[0x2ac:0x2dc]

 rows[side]={phase:{k:int(v,16) for k,v in re.findall(r'(\w+)=([\dA-Fa-f]+)',line)} for phase,line in re.findall(r'^PBASE phase=(\S+) (.*)$',text,re.M)}
 relocated=bytearray(read(side,'copy-code'));assert int.from_bytes(relocated[16:20],'big')==rows[side]['locked-before']['A5']+int.from_bytes(code[0x678:0x67c],'big')
 relocated[16:20]=code[0x678:0x67c];assert relocated==code[0x668:0x68a]
 phases=['locked','unlocked'] if side=='reference' else ['locked']
 for phase in phases:
  e,r=rows[side][phase+'-before'],rows[side][phase+'-after']
  assert r['sp']==e['sp']+4 and e['result']==e['handle'] and r['result']==e['pixels'] and r['A1']==e['pm']
  if phase=='locked':assert r['D0']==0x40001 and r['A0']==e['pixels']
  else:
   assert r['D0']==e['pixels'] and r['A0']==int.from_bytes(read(side,'unlocked-before-pm')[:4],'big')
  for reg in ['D1','D2','D3','D4','D5','D6','D7','A2','A3','A4','A5','A6']:assert e[reg]==r[reg],(side,phase,reg)
  for obj in ['pm','pixels']:assert read(side,phase+'-before-'+obj)==read(side,phase+'-after-'+obj)
 source=read(side,'copy-source');before=read(side,'copy-before');after=read(side,'copy-after')
 assert len(source)==28672 and len(before)==len(after)==29120
 assert int.from_bytes(read(side,'copy-after-pm')[14:16],'big')==2
 for y in range(56):
  assert after[y*520:y*520+512]==source[y*512:(y+1)*512],(side,y,'row copy')
  assert after[y*520+512:(y+1)*520]==before[y*520+512:(y+1)*520],(side,y,'padding')
assert read('reference','copy-source')==read('native','copy-source')
assert read('native','screen-before')==read('native','screen-after')
print('PASS paired GetPixBaseAddr: original bytes, locked return ABI, unlocked reference, unchanged query state, original 56-row copy of 28672 bytes with 448 unused/padding bytes preserved; native screen unchanged')

endpoint=re.search(r'PBASE_NEXT state=3 trap=A0F8 selector=F segment=3 offset=FC8 manager=SOUND DRIVER routine=SELECTOR windows=249 services=(\d+)/(\d+) reads=109 bytes=826832', a.native.read_text())
assert endpoint and int(endpoint[1])==int(endpoint[2])
