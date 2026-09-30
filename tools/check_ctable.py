#!/usr/bin/env python3
"""Verify original GetCTable bytes/mutations and independent ownership fixtures."""
import argparse
import hashlib
from pathlib import Path
import re
import struct
import unittest
from resource_fork import read_resource_fork
from check_getgworld import fields
from check_choice_services import PRESERVED,one
# label, trap, argument bytes popped, ResError, MemError; result expectations below.
CASES=(
 ('original-size',0xa025,0,0x8888,0),('original-state',0xa069,0,0x8888,0),
 ('original-attrs',0xa9a6,4,0xff40,0x7777),('resource',0xa9a0,6,0,0),
 ('resource-size',0xa025,0,0x8888,0),('resource-state',0xa069,0,0x8888,0),
 ('seed-before',0xaa28,0,0x8888,0x7777),('second',0xaa18,2,0,0),
 ('seed-after',0xaa28,0,0x8888,0x7777),('second-state',0xa069,0,0x8888,0),
 ('second-attrs',0xa9a6,4,0xff40,0x7777),('mutate-second',0xa069,0,0x8888,0),
 ('third',0xaa18,2,0,0),('resource-again',0xa9a0,6,0,0),
 ('source-state-again',0xa069,0,0x8888,0),('dispose-second',0xa023,0,0x8888,0),
 ('original-survives',0xa025,0,0x8888,0),('disposed-alias-size',0xa025,0,0x8888,0xff91),
 ('third-survives',0xa025,0,0x8888,0),('missing',0xaa18,2,0,0x7777),
 ('seed-final',0xaa28,0,0x8888,0x7777))
def source(path):
    rows=read_resource_fork(path)
    code=next(r.body for r in rows if r.kind==b'CODE' and r.rid==7)
    if hashlib.sha256(code[0x1108:0x1168]).hexdigest()!='36c034625d8e96eef1f4369b65be8f9725950c9b367a845015826f6754e01bbf':raise ValueError('original call/mutation bytes')
    return next(r.body for r in rows if r.kind==b'clut' and r.rid==128)
def preserved(e,r,pop):
    if r['sp']!=e['sp']+pop or any(e[k]!=r[k] for k in PRESERVED):raise ValueError('stack/register preservation')
def check(text,status,resource,folder,fixture=False,native=False):
    if status!=0 or any(x in text for x in ('FAIL','Error in','[LUA ERROR]','timeout')):raise ValueError('failed observer')
    markers=('ARM native ctable original bytes','PASS original GetCTable and mutations','PASS native GetCTable detached next=DRAWPICTURE original-MDRV=absent') if native else ('ARM ctable dispatcher bytes=2f0a2f02246f000a','PASS original GetCTable and mutations','Exited via the debugger')
    if native and fixture:markers=('ARM native ctable CPU fixture','PASS CPU GetCTable and mutations','PASS native ctable CPU fixture shutdown sources=0/0 lineA=0 result=0')
    for marker in markers:
        if text.count(marker)!=1:raise ValueError('completion')
    e=fields(one(text,r'CTABLE_ENTER (.*)'));r=fields(one(text,r'CTABLE_RETURN (.*)'))
    m=fields(one(text,r'CTABLE_MUTATED (.*)'));preserved(e,r,2)
    if e['id']!=128 or e['slot']!=0 or one(text,r'CTABLE_ENTER .*bytes=([0-9A-F/]+) .*')!='3F3C0080/AA18':raise ValueError('original input/bytes')
    if not r['handle'] or not r['body'] or r['master']!=r['body'] or (r['flags'],r['size'])!=(0x8000,255):raise ValueError('returned table header')
    if m!={'handle':r['handle'],'body':r['body'],'seed':r['seed'],'flags':0,'size':255,'count':256}:raise ValueError('original mutation state')
    prefix='ctable-native' if native else 'ctable-reference'
    before=(folder/(prefix+'-return.bin')).read_bytes();after=(folder/(prefix+'-mutated.bin')).read_bytes()
    if len(resource)!=2056 or before!=struct.pack('>I',r['seed'])+resource[4:]:raise ValueError('returned resource bytes/seed')
    expected=bytearray(before);expected[4:6]=b'\0\0'
    for i in range(256):struct.pack_into('>H',expected,8+i*8,i)
    if after!=expected:raise ValueError('original index/flags mutations')
    if native and not fixture:
        one(text,r'CTABLE_NEXT state=3 trap=A8F6 selector=FFFFFFFF segment=13 offset=382 manager=QUICKDRAW routine=DRAWPICTURE windows=(?:101|127) services=(?:164/164|172/172) reads=62 bytes=265454')
    if not fixture:
        if 'CTABLE_FIX_' in text:raise ValueError('unexpected fixture')
        return
    if text.count('PASS GetCTable ownership fixture calls=15')!=1:raise ValueError('fixture completion')
    ent=re.findall(r'^CTABLE_FIX_ENTER (.*)$',text,re.M);ret=re.findall(r'^CTABLE_FIX_RETURN label=([\w-]+) (.*)$',text,re.M)
    if len(ent)!=21 or [n for n,_ in ret]!=[q[0] for q in CASES]:raise ValueError('fixture coverage/order')
    rows={};base=None
    for n,(es,(label,rs),q) in enumerate(zip(ent,ret,CASES),1):
        x,y=fields(es),fields(rs);rows[label]=y;preserved(x,y,q[2])
        if x['seq']!=n or y['seq']!=n or (y['res'],y['mem'])!=q[3:]:raise ValueError('fixture sequence/errors')
        if base is None:base=x['sp']
        arg=bytes.fromhex(one(es,r'.*args=([0-9A-F/]+) .*').replace('/',''))
        if x['d0']!=0x12345678:raise ValueError('fixture D0 input')
        if q[1] in (0xa025,0xa069,0xa023):
            h=r['handle'] if label.startswith('original') else y['third'] if label=='third-survives' else y['resource'] if label.startswith('resource') or label.startswith('source') or label=='disposed-alias-size' else y['second']
            if x['a0']!=h or x['sp']!=base:raise ValueError('OS handle input')
        elif q[1]==0xa9a6:
            h=r['handle'] if label=='original-attrs' else y['second']
            if x['sp']!=base-6 or arg[:6]!=struct.pack('>IH',h,0xcccc):raise ValueError('attribute input')
        elif q[1]==0xa9a0:
            if x['sp']!=base-10 or arg[:10]!=struct.pack('>HII',128,0x636c7574,0xcccccccc):raise ValueError('resource input')
        elif q[1]==0xaa18:
            if x['sp']!=base-6 or arg[:6]!=struct.pack('>HI',32766 if label=='missing' else 128,0xcccccccc):raise ValueError('GetCTable input')
        elif x['sp']!=base-4 or arg[:4]!=bytes.fromhex('cccccccc'):raise ValueError('seed input')
    first=r['handle'];resource_handle=rows['resource']['result'];second=rows['second']['result'];third=rows['third']['result'];again=rows['resource-again']['result']
    if second!=resource_handle or len({first,second,third,again})!=4 or not all((first,second,third,again)):raise ValueError('detach/reload ownership')
    for label in ('original-size','resource-size','original-survives','third-survives'):
        if rows[label]['d0']!=2056:raise ValueError('handle size')
    for label,value in (('original-state',0),('resource-state',32),('second-state',0),('mutate-second',0),('source-state-again',0),('dispose-second',0),('disposed-alias-size',0xffffff91)):
        if rows[label]['d0']!=value:raise ValueError('handle ownership state/disposal')
    if rows['missing']['result']!=0:raise ValueError('missing table result')
    seed=r['seed']
    if [rows[k]['result'] for k in ('seed-before','seed-after','seed-final')]!=[seed+1,seed+3,seed+5]:raise ValueError('seed sequence')
    expected_second=struct.pack('>I',seed+2)+resource[4:]
    mutated=bytearray(expected_second);mutated[10:12]=bytes.fromhex('1234')
    expected_files={'source':resource,'second':expected_second,'second-mutated':mutated,'source-after-mutation':mutated,'source-after-third':mutated,'third':struct.pack('>I',seed+4)+resource[4:],'source-again':resource}
    for name,wanted in expected_files.items():
        if (folder/f'ctable-fixture-{name}.bin').read_bytes()!=wanted:raise ValueError('fixture table bytes '+name)
class Checks(unittest.TestCase):
    def test_incomplete(self):
        for status in (None,124,0):
            with self.assertRaises(ValueError):check('PASS original GetCTable and mutations',status,b'',Path('tmp'))
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('log',type=Path,nargs='?');p.add_argument('--status',type=int);p.add_argument('--fixture',action='store_true');p.add_argument('--native',action='store_true');p.add_argument('--folder',type=Path,default=Path('tmp'));p.add_argument('--selftest',action='store_true');a=p.parse_args()
    if a.selftest:raise SystemExit(not unittest.TextTestRunner().run(unittest.defaultTestLoader.loadTestsFromTestCase(Checks)).wasSuccessful())
    try:
        resource=source(Path('tmp/runtime-data/Alone In The Dark'));text=a.log.read_text();check(text,a.status,resource,a.folder,a.fixture,a.native)
        for bad,status in ((text,124),(text,None),(text+text,0),(text.replace('id=80','id=81',1),0),(text.replace('count=100','count=FF',1),0)):
            try:check(bad,status,resource,a.folder,a.fixture,a.native)
            except ValueError:continue
            raise ValueError('invalid capture accepted')
        print('PASS GetCTable: bytes, mutations and stack/registers'+('; 21 ownership/seed/disposal fixtures' if a.fixture else ''))
    except (OSError,ValueError,KeyError,AttributeError) as e:raise SystemExit('FAIL GetCTable: '+str(e))
