#!/usr/bin/env python3
"""Check original GetKeys ABI/map extent and native held-key fixture evidence."""
import argparse,re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def complete(text,status,marker,end):
    if status!=0 or text.count(marker)!=1 or text.count(end)!=1 or re.search(r'FAIL|LUA ERROR|Error in|TIMEOUT|timeout|Program received signal|Cannot execute this command|Remote connection closed',text):
        raise ValueError('normal completion and positive controls')
def calls(text,native=False):
    code=(ROOT/'tmp/segments/CODE_12_Dan1').read_bytes()
    if code[0x5836:0x583c]!=bytes.fromhex('486efff0a976'):raise ValueError('original caller bytes')
    count=1 if native else 3
    if re.findall(r'^GETKEYS_BYTES n=(\d+) data=486EFFF0A976$',text,re.M)!=list(map(str,range(1,count+1))):raise ValueError('live caller bytes/order')
    rows=re.findall(r'^GETKEYS_(ENTER|RETURN) (.*)$',text,re.M)
    if len(rows)!=count*2:raise ValueError('call count')
    preserved=[f'd{i}'for i in range(2,8)]+[f'a{i}'for i in range(2,7)]
    for i in range(count):
        if [x[0]for x in rows[2*i:2*i+2]]!=['ENTER','RETURN']:raise ValueError('entry/return order')
        e,r=[dict(re.findall(r'(\w+)=([^ ]+)',x[1]))for x in rows[2*i:2*i+2]]
        if e['n']!=str(i+1) or r['n']!=e['n'] or e['destination']!=r['destination']:raise ValueError('call/destination identity')
        if int(r['sp'],16)!=int(e['sp'],16)+4 or int(r['d0'],16)!=(int(e['d0'],16)&0xffff0000):raise ValueError('stack/D0.w result')
        if any(e[k]!=r[k]for k in preserved):raise ValueError('preserved registers')
        before,after=bytes.fromhex(e['guard']),bytes.fromhex(r['guard'])
        expected=(b'\1'+bytes(15)) if i==1 else bytes(16)
        if bytes.fromhex(e['keymap'])!=expected or e['keymap']!=r['keymap']:raise ValueError('released/held key-map state')
        if len(before)!=24 or len(after)!=24 or before[:4]!=after[:4] or before[20:]!=after[20:] or after[4:20]!=expected:raise ValueError('exact 16-byte write/guards')
def check(reference,status,native=None,native_status=None,probe=None,probe_status=None):
    complete(reference,status,'PASS original GetKeys calls=3 released/held/released','Exited via the debugger');calls(reference)
    if native is not None:
        complete(native,native_status,'PASS native original GetKeys calls=1','[Inferior 1 (Remote target) detached]');calls(native,True)
        if probe is None:raise ValueError('native key fixtures required')
        complete(probe,probe_status,'PASS native KeyMap: 11 guarded released/held/multiple-key/alias snapshots; events not consumed','[Inferior 1 (Remote target) detached]')
    print('PASS GetKeys: original caller/ABI, exact 16-byte map and guards, released/held/released A'+('; native key levels, aliases and event preservation' if native is not None else ''))
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('reference',type=Path);p.add_argument('--status',type=int,required=True);p.add_argument('--native',type=Path);p.add_argument('--native-status',type=int);p.add_argument('--keys-probe',type=Path);p.add_argument('--keys-probe-status',type=int);a=p.parse_args()
    try:check(a.reference.read_text(),a.status,a.native.read_text()if a.native else None,a.native_status,a.keys_probe.read_text()if a.keys_probe else None,a.keys_probe_status)
    except (ValueError,OSError,KeyError)as e:raise SystemExit('FAIL GetKeys: '+str(e))
