#!/usr/bin/env python3
"""Check the completed System 7.5.5 async File Manager ABI fixture."""
import argparse
from pathlib import Path
import re

LABELS='hgetvol hgetvol-null hgetvol-sync hsetvol hsetvol-error getinfo getinfo-sync hgetinfo hgetinfo-error getwd getwd-error getfcb getfcb-error openwd closewd-app closewd-app-sync openwd-root closewd-root openwd-new closewd-new closewd-error openwd-error create create-error scratch-info setinfo scratch-readback setinfo-error openrf close openrf-error delete flush'.split()
NO_CALLBACK={'hgetvol-null','hgetvol-sync','getinfo-sync','closewd-app','closewd-app-sync','close','delete','flush'}
ERRORS={'hsetvol-error':-35,'hgetinfo-error':-35,'getwd-error':-35,'getfcb-error':-51,'closewd-error':-51,'openwd-error':-35,'create-error':-48,'setinfo-error':-35,'openrf-error':-35}

def validate(text,status):
    if status or 'FAIL ' in text or 'Error in breakpoint' in text or text.count('PASS async capture complete')!=1:
        raise ValueError('runner, breakpoint or completion failure')
    mode=re.findall(r'ARM async bytes=7008a2606004 sites=11 clobber=([01])',text)
    if len(mode)!=1:raise ValueError('missing original-byte/mode proof')
    clobber=mode[0]=='1'
    def fields(line):
        return {k:v if k=='label' else int(v,16) for k,v in re.findall(r'(\w+)=(\S+)',line)}
    rows=[];callbacks={};last=0
    for line in text.splitlines():
        if line.startswith('ASYNC CALLBACK '):
            r=fields(line);n=r['stage']
            if n!=last+1 or n in callbacks:raise ValueError('late/duplicate callback')
            callbacks[n]=r
        elif line.startswith('ASYNC label='):
            r=fields(line);rows.append(r);last=r['stage']
    if len(rows)!=len(LABELS):raise ValueError('stage count')
    for n,(r,label) in enumerate(zip(rows,LABELS),1):
        error=ERRORS.get(label,0)&65535;called=label not in NO_CALLBACK
        if r['stage']!=n or r['label']!=label or r['result']!=error:raise ValueError(label+' stage/result')
        if r['callbacks']!=int(called) or (n in callbacks)!=called:raise ValueError(label+' callback count')
        if r['a0']!=r['pb'] or (r['d1'],r['d2'],r['a1'])!=(0x11223344,0x22334455,0x33445566):raise ValueError(label+' register preservation')
        if called:
            cb=callbacks[n]
            if cb['a0']!=r['pb'] or cb['pb']!=r['pb'] or cb['result']!=error or cb['d0']&65535!=error:
                raise ValueError(label+' completion ABI')
            if not r['completion']:raise ValueError(label+' completion pointer changed')
        elif label not in ('closewd-app','closewd-app-sync') and r['completion']:raise ValueError(label+' synchronous/null completion not cleared')
        if label in ('closewd-app','closewd-app-sync') and not r['completion']:raise ValueError('protected WD completion pointer')
        expected=0xdeadbeef if called and clobber else error
        if (r['d0'] if called and clobber else r['d0']&65535)!=expected:raise ValueError(label+' callback D0 return')
        if r['sr']&15!=(8 if expected&0x8000 else 4 if not expected else 0):raise ValueError(label+' return CCR')
    by={r['label']:r for r in rows}
    if by['scratch-info']['type'] or by['scratch-info']['creator']:raise ValueError('new scratch metadata')
    if (by['scratch-readback']['type'],by['scratch-readback']['creator'])!=(0x54455354,0x41495444):raise ValueError('written scratch metadata')
    if by['openwd']['volume']!=by['hgetvol']['volume'] or by['openwd-new']['volume'] in (0,65535,by['openwd']['volume']):raise ValueError('distinct WD identity')
    if by['closewd-new']['volume']!=by['openwd-new']['volume']:raise ValueError('closed WD identity')
    return f'PASS async reference: 33 calls, 25 early callbacks, errors/metadata/cleanup/registers; clobber={int(clobber)}'

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('log',type=Path);p.add_argument('--status',type=int,required=True);a=p.parse_args()
    try:print(validate(a.log.read_text(),a.status))
    except (ValueError,KeyError) as e:raise SystemExit('FAIL async reference: '+str(e))
