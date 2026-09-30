#!/usr/bin/env python3
"""Original/native effect-status results, preserved state and playback order."""
import argparse,re,struct
from pathlib import Path
from check_driver22 import ROOT,one
from resource_fork import read_resource_fork

def check_native_sequence(n,allow_prefix=False):
    pattern=(r'^DRIVER20_NATIVE_PREFIX calls=(\d+) active=(\d+) complete=0 driverCalls=(\d+) statusCalls=(\d+) starts=(\d+) stops=(\d+) next=A891/6/337E$' if allow_prefix else r'^DRIVER20_NATIVE_SEQUENCE calls=(\d+) active=(\d+) complete=1 driverCalls=(\d+) statusCalls=(\d+) starts=(\d+) stops=(\d+)$')
    polls,playing,calls,statuses,starts,stops=map(int,one(n,pattern))
    if not playing or polls!=playing+(0 if allow_prefix else 1) or calls!=statuses+4 or starts!=1 or stops!=(0 if allow_prefix else 1):raise ValueError('native event sequence')
    if allow_prefix:
        if polls!=statuses:raise ValueError('prefix query accounting')
    else:
        observed,scoped,total=map(int,one(n,r'^DRIVER20_ACCOUNTING observed=(\d+) scoped=(\d+) total=(\d+)$'))
        if observed!=polls or total!=statuses or observed+scoped!=total:raise ValueError('scoped callback query accounting')

def check(text,status,native=None,native_status=None,allow_prefix=False):
    if status!=0 or any(x in text for x in ('FAIL','LUA ERROR','Error in')) or text.count('Exited via the debugger')!=1:raise ValueError('reference completion')
    active,total,fixtures=map(int,one(text,r'^PASS original driver20 status active=(\d+) total=(\d+) fixtures=(\d+)$'))
    if not active or total!=active+1 or fixtures!=4:raise ValueError('reference sequence')
    code=next(r.body for r in read_resource_fork(ROOT/'tmp/runtime-data/Alone In The Dark') if r.kind==b'CODE' and r.rid==3)
    raw=code[0x17bc:0x17cc]
    if raw.hex()!='2f2e000848780014206df9544e90508f' or one(text,r'^DRIVER20_BYTES (\w+)$')!=raw.hex().upper():raise ValueError('original caller')
    driver=(ROOT/'tmp/driver20-reference-driver.bin').read_bytes()
    original=(ROOT/'tmp/plan/MDRV_11.bin').read_bytes()
    if driver[0x84:0x88].hex()!='60000150' or driver[0x1d6:0x1e6].hex()!='206c000461003506394000086000fec6' or driver[0x36e2:0x3716]!=original[0x36e2:0x3716]:raise ValueError('original status implementation')
    packet=(ROOT/'tmp/driver20-reference-packet.bin').read_bytes()
    if len(packet)!=26 or packet[24:]!=b'\x80\0':raise ValueError('reference identifier')
    def transition(name,result):
        before=(ROOT/'tmp'/f'driver20-reference-{name}-enter.bin').read_bytes()
        after=(ROOT/'tmp'/f'driver20-reference-{name}-return.bin').read_bytes()
        if len(before)!=0x3048 or len(after)!=len(before):raise ValueError('full state dump')
        argument=int(one(text,r'^DRIVER20_NATURAL calls=\d+ active=\d+ result=1 packet=(\w+) id=8000$'),16) if name=='first' else int(one(text,rf'^DRIVER20_FIXTURE name={name} result=\d+ sp=\w+ argument=(\w+)$'),16)
        expected=bytearray(before);struct.pack_into('>IIH',expected,0,20,argument,result)
        if struct.unpack_from('>I',after)[0]!=20 or expected!=after:raise ValueError('status-only state transition '+name)
    transition('first',0)
    for name,result in [('active',0),('stopped',1),('missing',1),('first-inactive',1)]:
        observed=int(one(text,rf'^DRIVER20_FIXTURE name={name} result=(\d+) sp=\w+ argument=\w+$'))
        if observed!=result:raise ValueError('fixture result '+name)
        transition(name,result)
    complete=(ROOT/'tmp/driver20-reference-complete.bin').read_bytes()
    if struct.unpack_from('>H',complete,8)[0]!=1 or struct.unpack_from('>H',complete,0x24ea)[0]!=0xffff:raise ValueError('natural completion')
    if native:
        n=native.read_text()
        if native_status!=0 or any(x in n for x in ('FAIL','Error in','DIAG / GDB TIMEOUT','Program received signal')) or n.count('PASS native driver20 active-prefix ABI; completed-query acceptance pending' if allow_prefix else 'PASS native driver20 playing-to-finished sequence ABI and cleanup')!=1 or n.count('[Inferior 1 (Remote target) detached]')!=1:raise ValueError('native completion')
        check_native_sequence(n,allow_prefix)
        if (ROOT/'tmp/driver20-native-packet.bin').read_bytes()[24:]!=packet[24:]:raise ValueError('native identifier')
    print('PASS driver20: original bytes/states'+(('; native active prefix only; completed-query acceptance pending' if allow_prefix else '; native playback sequence') if native else '; reference only'))

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('reference',type=Path);p.add_argument('--status',required=True,type=int);p.add_argument('--native',type=Path);p.add_argument('--native-status',type=int);p.add_argument('--allow-prefix',action='store_true');a=p.parse_args()
    try:check(a.reference.read_text(),a.status,a.native,a.native_status,a.allow_prefix)
    except (ValueError,OSError,KeyError) as e:raise SystemExit('FAIL driver20: '+str(e))
