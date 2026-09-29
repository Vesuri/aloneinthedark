#!/usr/bin/env python3
"""Verify the CPU-only HGetVolParms Mac reference capture and actual runner exit."""
import argparse
from pathlib import Path
import re
import struct

def validate(text, status):
    if status or 'FAIL ' in text or 'Error in breakpoint' in text or text.count('PASS volparms capture complete; read-only complete') != 1 or 'bytes=7008a2606004' not in text:
        raise ValueError('runner, original bytes or completion')
    rows = []
    for line in text.splitlines():
        if line.startswith('VOLPARMS label='):
            fields = dict(re.findall(r'(\w+)=(\S+)', line))
            rows.append({k: v if k == 'label' else int(v, 16) for k, v in fields.items()})
    sizes = [0,1,2,4,6,10,14,18,20,24,32]
    labels = ['get-default']+['size'+str(n) for n in sizes]+['default','wd','badvol','named','named-colon','missing','missing-colon','empty','relative','null-zero']
    if len(rows) != len(labels): raise ValueError('stage count')
    record = bytes.fromhex('0002000010e0')+bytes(14)
    for n,(row,label) in enumerate(zip(rows,labels),1):
        if (row['label'],row['stage'],row['state']) != (label,n,n): raise ValueError('sequence')
        error = label in ['badvol','named','missing-colon']
        wanted = 0xffdd if error else 0
        if row['result'] != wanted or row['d0'] & 65535 != wanted: raise ValueError(label+' result')
        if label == 'get-default':
            if not 0x8000 <= row['volume'] < 0xffff: raise ValueError('default WD positive control')
            continue
        if label == 'wd' and row['volume'] != rows[0]['volume']: raise ValueError('WD round trip')
        requested = int(label[4:]) if label.startswith('size') else 0 if label == 'null-zero' else 6
        actual = min(requested,20)
        if row['actual'] != (0xdeadbeef if error else actual): raise ValueError(label+' actual count')
        buffer = b''.join(struct.pack('>I',row['b'+str(i)]) for i in range(8))
        expected = bytes([0xcc])*32 if error else record[:actual]+bytes([0xcc])*(32-actual)
        if buffer != expected: raise ValueError(label+' record/canary')
    return 'PASS volparms reference: 22 calls; record=0002000010e0/zero-tail lengths=0..32 volume=name/ref/WD errors=unchanged'

if __name__ == '__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('log',type=Path);p.add_argument('--status',type=int,required=True);a=p.parse_args()
    try: print(validate(a.log.read_text(),a.status))
    except (ValueError,KeyError) as error: raise SystemExit('FAIL volparms reference: '+str(error))
