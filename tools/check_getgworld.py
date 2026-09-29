#!/usr/bin/env python3
"""Verify original current-world identity and its screen-backed window-manager port."""
import argparse
import hashlib
from pathlib import Path
import re
import unittest
from resource_fork import read_resource_fork
REFERENCE='PASS GetGWorld reference calls=1'
NATIVE='PASS native GetGWorld calls=1 next=SIZEWINDOW'
PRESERVED=[f'd{n}' for n in range(8)]+[f'a{n}' for n in range(2,7)]
def original(path):
    rows=read_resource_fork(path)
    for seg,start,end,want in ((13,0x30d4,0x30e8,'553e52baae3a6c5342a0c71c2c4babd3feb0132462d11626e69f507bf390408b'),(7,0x3f92,0x3f9a,'bd9f460f5b1e3c012f695c12edd1f8dba67ea1a9f34741b50a6ea7e93cb37b3a')):
        data=next(r.body for r in rows if r.kind==b'CODE' and r.rid==seg)
        if hashlib.sha256(data[start:end]).hexdigest()!=want:raise ValueError('original GetGWorld/InitGraf bytes')
def fields(line):return {k:int(v,16) for k,v in re.findall(r'(\w+)=([0-9A-F]+)(?= |$)',line)}
def check(text,status,native=False):
    if status!=0 or any(x in text for x in ('FAIL','[LUA ERROR]','unknown command','Error in','Program received signal','timeout')):raise ValueError('failed observer')
    for marker in (NATIVE if native else REFERENCE,'[Inferior 1 (Remote target) detached]' if native else 'Exited via the debugger'):
        if text.count(marker)!=1:raise ValueError('missing/duplicate completion')
    rows={}
    for name in ('WORLD_ENTER','WORLD_RETURN'):
        matches=[line for line in text.splitlines() if line.startswith(name+' ')]
        if len(matches)!=1:raise ValueError('paired call coverage')
        rows[name]=fields(matches[0])
    e,r=rows.values()
    if e['seq']!=1 or r['seq']!=1 or e['opcode']!=0xab1d4eba or e['selectorBytes']!=0x80005 or e['d0']!=0x80005:raise ValueError('original call identity')
    if e['deviceOut']!=e['portOut']+4 or not e['portOut'] or r['sp']!=e['sp']+8 or r['expected']!=r['sp']:raise ValueError('outputs/stack contract')
    if any(e[k]!=r[k] for k in PRESERVED):raise ValueError('preserved registers')
    if not r['port'] or not r['device'] or any(r['port']!=x for x in (r['qdPort'],r['wmgrPort'],e['qdPort'],e['wmgrPort'])) or r['device']!=r['mainDevice'] or r['device']!=e['mainDevice']:raise ValueError('current port/device identity')
    return rows

def record(text,name,size):
    values=re.findall(r'^'+name+r' seq=1 data=([0-9A-F]+)$',text,re.M)
    if len(values)!=1:raise ValueError('record coverage')
    data=bytes.fromhex(values[0])
    if len(data)<size:raise ValueError('record extent')
    return data[:size]

def port_layout(port,screen):
    if len(port)!=108 or len(screen)!=14:raise ValueError('port/screen record extent')
    if port[2:6]!=screen[:4] or port[6:8]!=bytes.fromhex('0280') or screen[4:6]!=bytes.fromhex('0050') or port[8:16]!=screen[6:14] or port[16:24]!=screen[6:14] or screen[6:14]!=bytes.fromhex('0000000001e00280'):raise ValueError('screen alias/stride/bounds')
    if port[74:76]!=bytes(2):raise ValueError('window-manager default text size')

def reference(text,status):
    check(text,status);port=record(text,'WORLD_PORT',108);screen=record(text,'WORLD_SCREEN',14)
    if port!=record(text,'WORLD_PORT_BEFORE',108):raise ValueError('GetGWorld changed the current port')
    port_layout(port,screen)
    gd=record(text,'WORLD_DEVICE',62)
    if gd[34:46]!=bytes.fromhex('0000000001e0028000000083'):raise ValueError('reference main-device mode')
    return port,screen,gd

def native(text,status,ref):
    check(text,status,True)
    before=Path('tmp/getgworld-native-before-port.bin').read_bytes();port=Path('tmp/getgworld-native-after-port.bin').read_bytes();screen=Path('tmp/getgworld-native-screen.bin').read_bytes();gd=Path('tmp/getgworld-native-device.bin').read_bytes()
    if before!=port:raise ValueError('native port changed')
    port_layout(port,screen)
    # Base and region/master addresses belong to their respective systems.
    for start,end in ((0,2),(6,24),(32,108)):
        if port[start:end]!=ref[0][start:end]:raise ValueError('paired port fields')
    if screen[4:]!=ref[1][4:]:raise ValueError('paired screen descriptor')
    for start,end in ((4,6),(10,12),(20,22),(30,46)):
        if gd[start:end]!=ref[2][start:end]:raise ValueError('paired main-device fields')

class Checks(unittest.TestCase):
    def test_incomplete(self):
        for flag,marker in ((False,REFERENCE),(True,NATIVE)):
            for status in (0,124,None):
                with self.assertRaises(ValueError):check(marker,status,flag)
    def test_layout(self):
        port=bytearray(108);port[2:6]=bytes.fromhex('00123456');port[6:8]=bytes.fromhex('0280');port[8:16]=port[16:24]=bytes.fromhex('0000000001e00280')
        screen=bytes.fromhex('0012345600500000000001e00280');port_layout(port,screen)
        for changed in (screen[:3]+b'X'+screen[4:],screen[:4]+bytes.fromhex('0280')+screen[6:]):
            with self.assertRaises(ValueError):port_layout(port,changed)
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('log',type=Path,nargs='?');p.add_argument('--status',type=int);p.add_argument('--native',type=Path);p.add_argument('--native-status',type=int);p.add_argument('--selftest',action='store_true');a=p.parse_args()
    if a.selftest:raise SystemExit(not unittest.TextTestRunner().run(unittest.defaultTestLoader.loadTestsFromTestCase(Checks)).wasSuccessful())
    try:
        original(Path('tmp/runtime-data/Alone In The Dark'));text=a.log.read_text();ref=reference(text,a.status)
        for bad,status in ((text,124),(text,None),(text.replace(REFERENCE,''),0),(text+REFERENCE,0),(text.replace('opcode=AB1D4EBA','opcode=AB1D4EBB'),0),(text.replace('selectorBytes=00080005','selectorBytes=00080006'),0)):
            try:check(bad,status)
            except ValueError:continue
            raise ValueError('rejection fixture passed')
        if a.native:native(a.native.read_text(),a.native_status,ref)
        print('PASS GetGWorld: original bytes, eight-byte cleanup, preserved registers, current WMgrPort/main device, shared screen view'+('; complete portable native port fields match' if a.native else ''))
    except (OSError,ValueError,KeyError,AttributeError) as error:raise SystemExit('FAIL GetGWorld: '+str(error))
