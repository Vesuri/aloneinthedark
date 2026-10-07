#!/usr/bin/env python3
"""Validate bounded M5 memory/interrupt evidence; never infer a full play-through."""
import argparse,json,re
from pathlib import Path

def require(ok,why):
    if not ok:raise ValueError(why)

def check(log,folder,status,cpu,fast_kb,completion):
    require(status==0,'runner status')
    require(not re.search(r'FAIL|Error in sourced|TIMEOUT|Program received signal',log),'clean observer')
    require(completion in log and '[Inferior 1 (Remote target) detached]' in log,'positive completion and detach')
    rows={}
    for line in log.splitlines():
        if line.startswith('M5_'):
            rows[line.split()[0]]={k:int(v,16 if k in ('from','to','trap') else 10) for k,v in re.findall(r'(\w+)=([0-9A-F]+)',line)}
    require(set(rows)=={'M5_MACHINE','M5_MEMORY','M5_IRQ','M5_GAP'},'complete audit categories')
    machine=rows['M5_MACHINE'];memory=rows['M5_MEMORY'];irq=rows['M5_IRQ'];gap=rows['M5_GAP']
    require(machine['clockHz']==709379,'PAL E-clock frequency')
    require(machine['cpuFlags']&(7 if cpu=='68030' else 3)==(7 if cpu=='68030' else 3),'OS-visible CPU flags')
    require(machine['fast']==fast_kb*1024 and 2090000<=machine['chip']<=2097152,'OS-visible RAM')
    require(memory['errors']==0 and memory['failures']==0,'allocation accounting and failures')
    require(memory['allocations']>100 and memory['appZone']>1000000 and memory['systemZone']>0,'active memory coverage')
    require(0<memory['minFast']<machine['initialFast'] and 0<memory['minChip']<machine['initialChip'],'memory low-water marks')
    require(irq['calls']>100 and irq['events']>0,'music coverage')
    require(irq['eventLate']==0,'current song delivery lateness')
    require(0<irq['maxClocks']<machine['clockHz']//60,'interrupt under one music period')
    require(machine['clockHz']//120<irq['minInterval']<=irq['maxInterval']<machine['clockHz']//30,'no lost or doubled music periods')
    require(irq['maxLateEClocks']<machine['clockHz']//120,'interrupt lateness below half a period')
    require(0<gap['maxClocks']<machine['clockHz']*120,'bounded trap gap, no clock underflow')
    margins={}
    for name in ('music','deferred'):
        data=(folder/(name+'-stack.bin')).read_bytes()
        require(len(data)==8192,name+' stack extent')
        margin=next((i for i,v in enumerate(data) if v!=0xa5),len(data))
        require(margin>=1024,name+' stack guard/headroom')
        margins[name]=margin
    result={'machine':machine,'memory':memory,'irq':irq,'gap':gap,'stack_headroom_bytes':margins,
            'irq_max_ms':irq['maxClocks']*1000/machine['clockHz'],
            'irq_lateness_max_ms':irq['maxLateEClocks']*1000/machine['clockHz'],
            'trap_gap_max_seconds':gap['maxClocks']/machine['clockHz']}
    return result

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('log',type=Path);p.add_argument('--folder',type=Path,required=True)
    p.add_argument('--status',type=int,required=True);p.add_argument('--cpu',choices=['68020','68030'],required=True)
    p.add_argument('--fast-kb',type=int,default=8192)
    p.add_argument('--completion',default='PASS native continuous firstfloor circuit')
    a=p.parse_args()
    try:
        result=check(a.log.read_text(errors='replace'),a.folder,a.status,a.cpu,a.fast_kb,a.completion)
    except (ValueError,OSError) as e:raise SystemExit('FAIL M5 audit: '+str(e))
    print(json.dumps(result,indent=2));print('PASS M5 audit: bounded session, memory, music interrupt and stack checks')
