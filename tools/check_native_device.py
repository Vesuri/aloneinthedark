#!/usr/bin/env python3
"""Compare original native device selection with its checked Macintosh contract."""
import argparse
import hashlib
from pathlib import Path
import re
from check_device_startup import check,original,ORDER,SITES

def native(text,status,gd,pm,ct,pixels,reference):
    if status!=0 or any(s in text for s in ('FAIL','Error in','Program received signal','timeout')):raise ValueError('failed native observer')
    for marker in ('PASS native device selection calls=4 count=1','[Inferior 1 (Remote target) detached]','NEXT state=3 trap=AB1D QUICKDRAW/NEWGWORLD caller=10+74'):
        if text.count(marker)!=1:raise ValueError('missing/duplicate native completion')
    entries=re.findall(r'DEVICE native entry=(\d+) offset=([0-9a-f]+) sp=([0-9A-F]+) args=([0-9A-F/]+)',text)
    returns=re.findall(r'DEVICE native return=(\d+) sp=([0-9A-F]+) result=([0-9A-F]+) D0=([0-9A-F]+)',text)
    if len(entries)!=4 or len(returns)!=4:raise ValueError('paired native coverage')
    handle=int(returns[0][2],16)
    for seq,(e,r,off,ref) in enumerate(zip(entries,returns,ORDER,reference),1):
        if int(e[0])!=seq or int(r[0])!=seq or int(e[1],16)!=off or int(r[1],16)!=int(e[2],16)+SITES[off][1]:raise ValueError('native order/stack')
        if int(r[3],16)!=ref['DEVICE_RETURN']['d0']:raise ValueError('paired D0')
    depth=bytes.fromhex(entries[1][3].replace('/',''))
    if depth[:6]!=reference[1]['enter']['args'][:6] or int.from_bytes(depth[6:10],'big')!=handle or int(returns[1][2],16)>>16!=0x83:raise ValueError('native HasDepth arguments/mode')
    if int(entries[3][3].split('/')[0],16)!=handle or int(returns[3][2],16)!=0:raise ValueError('native single-device traversal')
    if (len(gd),len(pm),len(ct),len(pixels))!=(62,50,2056,307200) or any(pixels):raise ValueError('native record/backing extents or unexpected writes')
    refgd=reference[0]['DEVICE_RECORD'];refpm=reference[0]['PIXMAP_RECORD'];refct=reference[0]['CTABLE_RECORD']
    for off,n in ((4,2),(10,2),(20,2),(30,4),(34,8),(42,4)):
        if gd[off:off+n]!=refgd[off:off+n]:raise ValueError('paired GDevice field')
    if pm[4:42]!=refpm[4:42] or pm[46:50]!=refpm[46:50] or ct[4:8]!=refct[4:8]:raise ValueError('paired PixMap/CTable header')
    # Initial system colours, independently measured before game realization.
    if hashlib.sha256(ct[4:]).hexdigest()!='8bde63f387a037ed68a9a1b659571162634834d079dd17e593df446b53aabb19':
        raise ValueError('initial system colour table')
    if not int.from_bytes(pm[:4],'big') or not int.from_bytes(pm[42:46],'big') or not int.from_bytes(gd[22:26],'big'):raise ValueError('native backing pointers')

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('log',type=Path);p.add_argument('--status',type=int);p.add_argument('--reference',type=Path,required=True);p.add_argument('--reference-status',type=int,required=True);a=p.parse_args()
    try:
        original(Path('tmp/runtime-data/Alone In The Dark'));reference=check(a.reference.read_text(),a.reference_status)
        payload=[Path('tmp/m2-device-native-'+n+'.bin').read_bytes() for n in ('gd','pm','ct','pixels')]
        text=a.log.read_text();native(text,a.status,*payload,reference)
        for bad,status in ((text,124),(text,None),(text.replace('calls=4','calls=0'),0),(text.replace('result=0083','result=0001'),0)):
            try:native(bad,status,*payload,reference)
            except ValueError:continue
            raise ValueError('native rejection fixture passed')
        print('PASS paired native device: four original calls, stack/register observer, mode 0x83, 640x480x8 records, 307200 real bytes; next NEWGWORLD')
    except (OSError,ValueError,KeyError,AttributeError) as error:raise SystemExit('FAIL native device: '+str(error))
