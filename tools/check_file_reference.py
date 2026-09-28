#!/usr/bin/env python3
"""Validate byte-attributed startup File Manager parameter-block evidence."""
import argparse
from pathlib import Path
import struct
import unittest
import trap_census as census
from mac_trap_report import fields, caller

def block(record):
    return b''.join(record[f'pb{i}'].to_bytes(4,'big') for i in range(20))
def word(data, offset): return struct.unpack_from('>H',data,offset)[0]
def long(data, offset): return struct.unpack_from('>I',data,offset)[0]
def name(record):
    # ioNamePtr may be null, or output-only (GetFCBInfo). Decode only when used.
    if not long(block(record),18): return None
    raw=b''.join(record[f'name{i}'].to_bytes(4,'big') for i in range(12))
    if raw[0]>47: raise ValueError('truncated input filename')
    return raw[1:1+raw[0]].decode('mac_roman')

def capture(lines, resource):
    census.load(resource)
    first={}
    for seg,offset in census.JT: first.setdefault(seg,offset)
    last=None; pending={}; pairs=[]; complete=False
    for line in lines:
        if line.startswith(('PASS file-reference captured;','SESSION complete;')): complete=True
        if line.startswith('FAIL ') or 'Error in breakpoint' in line:
            raise ValueError('reference execution failed')
        if line.startswith('TRAP '):
            f=fields(line)
            maps={(s,(f['j'+str(s)]&0xffffff)-off,len(census.CODE[s]))
                  for s,off in first.items() if f.get('j'+str(s))}
            last=(f,caller(f['pc'],f['trap'],maps,census.CODE))
        elif line.startswith('FILE '):
            f=fields(line)
            if last is None or f['pc']!=last[0]['pc'] or f['trap']!=last[0]['trap']:
                raise ValueError('FILE record lacks matching dispatcher entry')
            if last[1] is not None:
                block(f) # All 80 bytes required, even if the caller uses fewer.
                key=((f['pc']+2)&0xffffff,f['pb']&0xffffff)
                if key in pending: raise ValueError('unreturned repeated file call')
                pending[key]=(last[1],f)
        elif line.startswith('RESULT '):
            f=fields(line);key=(f['pc']&0xffffff,f['a0']&0xffffff)
            if key not in pending: continue # alternate glue fall-through / non-file return
            at,before=pending.pop(key)
            if f['trap']!=before['trap']: raise ValueError('return trap mismatch')
            after=block(f)
            if word(after,16)!=(f['d0']&65535): raise ValueError('ioResult differs from D0.W')
            pairs.append((at,before,f))
    if not complete:
        raise ValueError('no positive session completion')
    if pending: raise ValueError('unreturned direct file calls')
    return pairs

def validate(pairs, size, required=('itd_ress.pak',)):
    fcbs=[p for p in pairs if p[0]==(3,0x4144) and p[1]['selector']==8]
    if len(fcbs)!=1: raise ValueError('need one original startup GetFCBInfo')
    _,before,result=fcbs[0];pb=block(result)
    if result['d0'] or long(pb,40)!=size or not long(pb,58) or not long(pb,32):
        raise ValueError('application fork identity/length mismatch')
    opened={}; read_bytes={}; data_wd=None; movies_error=None
    for at,b,r in pairs:
        code=b['trap']&0x8ff; raw=block(r)
        if code==0x60 and b['selector']==1:
            path=name(b)
            if path==':Alone Data:' and r['d0']==0: data_wd=word(raw,22)
            if path==':Alone Movies:': movies_error=r['d0']&65535
        if code==0 and r['d0']==0:
            opened[word(raw,24)]=name(b)
        elif code==2 and (r['d0']&65535) in (0,0xffd9): # noErr / eofErr
            path=opened.get(word(raw,24))
            if path: read_bytes[path]=read_bytes.get(path,0)+long(raw,40)
        elif code==1 and r['d0']==0: opened.pop(word(raw,24),None)
    if not data_wd or movies_error!=0xffd5: raise ValueError('directory success/missing control absent')
    for suffix in required:
        if not any(k and k.lower().endswith(':'+suffix) and v>0 for k,v in read_bytes.items()):
            raise ValueError('no positive original read of '+suffix)
    return (f'GetFCBInfo ref=${word(block(before),24):04X} file={long(pb,32)} '
            f'parent={long(pb,58)} volume=${word(pb,52):04X} EOF={long(pb,40)} '
            f'physical={long(pb,44)} mark={long(pb,48)} data-WD=${data_wd:04X}',read_bytes)

def validate_directories(pairs, folder):
    """Startup's byte-attributed seven file calls, plus FindFolder's live outputs."""
    if len(pairs)<7: raise ValueError('incomplete startup directory sequence')
    expected=[(0xa260,8),(0xa260,1),(0xa015,None),(0xa260,1),
              (0xa260,1),(0xa015,None),(0xa260,1)]
    for (_,b,_),(trap,selector) in zip(pairs,expected):
        if b['trap']!=trap or (selector is not None and b['selector']!=selector):
            raise ValueError('wrong startup directory call order')
    if folder.get('folderVolume')!=0xffff or not folder.get('folderID') or 'r0' not in folder or folder['r0']>>16:
        raise ValueError('FindFolder output absent or failed')
    parent=long(block(pairs[0][2]),58)
    app=word(block(pairs[1][2]),22)
    for index in (2,5):
        _,before,after=pairs[index]
        if name(before) is not None or word(block(before),22)!=app or after['d0']:
            raise ValueError('SetVol did not use application WD')
    for index,path,directory,volume in ((1,None,parent,0),(3,':Alone Data:',parent,0),
        (4,None,folder['folderID'],0xffff),(6,':Alone Movies:',parent,0)):
        _,before,after=pairs[index];raw=block(before)
        error=0xffd5 if index==6 else 0
        if name(before)!=path or long(raw,48)!=directory or word(raw,22)!=volume or (after['d0']&65535)!=error:
            raise ValueError('directory arguments/result mismatch')
        if not error and not word(block(after),22):raise ValueError('missing WD identity')
    return 'PASS startup-directories: SetVol=2 OpenWD=3 missing-movies=-43 FindFolder=pref'

def folder_result(lines):
    found=[]
    for line in lines:
        if line.startswith('RESULT seg=3 offset=4356 trap=A823 '):found.append(fields(line))
    if len(found)!=1: raise ValueError('need one original FindFolder return')
    return found[0]

class Tests(unittest.TestCase):
    def test_blocks(self):
        r={f'pb{i}':i for i in range(20)}
        self.assertEqual(len(block(r)),80);self.assertEqual(long(block(r),76),19)
        self.assertIsNone(name({**r,'pb4':0,'pb5':0}))
        del r['pb19']
        with self.assertRaises(KeyError): block(r)
    def test_required_evidence(self):
        def record(values=(),path=None):
            raw=bytearray(80)
            for off,size,value in values:raw[off:off+size]=value.to_bytes(size,'big')
            r={f'pb{i}':long(raw,4*i) for i in range(20)}
            if path is not None:
                raw[18:22]=(0x1000).to_bytes(4,'big')
                r.update({f'pb{i}':long(raw,4*i) for i in range(20)})
                text=bytes([len(path)])+path.encode('mac_roman')
                text=text.ljust(48,b'\0')
                r.update({f'name{i}':long(text,4*i) for i in range(12)})
            return {'d0':0,**r}
        pairs=[((3,0x4144),{'selector':8,'trap':0xa260,**record([(24,2,123)])},
            record([(32,4,3),(40,4,42),(52,2,65535),(58,4,2)])),
            ((3,0x40de),{'selector':1,'trap':0xa260,**record(path=':Alone Data:')},record([(22,2,8)])),
            ((3,0x40de),{'selector':1,'trap':0xa260,**record(path=':Alone Movies:')},
                {**record(),'d0':0xffffffd5})]
        for ref,path in ((10,':Alone Data:itd_ress.PAK'),(11,':Alone Data:Present.PAK')):
            pairs.append(((11,0xfbe),{'trap':0xa000,**record(path=path)},record([(24,2,ref)])))
            pairs.append(((11,0x111e),{'trap':0xa002,**record()},record([(24,2,ref),(40,4,3)])))
        self.assertIn('EOF=42',validate(pairs,42)[0])
        with self.assertRaises(ValueError):validate(pairs[:-1],42,('itd_ress.pak','present.pak'))
        with self.assertRaises(ValueError):validate(pairs,43)

    def test_directory_missing_evidence(self):
        with self.assertRaises(ValueError):validate_directories([], {})
        with self.assertRaises(ValueError):folder_result([])
        with self.assertRaises(ValueError):folder_result(['RESULT seg=3 offset=4356 trap=A823 ']*2)

    def test_no_fake_success(self):
        with self.assertRaises(ValueError): validate([],1424934)

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('log',nargs='?',type=Path)
    p.add_argument('--resource',type=Path,default=Path('tmp/runtime-data/Alone In The Dark'))
    p.add_argument('--require-file',action='append',default=[])
    p.add_argument('--startup-directories',action='store_true')
    p.add_argument('--selftest',action='store_true');a=p.parse_args()
    if a.selftest: return not unittest.TextTestRunner().run(unittest.defaultTestLoader.loadTestsFromTestCase(Tests)).wasSuccessful()
    if not a.log:p.error('log required')
    try:
        with a.log.open() as source:pairs=capture(source,str(a.resource))
        required=tuple(a.require_file) or ('itd_ress.pak',)
        summary,reads=validate(pairs,a.resource.stat().st_size,required)
        if a.startup_directories:
            with a.log.open() as source:folder=folder_result(source)
            print(validate_directories(pairs,folder))
    except (ValueError,KeyError) as e: raise SystemExit('FAIL file-reference: '+str(e))
    print(summary)
    for path,count in sorted(reads.items()): print(f'read {path}: {count} bytes')
    print(f'PASS file-reference: direct paired calls={len(pairs)} application-FCB=1 data-directory=1 absent-movies=1 required-PAK-reads={len(required)}')
if __name__=='__main__':raise SystemExit(main())
