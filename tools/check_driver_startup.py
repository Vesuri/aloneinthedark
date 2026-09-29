#!/usr/bin/env python3
"""Validate the bounded, unmodified Mac SoundMusicSys startup contract."""
import argparse
import hashlib
from pathlib import Path
import re
import unittest
from check_font_lookup import check_original
from check_native_font import check_driver_source
from resource_fork import read_resource_fork

ARM='ARM driver startup dispatcher bytes=2f0a2f02246f000a'
COMPLETE='PASS driver startup reference: second Times=14 calls=2'
DRIVER_HASH='3880a65dcdf4ece9c5e91712ce0af9866b0dcc435bd09fc5ad536eff2b70b470'
PRESERVED=[f'd{i}' for i in range(2,8)]+[f'a{i}' for i in range(7)]

def check_call_source(path):
    check_original(path);check_driver_source(path)
    core=next(r.body for r in read_resource_fork(path) if r.kind==b'CODE' and r.rid==3)
    if hashlib.sha256(core[0x1d28:0x1d6c]).hexdigest()!='0a07124a10112a37e832f94caf9bce1380189f7523f52da8fe59a6a57eb2075a':
        raise ValueError('original driver call/argument/cleanup bytes')

def original(path,driver):
    check_call_source(path)
    data=driver.read_bytes()
    if len(data)!=29256 or hashlib.sha256(data).hexdigest()!=DRIVER_HASH:
        raise ValueError('original live decrypted driver bytes')

def fields(line):
    return dict(re.findall(r'(\w+)=([0-9A-F/]+)(?= |$)',line))

def check(text,status):
    if status!=0 or any(s in text for s in ('FAIL','LUA ERROR','Error in breakpoint','Unknown command','timeout')):
        raise ValueError('failed or incomplete runner')
    if text.count(ARM)!=1 or text.count(COMPLETE)!=1 or text.count('Exited via the debugger')!=1:
        raise ValueError('missing/duplicate completion')
    rows=[line for line in text.splitlines() if line.startswith('DRIVER_')]
    if len(rows)!=6 or [r.split()[0] for r in rows]!=['DRIVER_ARM','DRIVER_INSTALLED','DRIVER_CALL','DRIVER_RETURN','DRIVER_CALL','DRIVER_RETURN']:
        raise ValueError('call count/order')
    if fields(rows[0])!={'init':'4E90508F','quality':'4E90508F','font':'A9003F3C'}:
        raise ValueError('live original call bytes')
    installed=fields(rows[1])
    if installed.get('bytes')!='202F0004/222F0008/48E73FFE' or installed.get('store')!='2B50F954' or not int(installed.get('entry','0'),16) or int(installed.get('raw','0'),16)&0xffffff!=int(installed['entry'],16):
        raise ValueError('driver entry/store attribution')
    for i,(selector,caller,quality,rate,d1) in enumerate(((21,0x1d48,'00','0172/0001',0),(24,0x1d62,'01','00B9/0000',1))):
        before,after=map(fields,rows[2+i*2:4+i*2])
        for r in (before,after):
            if int(r.get('count','0'),16)!=i+1 or int(r.get('selector','0'),16)!=selector:
                raise ValueError('selector sequence')
        if int(before.get('caller','0'),16)!=caller or before.get('cleanup')!='508F' or not int(before.get('sp','0'),16) or after.get('sp')!=before['sp'] or after.get('expected')!=before['sp']:
            raise ValueError('caller/stack contract')
        if before.get('a0')!=installed['raw'] or any(k not in before or before[k]!=after.get(k) for k in PRESERVED):
            raise ValueError('preserved register contract')
        if after.get('d0')!='00000000' or int(after.get('d1','FF'),16)!=d1 or after.get('error')!='0000':
            raise ValueError('return result')
        if after.get('voices')!='0006/0002/0002' or after.get('quality')!=quality or after.get('rate')!=rate:
            raise ValueError('initialized driver state')
        if i==0:
            if before.get('packet0')!='00060002' or before.get('packet1')!='0002' or not int(before.get('arg','0'),16):
                raise ValueError('voice configuration packet')
        elif before.get('arg')!='10B':raise ValueError('quality argument')
    if not text.index(ARM)<text.index(rows[0])<text.index(rows[-1])<text.index(COMPLETE)<text.index('Exited via the debugger'):
        raise ValueError('completion order')

class Checks(unittest.TestCase):
    def test_contract(self):
        regs=' '.join(f'{k}=00000100' for k in PRESERVED if k!='a0')+' a0=80100000'
        rows=[ARM,'DRIVER_ARM init=4E90508F quality=4E90508F font=A9003F3C','DRIVER_INSTALLED entry=100000 raw=80100000 bytes=202F0004/222F0008/48E73FFE store=2B50F954']
        for n,selector,caller,arg,packet,quality,rate,d1 in ((1,'15','1D48','2000','00060002','00','0172/0001',0),(2,'18','1D62','10B','00000000','01','00B9/0000',1)):
            rows += [f'DRIVER_CALL count={n} caller={caller} cleanup=508F selector={selector} arg={arg} packet0={packet} packet1=0002 sp=3000 d0=00000000 d1=00000000 {regs}',f'DRIVER_RETURN count={n} selector={selector} sp=3000 expected=3000 voices=0006/0002/0002 quality={quality} rate={rate} error=0000 d0=00000000 d1={d1:08X} {regs}']
        rows += [COMPLETE,'Exited via the debugger'];good='\n'.join(rows);check(good,0)
        bads=[good.replace(a,b) for a,b in ((COMPLETE,''),('selector=15','selector=16'),('caller=1D48','caller=1D46'),('expected=3000','expected=3008'),('voices=0006','voices=0004'),('arg=10B','arg=10C'),('d0=00000000','d0=00000001'),('packet0=00060002','packet0=00060004'),('store=2B50F954','store=00000000'),('rate=00B9/0000','rate=0172/0001'))]
        bads += [good+'\n'+COMPLETE,good+'\nFAIL',good.replace('d2=00000100','d2=00000200',1),good.replace(rows[3]+'\n',''),good.replace(rows[5],rows[6])]
        for bad in bads:
            with self.subTest(bad=bad),self.assertRaises(ValueError):check(bad,0)
        for status in (None,1,124):
            with self.assertRaises(ValueError):check(good,status)

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('log',nargs='?',type=Path);p.add_argument('--status',type=int);p.add_argument('--selftest',action='store_true');p.add_argument('--original',type=Path,default=Path('tmp/runtime-data/Alone In The Dark'));p.add_argument('--driver',type=Path,default=Path('tmp/m2-driver-original.bin'));a=p.parse_args()
    if a.selftest:raise SystemExit(not unittest.TextTestRunner().run(unittest.defaultTestLoader.loadTestsFromTestCase(Checks)).wasSuccessful())
    try:
        original(a.original,a.driver);check(a.log.read_text(),a.status)
        print('PASS driver startup reference: original bytes, two selectors, state, preserved registers, stack and second Times=20')
    except (OSError,ValueError,KeyError,AttributeError,StopIteration) as error:raise SystemExit('FAIL driver startup reference: '+str(error))
