#!/usr/bin/env python3
"""Validate measured Times 14 advances and original TextWidth ABI."""
import argparse,re
from pathlib import Path
from resource_fork import read_resource_fork
ROOT=Path(__file__).resolve().parents[1]
def check(text,status):
    if status!=0 or any(v in text for v in ('FAIL','LUA ERROR','timeout')):raise ValueError('reference failed')
    if text.count('PASS original TextWidth and 256 character widths plus repeats/prefixes')!=1 or text.count('Exited via the debugger')!=1:raise ValueError('terminal completion')
    code=next(r.body for r in read_resource_fork(ROOT/'tmp/runtime-data/Alone In The Dark') if r.kind==b'CODE' and r.rid==12)
    if code[0x212:0x218].hex()!='548f3e80a886' or re.findall(r'^TW_BYTES data=(\w+)$',text,re.M)!=['548F3E80A886']:raise ValueError('original caller bytes')
    def row(label):
        rows=re.findall('^'+label+' (.*)$',text,re.M)
        if len(rows)!=1:raise ValueError('original call count')
        return dict(re.findall(r'(\w+)=(\w+)',rows[0]))
    entry,result=row('TW_ENTER'),row('TW_RETURN')
    title=bytes.fromhex(entry['text'])
    if title!=b'Alone in the Dark' or (entry['font'],entry['size'],entry['face'],entry['extra'],entry['first'])!=('14','E','0','0','0'):raise ValueError('selected font and original range')
    if int(entry['count'],16)!=len(title) or int(result['sp'],16)!=int(entry['sp'],16)+8 or entry['port']!=result['port']:raise ValueError('stack/port preservation')
    for reg in [f'd{i}' for i in range(3,8)]+[f'a{i}' for i in range(2,7)]:
        if entry[reg]!=result[reg]:raise ValueError('preserved register '+reg)
    def widths(label,count):
        rows=re.findall('^'+label+r' code=(\w+) width=(\w+)$',text,re.M)
        if len(rows)!=count or [int(c,16) for c,w in rows]!=list(range(count)):raise ValueError('fixture count/order')
        return [int(w,16) for c,w in rows]
    chars=widths('TW_CHAR',256);repeats=widths('TW_REPEAT',273)
    # Integer advances and a single 8.8 scale explain independently measured
    # 192-character runs, individual CharWidth calls and every title prefix.
    advances=[(w*256+192*299//2)//(192*299) for w in repeats[:256]]
    if any(w!=a*192*299//256 for w,a in zip(repeats,advances)):raise ValueError('repeat model')
    if any(w!=a*299//256 for w,a in zip(chars,advances)):raise ValueError('character model')
    for length,width in enumerate(repeats[256:],1):
        if width!=sum(advances[c] for c in title[:length])*299//256:raise ValueError('prefix rounding')
    if int(result['width'],16)!=repeats[-1] or repeats[-1]!=99:raise ValueError('original whole-string width')
    return advances
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('log',type=Path);p.add_argument('--status',type=int,required=True);a=p.parse_args()
    try:
        check(a.log.read_text(),a.status)
        print('PASS TextWidth reference: original bytes, range, port and preserved ABI; 256 character widths, 256 repeated runs, 17 prefixes; integer 8.8 accumulation matches all results')
    except (ValueError,OSError,KeyError,IndexError) as e:raise SystemExit('FAIL TextWidth: '+str(e))
