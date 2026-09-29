#!/usr/bin/env python3
"""Independent exact-rational checks of the native finite SANE subset."""
import argparse
from fractions import Fraction as F
import os
from pathlib import Path
import random
import re
import subprocess
import tempfile
ROOT=Path(__file__).resolve().parents[1]
def pow2(e):return F(2)**e
def rounded(x):
    q,r=divmod(x.numerator,x.denominator)
    return q+int(r*2>x.denominator or (r*2==x.denominator and q&1))
def encode(value,negative_zero=False):
    negative=value<0 or (not value and negative_zero);value=abs(value)
    if not value:return (0x8000 if negative else 0).to_bytes(2,'big')+bytes(8)
    e=value.numerator.bit_length()-value.denominator.bit_length()
    if value<pow2(e):e-=1
    if e>16383:return None
    if e < -16382:
        m=rounded(value*pow2(16445));biased=int(m>=1<<63)
    else:
        m=rounded(value*pow2(63-e))
        if m==1<<64:m>>=1;e+=1
        if e>16383:return None
        biased=e+16383
    return (biased|(0x8000 if negative else 0)).to_bytes(2,'big')+m.to_bytes(8,'big')
def extended(b):
    e=int.from_bytes(b[:2],'big');m=int.from_bytes(b[2:10],'big');sign=bool(e&0x8000);e&=0x7fff
    if e==0x7fff or bool(m>>63)!=bool(e):return None
    value=F(m)*pow2((e or 1)-16383-63)
    return -value if sign else value
def single(b):
    v=int.from_bytes(b[:4],'big');e=(v>>23)&255;m=v&0x7fffff
    if e==255:return None
    if e:m|=0x800000
    value=F(m)*pow2(e-150 if e else -149)
    return -value if v>>31 else value
def word(n):return (n&65535).to_bytes(2,'big')
def vector(op,source,dest):
    source=source+bytes([0xa5])*(12-len(source));dest=dest+bytes([0x5a])*(12-len(dest))
    result=None;x=extended(dest);src=extended(source)
    if op==0x200e:result=encode(F(int.from_bytes(source[:2],'big',signed=True)))
    elif op==0x1004 and x is not None and single(source) is not None:
        result=encode(x*single(source),bool(dest[0]&128)!=bool(source[0]&128))
    elif op==0x2000 and x is not None:
        result=encode(x+int.from_bytes(source[:2],'big',signed=True))
    elif op==0x16 and x is not None:result=encode(F(int(x)),bool(dest[0]&128))
    elif op==0x2010 and src is not None:
        n=rounded(abs(src))*(-1 if src<0 else 1)
        if -32768<=n<=32767:result=word(n)
    return dict(op=op,source=source.hex(),before=dest.hex(),ok=result is not None,
                after=(result+dest[len(result):] if result is not None else dest).hex())
def fixtures():
    out=[]
    for n in (-32768,-1,0,1,32767):out.append(vector(0x200e,word(n),bytes(10)))
    for n in (F(1,2),F(3,2),F(5,2),F(-1,2),F(-3,2),F(-5,2),F(32767),F(-32768)):
        out.append(vector(0x2010,encode(n),bytes(10)))
        out.append(vector(0x16,bytes(2),encode(n)))
    for x,n in [(F(355),0),(F(1),-1),(F(-1),1),(F(-355,2),-20),(F(1)+pow2(-63),-1),(pow2(-130),1),(pow2(200),32767)]:
        out.append(vector(0x2000,word(n),encode(x)))
    for x,s in [(F(355),0x3f000000),(F(-355),0x3f000000),(F(32767),0x3eaaaaab),
                (F(1)+pow2(-63),0x3f800001),(F(1)+3*pow2(-63),0x3f800001),
                (pow2(-16382),0x3f000000),(pow2(-16445),0x3f000000),(3*pow2(-16445),0x3f000000),
                (F(1),1),(F(0),0xbf800000),(F(-1),0)]:
        out.append(vector(0x1004,s.to_bytes(4,'big'),encode(x)))
    out.append(vector(0x16,bytes(2),encode(F(0),True)))
    out.append(vector(0x2000,word(0),encode(F(0),True)))
    assert all(v['ok'] for v in out)
    return out

def check_host():
    rows=fixtures();rng=random.Random(0x68020)
    for i in range(2400):
        x=encode(F(rng.randrange(-(1<<70),1<<70))*pow2(rng.randrange(-200,201)))
        op=(0x200e,0x1004,0x2000,0x16,0x2010)[i%5]
        src=word(rng.randrange(-32768,32768))
        if op==0x1004:src=rng.getrandbits(32).to_bytes(4,'big')
        if op==0x2010:src=x;x=bytes(10)
        rows.append(vector(op,src,x))
    for bad in [bytes.fromhex('7fff8000000000000000'),bytes.fromhex('3fff0000000000000001'),bytes.fromhex('00008000000000000000')]:
        for op in (0x1004,0x2000,0x16):rows.append(vector(op,word(1),bad))
        rows.append(vector(0x2010,bad,bytes(10)))
    rows.append(vector(0x1004,bytes.fromhex('40000000'),bytes.fromhex('7ffeffffffffffffffff')))
    rows.append(vector(0x9999,bytes(10),bytes(10)))
    with tempfile.TemporaryDirectory(prefix='aitd-sane-') as work:
        exe=Path(work)/'check'
        subprocess.run([os.environ.get('HOST_CXX','c++'),'-std=c++17','-Wall','-Wextra','-Werror','-fsanitize=address,undefined',str(ROOT/'tools/test_sane_cli.cpp'),'-o',str(exe)],check=True)
        text=''.join(f"{v['op']:x} {v['source']} {v['before']}\n" for v in rows)
        result=subprocess.run([str(exe)],input=text,text=True,capture_output=True,check=True,timeout=30)
        lines=result.stdout.splitlines();assert len(lines)==len(rows)
        for i,(v,line) in enumerate(zip(rows,lines)):
            want=f"{int(v['ok'])} {v['after']}"
            if line!=want:raise ValueError(f'case {i} {v}: got {line}, expected {want}')
    print(f'PASS SANE rational oracle: {len(rows)} cases, rounding/cancellation/subnormals, rejected values and untouched destination guards')

def check_reference(path,status):
    if status!=0:raise ValueError('nonzero or missing reference status')
    text=path.read_text();rows=fixtures()
    if any(s in text for s in ('FAIL','[LUA ERROR]','unknown command','Error in')):raise ValueError('reference failure')
    if text.count(f'PASS SANE fixtures calls={len(rows):X}')!=1 or text.count('Exited via the debugger')!=1:raise ValueError('reference completion')
    entries=re.findall(r'^FIXTURE_ENTER seq=([0-9A-F]+) op=([0-9A-F]+) sp=([0-9A-F]+) sr=([0-9A-F]+) fp=([0-9A-F]+)$',text,re.M)
    returns=re.findall(r'^FIXTURE_RETURN seq=([0-9A-F]+) sp=([0-9A-F]+) sr=([0-9A-F]+) fp=([0-9A-F]+) data=([0-9A-F]+)$',text,re.M)
    if len(entries)!=len(rows) or len(returns)!=len(rows):raise ValueError('fixture coverage')
    for i,(v,e,r) in enumerate(zip(rows,entries,returns),1):
        if int(e[0],16)!=i or int(r[0],16)!=i or int(e[1],16)!=v['op']:raise ValueError('fixture identity')
        if int(r[1],16)!=int(e[2],16)+(6 if v['op']==0x16 else 10):raise ValueError('fixture stack')
        # FP68K clobbers CCR; each original continuation overwrites it before use.
        if int(e[4],16)!=0 or int(r[3],16)!=0:raise ValueError('fixture FPState')
        if r[4].lower()!=v['after']:raise ValueError(f'fixture result {i}: {r[4]} != {v["after"]}')
    print(f'PASS SANE Mac fixtures: {len(rows)} exact results, stack cleanup, FPState and destination guards')

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--write-fixtures',type=Path);p.add_argument('--reference',type=Path);p.add_argument('--status',type=int);a=p.parse_args()
    if a.write_fixtures:
        a.write_fixtures.write_text('return {\n'+''.join('{op=0x%x,source="%s",before="%s"},\n'%(v['op'],v['source'],v['before']) for v in fixtures())+'}\n')
    elif a.reference:check_reference(a.reference,a.status)
    else:check_host()
