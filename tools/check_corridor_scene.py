#!/usr/bin/env python3
"""Validate paired natural scene stages in tmp/corridor-scene; all times are game ticks.

Includes callbacks and compatibility work within each interval; stages are not
exclusive CPU categories. These are same-view, not identical-pose comparisons.
"""
from pathlib import Path
import re,statistics,collections,argparse

def load(side,status):
 text=Path(f'tmp/corridor-scene/{side}.log').read_text()
 assert status==0 and not re.search(r'FAIL|Error in|TIMEOUT',text),'normal observer completion'
 marker='original' if side=='mac' else 'native'
 assert text.count(f'PASS {marker} natural corridor scene stages')==1,'unique completion'
 assert ('Exited via the debugger' if side=='mac' else '[Inferior 1 (Remote target) detached]') in text,'detach'
 rows=[(int(n),p,int(t),int(r),int(c),int(a),int(b)) for n,p,t,r,c,a,b in re.findall(r'SCENE_STAGE step=(\d+) stage=(\S+) ticks=(\d+) room=(\d+) camera=(\d+) actor=(-?\d+) body=(-?\d+)',text)]
 assert all(a[2]<=b[2] for a,b in zip(rows,rows[1:])),'monotonic clock'
 grouped=collections.defaultdict(list)
 for n,p,t,r,c,a,b in rows:grouped[n].append((p,t,r,c,a,b))
 out=[];previous_loop=None
 for n,rs in grouped.items():
  if any((r,c)!=(1,2) for p,t,r,c,a,b in rs):continue
  fixed={}
  for stage in ('scene-enter','background-done','actors-done','scene-exit','next-loop'):
   found=[t for p,t,r,c,a,b in rs if p==stage]
   assert len(found)==1,(side,n,stage,found)
   fixed[stage]=found[0]
  assert list(fixed.values())==sorted(fixed.values()),'scene stage order'
  spans={'background':fixed['background-done']-fixed['scene-enter'],
         'actors inclusive':fixed['actors-done']-fixed['background-done'],
         'overlay/copies':fixed['scene-exit']-fixed['actors-done'],
         'after scene':fixed['next-loop']-fixed['scene-exit'],
         'scene to loop':fixed['next-loop']-fixed['scene-enter']}
  if previous_loop is not None:
   spans['before scene']=fixed['scene-enter']-previous_loop
   spans['loop']=fixed['next-loop']-previous_loop
  previous_loop=fixed['next-loop']
  pending={}
  for p,t,r,c,a,b in rs:
   if p in ('model','mask','animate'):
    assert (p,a) not in pending,'nested actor stage'
    pending[p,a]=t
   if p in ('model-return','mask-return','animate-return'):
    start=p.removesuffix('-return');assert (start,a) in pending,'actor stage pair'
    spans[f'{start} actor {a}']=t-pending.pop((start,a))
  assert not pending,'unfinished actor stage'
  out.append((n,spans))
 assert len(out)>=5,'enough complete scene steps'
 print(side,len(out),'complete steps')
 keys=sorted(set(k for _,s in out for k in s))
 for k in keys:
  values=[s[k] for _,s in out if k in s]
  print(f'  {k}: n={len(values)} min/median/max {min(values)}/{statistics.median(values):g}/{max(values)}')
 for n,spans in out:print(side,n,spans)
 return out

if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('side',choices=['mac','amiga']);p.add_argument('--status',required=True,type=int);a=p.parse_args();load(a.side,a.status)
