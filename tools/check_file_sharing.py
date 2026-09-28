#!/usr/bin/env python3
"""Strict acceptance for the scratch-only Mac sharing/permission reference."""
import argparse
from pathlib import Path
import re
import unittest

def contract():
    expected=[]
    def add(label,trap,error=0,**fields):expected.append((label,trap,error,fields))
    add('create',0xa208);add('directory',0xa215)
    for a in range(5):
        for b in range(5):
            tag=f'matrix_{a}_{b}'
            conflict=a!=1 and b!=1 and (a,b)!=(4,4)
            add(tag+'_first',0xa000)
            add(tag+'_firstflags',0xa260,flags=0 if a==1 else 0x1100 if a==4 else 0x100,eof=0,mark=0)
            add(tag+'_second',0xa000,-49 if conflict else 0)
            add(tag+'_secondflags',0xa260,-51 if conflict else 0,**({} if conflict else {'flags':0 if b==1 else 0x1100 if b==4 else 0x100,'eof':0,'mark':0}))
            add(tag+'_close_second',0xa001,-51 if conflict else 0);add(tag+'_close_first',0xa001)
    for a,b in [(3,1),(4,4)]:
        tag=f'coherent_{a}_{b}';fa=0x100 if a==3 else 0x1100;fb=0 if b==1 else 0x1100
        add(tag+'_first',0xa000);add(tag+'_second',0xa000);add(tag+'_truncate',0xa012)
        add(tag+'_write',0xa003,actual=4,position=4)
        add(tag+'_second_before_read',0xa260,eof=4,mark=0,flags=fb)
        add(tag+'_read',0xa002,actual=4,position=4,data=0x12345678)
        add(tag+'_shrink',0xa012)
        add(tag+'_second_after_shrink',0xa260,eof=2,mark=4,flags=fb)
        add(tag+'_first_after_shrink',0xa260,eof=2,mark=2,flags=fa|0x8000)
        add(tag+'_flush',0xa013);add(tag+'_first_after_flush',0xa260,flags=fa,eof=2,mark=2)
        add(tag+'_close_first',0xa001);add(tag+'_second_after_close',0xa260,eof=2,mark=4,flags=fb)
        add(tag+'_read_after_close',0xa002,actual=2,position=2,data=0x12340000)
        if b==4:
            add(tag+'_write_after_close',0xa003,actual=4,position=6)
            add(tag+'_after_late_write',0xa260,eof=6,mark=6,flags=0x9100)
        add(tag+'_close_second',0xa001)
    add('reader_close_writer',0xa000);add('reader_close_reader',0xa000)
    add('reader_close_write',0xa003,actual=4,position=4);add('reader_close_first',0xa001)
    add('reader_close_writer_flags',0xa260,flags=0x8100,eof=6,mark=4);add('reader_close_last',0xa001)
    add('lock',0xa041)
    for p in range(5):
        add(f'locked_{p}',0xa000,0 if p<2 else -54)
        add(f'locked_{p}_flags',0xa260,0 if p<2 else -51,**({'flags':0x2000} if p<2 else {}))
        add(f'locked_{p}_close',0xa001,0 if p<2 else -51)
    add('unlock',0xa042);add('volume_name',0xa014)
    for name,error in [('flush_name',-35),('flush_plain_default',0),('flush_colon',0),('flush_full_path',0),('flush_partial',0),('flush_partial_bad_ref',-35),('restore_name',0),('flush_bad_name',-35)]:add(name,0xa013,error)
    add('volume_info',0xa207);add('flush_drive',0xa013);add('flush_bad_ref',0xa013,-35);add('flush_default',0xa013)
    add('delete',0xa009);add('flush',0xa013)
    return expected

def validate(text,status=0):
    if status or 'FAIL ' in text or 'Error in breakpoint' in text or text.count('PASS sharing capture complete; scratch deleted')!=1 or 'bytes=7008a2606004' not in text:
        raise ValueError('incomplete probe, original-byte proof or scratch cleanup')
    rows=[]
    for line in text.splitlines():
        if line.startswith('SHARING label='):
            fields=dict(re.findall(r'(\w+)=(\S+)',line))
            rows.append({k:v if k=='label' else int(v,16) for k,v in fields.items()})
    expected=contract()
    if len(rows)!=len(expected):raise ValueError('missing or extra stages')
    bylabel={r['label']:r for r in rows}
    for n,(r,(label,trap,error,fields)) in enumerate(zip(rows,expected),1):
        if r['label']!=label or r['stage']!=n or r['state']!=n or r['trap']!=trap or r['d0']&65535!=error&65535 or r['result']!=error&65535:
            raise ValueError(f'{label}: wrong stage/trap/result')
        for k,v in fields.items():
            if r.get(k)!=v:raise ValueError(f'{label}: {k} mismatch')
        if re.fullmatch(r'matrix_[0-4]_[0-4]_second',label):
            first=bylabel[label.removesuffix('_second')+'_first']['ref']
            if (r['ref']==first)!=(error==-49) or not first or not r['ref']:
                raise ValueError('new versus conflicting reference identity mismatch')
    drive=bylabel['volume_info']['drive']
    if not 0<drive<0x8000 or bylabel['flush_drive']['volume']!=drive:raise ValueError('actual volume drive not used')
    return 'PASS sharing reference: permissions=0-4/locked conflict-ref=existing marks=independent data=coherent volume=name/ref/drive cleanup=deleted'

class Tests(unittest.TestCase):
    def fixture(self):
        rows=['ARM bytes=7008a2606004']
        for n,(label,trap,error,fields) in enumerate(contract(),1):
            ref=2 if label.endswith('_second') and not error else 1
            fields=dict(fields,ref=ref,drive=8,volume=8)
            rows.append(f'SHARING label={label} stage={n:X} state={n:X} trap={trap:X} d0={error&0xffffffff:X} result={error&65535:X} '+' '.join(f'{k}={v:X}' for k,v in fields.items()))
        return '\n'.join(rows)+'\nPASS sharing capture complete; scratch deleted\n'
    def test_accept(self):self.assertIn('PASS',validate(self.fixture()))
    def test_reject(self):
        for before,after in [('scratch deleted',''),('bytes=7008a2606004',''),('state=D0','state=0'),('mark=4','mark=2'),('flags=2000','flags=0'),('result=FFCF','result=0')]:
            with self.subTest(before=before),self.assertRaises(ValueError):validate(self.fixture().replace(before,after))
        with self.assertRaises(ValueError):validate(self.fixture(),124)

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('log',type=Path,nargs='?')
    p.add_argument('--status',type=int,default=0);p.add_argument('--selftest',action='store_true');a=p.parse_args()
    if a.selftest:unittest.main(argv=['check_file_sharing'])
    elif a.log:
        try:print(validate(a.log.read_text(),a.status))
        except (ValueError,KeyError) as error:raise SystemExit('FAIL sharing reference: '+str(error))
    else:p.error('log or --selftest required')
