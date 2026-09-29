#!/usr/bin/env python3
"""Validate the Mac writable-resource mutation/duplicate reference capture."""
import argparse
from pathlib import Path
import re
from resource_fork import read_resource_fork
LABELS='application create-file create-map open allocate add attrs-added changed attrs-changed write attrs-written update close reopen lookup-written attrs-reopened write-without-changed close-unchanged reopen-unchanged lookup-unchanged duplicate-allocate duplicate-add count-after-duplicate update-duplicates close-duplicates reopen-duplicates count-reopened-duplicates duplicate-index-one duplicate-index-two lookup-duplicate-selected nil-add nil-changed nil-write nil-remove remove attrs-removed changed-removed write-removed remove-again count-removed readd invalid-update update-readded close-readded reopen-readded lookup-readded lookup-removed final-close delete-file current-final'.split()
OPENS={'open','reopen','reopen-unchanged','reopen-duplicates','reopen-readded'}
LOOKUPS={'lookup-written','lookup-unchanged','duplicate-index-one','duplicate-index-two','lookup-duplicate-selected','lookup-readded','lookup-removed'}
ATTRS={label for label in LABELS if label.startswith('attrs-')}
COUNTS={'count-after-duplicate':2,'count-reopened-duplicates':2,'count-removed':1}
PRESERVE={'application','current-final','update','update-duplicates','update-readded','invalid-update'}|OPENS|ATTRS
MEM_PRESERVE={'application','create-file','create-map','nil-changed','nil-write','nil-remove','changed-removed','write-removed','remove-again','invalid-update','delete-file','current-final','lookup-duplicate-selected'}|ATTRS
ERRORS={'nil-add':0xff3e,'nil-changed':0xff40,'nil-write':0xff40,'nil-remove':0xff3c,'attrs-removed':0xff40,'changed-removed':0xff40,'write-removed':0xff40,'remove-again':0xff3c,'invalid-update':0xff3f}
def validate(text,status,resources):
    if status or any(x in text for x in ('FAIL ','LUA ERROR','Error in breakpoint')) or text.count('PASS resource writes capture complete; scratch deleted')!=1 or 'ARM resource-writes Engine+$3CDC bytes=a820245f' not in text:
        raise ValueError('runner, byte guard, completion or cleanup')
    rows=[{k:v if k=='label' else int(v,16) for k,v in re.findall(r'(\w+)=(\S+)',line)} for line in text.splitlines() if line.startswith('RWRITE label=')]
    if [r['label'] for r in rows]!=LABELS:raise ValueError('ordered 50-call sequence')
    by={r['label']:r for r in rows};app=by['application']['result']
    for n,r in enumerate(rows,1):
        label=r['label'];error=ERRORS.get(label,0)
        if label in {'application','current-final','create-file','delete-file','allocate','duplicate-allocate'}:error=0x8888
        mem=0x7777 if label in MEM_PRESERVE else 0
        d0=0x12345678 if label in PRESERVE else 4 if label=='create-map' else error if error!=0x8888 else 0
        delta=4 if label in LOOKUPS else 2 if label in OPENS|ATTRS|COUNTS.keys()|{'application','current-final'} else 0
        if (r['stage'],r['error'],r['mem'],r['d0'],r['sp'])!=(n,error,mem,d0,r['base']-delta):raise ValueError(label+' registers/errors/stack')
        if label in OPENS and (r['result'] in (0,0xffff,app) or r['ref']!=r['result']):raise ValueError(label+' reference')
        if label in LOOKUPS and (not r['result'] or r['result']!=r['handle']):raise ValueError(label+' handle')
        if label in ATTRS and r['result']!=(2 if label in {'attrs-added','attrs-changed'} else 0):raise ValueError(label+' resource attributes')
        if label in COUNTS and r['result']!=COUNTS[label]:raise ValueError(label+' duplicate count')
        if label not in OPENS|LOOKUPS|ATTRS|COUNTS.keys()|{'application','current-final','allocate','duplicate-allocate'} and r['result']:
            raise ValueError(label+' void result')
    if not app or by['current-final']['result']!=app:raise ValueError('current-file restoration')
    if not by['allocate']['result'] or not by['duplicate-allocate']['result'] or by['allocate']['result']==by['duplicate-allocate']['result']:raise ValueError('independent allocated handles')
    if by['duplicate-index-one']['handle']==by['duplicate-index-two']['handle'] or by['lookup-duplicate-selected']['handle']!=by['duplicate-index-one']['handle']:
        raise ValueError('duplicate index/lookup precedence')
    expected={'allocate':0x41414141,'add':0x41414141,'changed':0x42424242,'write':0x42424242,'lookup-written':0x42424242,'write-without-changed':0x43434343,'lookup-unchanged':0x42424242,'duplicate-index-one':0x42424242,'duplicate-index-two':0x44444444,'lookup-duplicate-selected':0x42424242,'remove':0x42424242,'attrs-removed':0x42424242,'changed-removed':0x42424242,'write-removed':0x42424242,'remove-again':0x42424242,'readd':0x42424242,'lookup-readded':0x42424242,'lookup-removed':0x44444444}
    for label,body in expected.items():
        row=by[label];flags=0 if label in {'allocate','remove','attrs-removed','changed-removed','write-removed','remove-again'} else 0x20
        if row['body']!=body or row['master']>>24!=flags or not row['master']&0xffffff:raise ValueError(label+' body/flags')
    for label in ['remove','attrs-removed','changed-removed','write-removed','remove-again','readd']:
        if by[label]['handle']!=by['lookup-duplicate-selected']['handle']:raise ValueError(label+' preserved detached handle')
    gloss=next(r.body for r in resources if r.kind==b'CODE' and r.rid==8)
    for offset,wanted in ((0x8ac,'a9ad3f06'),(0x906,'a9aa2f0b'),(0x90a,'a9b0204b'),(0x9ce,'a9ab2f2e'),(0x9d4,'a9b02f2e')):
        if gloss[offset:offset+4]!=bytes.fromhex(wanted):raise ValueError('original mutation call bytes')
    return 'PASS resource writes reference: 50 calls; dirty attributes, conditional writes, same-file duplicates/order, removal/readd, errors/registers, reopen and cleanup'
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('log',type=Path);p.add_argument('--status',type=int,required=True);p.add_argument('--original',type=Path,required=True);a=p.parse_args()
    try:print(validate(a.log.read_text(),a.status,read_resource_fork(a.original)))
    except (ValueError,KeyError,OSError,StopIteration) as error:raise SystemExit('FAIL resource writes reference: '+str(error))
