#!/usr/bin/env python3
"""Pair hidden startup menu membership, ownership and redraw suppression."""
from pathlib import Path
import argparse,hashlib,re
from resource_fork import read_resource_fork
from check_menu_reference import records
p=argparse.ArgumentParser();p.add_argument('reference',type=Path);p.add_argument('native',type=Path);p.add_argument('--reference-status',type=int,required=True);p.add_argument('--native-status',type=int,required=True);a=p.parse_args()
assert a.reference_status==a.native_status==0
code=next(r.body for r in read_resource_fork(Path('tmp/runtime-data/Alone In The Dark')) if r.kind==b'CODE' and r.rid==7)[0x2b04:0x2b46]
assert hashlib.sha256(code).hexdigest()=='d302ea1079ba3557d446a85bc8faafa1f23e92b2152cf06fab8daa8bb2a29e51'
def read(side,label):return Path(f'tmp/menulist-{side}-{label}.bin').read_bytes()
def fields(line):return {k:int(v,16) for k,v in re.findall(r'(\w+)=([\dA-Fa-f]+)',line)}
allrows={}
for side,path in [('reference',a.reference),('native',a.native)]:
 text=path.read_text();assert not any(x in text for x in ['FAIL','Error in','LUA ERROR','TIMEOUT','Program received signal'])
 assert text.count('PASS '+('original' if side=='reference' else 'native')+' menu-list lifecycle')==1
 assert text.count('Exited via the debugger' if side=='reference' else '[Inferior 1 (Remote target) detached]')==1
 assert read(side,'original-code')==code
 rows={(int(seq,16),phase):fields(line) for seq,phase,line in re.findall(r'^MLIST seq=(\w+) phase=(\w+) (.*)$',text,re.M)};allrows[side]=rows
 assert len(rows)==(14 if side=='reference' else 12)
 for seq in range(1,7):
  e,r=rows[seq,'before'],rows[seq,'after']
  assert r['sp']==e['sp']+(6 if 2<=seq<=5 else 0) and r['D0']==0
  if seq==1:assert r['A0']==0
  if 2<=seq<=5:assert r['A0']==r['pc']
  for reg in ['D3','D4','D5','D6','D7','A2','A3','A4','A5','A6']:assert e[reg]==r[reg],(side,seq,reg)
  for phase in ['before','after']:
   count=max(0,min(seq-(2 if phase=='before' else 1),4))
   entries=[fields(line) for line in re.findall(rf'^MLIST_ENTRY seq={seq:X} phase={phase} (.*)$',text,re.M)]
   expected=list(range(128,128+count))
   if side=='reference' and count:expected += [0xbf96,0xbf97]
   assert [e['id'] for e in entries]==expected,(side,seq,phase,'order')
   if side=='native':assert rows[seq,phase]['count']==count and all(e['bar']==1 for e in entries)
  for i in range(1,min(seq,5)):
   before=read(side,f'{seq}-before-menu{i}');after=read(side,f'{seq}-after-menu{i}')
   assert before[:2]+before[6:]==after[:2]+after[6:],(side,seq,i,'menu identity/items')
   if side=='native':assert before==after
 if side=='reference':
  assert int.from_bytes(read(side,'7-after-list')[:2],'big')==0
  for i in range(1,5):assert read(side,f'7-before-menu{i}')==read(side,f'7-after-menu{i}')
  assert read(side,'6-before-client')==read(side,'6-after-client')
 else:assert read(side,'screen-before')==read(side,'screen-after')
for i in range(1,5):
 rb,ri=records(read('reference',f'6-after-menu{i}'));nb,ni=records(read('native',f'6-after-menu{i}'))
 assert rb[:2]+rb[10:15+rb[14]]==nb[:2]+nb[10:15+nb[14]]
 if i==1:
  assert ri[-1]==(b'\0\0Control Panels',bytes(4));ri=ri[:-1]
 assert ri==ni,(i,'original application items')
print('PASS paired menu lifecycle: clear, four ordered owned menus, draw suppression, exact application records, preserved registers/stack, unchanged game client; reference nonempty clear preserves menu records')

assert 'MLIST_NEXT state=3 trap=A992 selector=FFFFFFFF segment=13 offset=210 manager=RESOURCE MANAGER routine=DETACHRESOURCE windows=101 services=163/163 reads=62 bytes=265454' in a.native.read_text()
