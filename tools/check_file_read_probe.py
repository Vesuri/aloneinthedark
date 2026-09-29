#!/usr/bin/env python3
"""Synthetic native file fixture; never an original-game read acceptance."""
import argparse
from pathlib import Path
import re
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--write',action='store_true');p.add_argument('--prepare',action='store_true');p.add_argument('--status',type=int,default=0)
a=p.parse_args();root=Path(__file__).resolve().parent.parent;drive=root/'amiga/.run/dh1'
if a.prepare:
    drive.mkdir(parents=True,exist_ok=True)
    (drive/'read-probe.bin').write_bytes(bytes((i*37+(i>>8))&255 for i in range(200003)))
    (drive/'absent-probe.bin').unlink(missing_ok=True)
    if a.write:
        import struct
        def metadata():
            body=b'AFI1'+bytes.fromhex('54455354414954440400001200340000')+struct.pack('>II',0xabcd0102,0xabcd0304)
            checksum=2166136261
            for byte in body:checksum=((checksum^byte)*16777619)&0xffffffff
            return body+struct.pack('>I',checksum)
        prefs=drive/'prefs'
        if prefs.exists():prefs.rmdir() # Fail rather than remove any pre-existing contents.
        saves=drive/'Saved Games';saves.mkdir(exist_ok=True)
        for basename in ['Resource Dirty A','Resource Dirty B','Resource Permissions','Resource Mutation','Resource Isolation','Resource Map Edits','Resource Probe A','Resource Probe B','.async-probe','.opendf-probe','catalog-probe.bin','metadata-seed.bin','metadata-durable.bin','fork-probe.bin','fork-seed.bin','fork-durable.bin','iZx','i_x','iAx','i0x','i`x']:
            for suffix in ['', '.finfo','.finfo.new','.finfo.old','.rsrc','.rsrc.aitd-new','.rsrc.aitd-old']:(saves/(basename+suffix)).unlink(missing_ok=True)
        (drive/'data'/'Alone In The Dark.data').unlink(missing_ok=True)
        (saves/'fork-seed.bin').write_bytes(bytes.fromhex('12345678'))
        (saves/'fork-seed.bin.rsrc').write_bytes(bytes.fromhex('abcdef012345'))
        (saves/'metadata-seed.bin').write_bytes(b'')
        (saves/'metadata-seed.bin.finfo').write_bytes(metadata())
        for stem in ['stage-probe.rsrc','stage-created.rsrc','stage-stale.rsrc','stage-backup.rsrc']:
            for suffix in ['', '.aitd-new', '.aitd-old']:(drive/(stem+suffix)).unlink(missing_ok=True)
        (drive/'stage-probe.rsrc').write_bytes(b'OLD!')
        (drive/'stage-stale.rsrc').write_bytes(b'OLD!')
        (drive/'stage-backup.rsrc').write_bytes(b'OLD!')
        (drive/'stage-stale.rsrc.aitd-new').write_bytes(b'KEEP')
        (drive/'stage-backup.rsrc.aitd-old').write_bytes(b'KEEP')
        (drive/'write-probe.bin').write_bytes(bytes((i*37+(i>>8))&255 for i in range(200003)))
        (drive/'mutation-probe.bin').write_bytes(b'')
        (drive/'sharing-probe.bin').write_bytes(b'')
        locked=drive/'locked-probe.bin'
        if locked.exists():locked.chmod(0o644)
        locked.write_bytes(b'') # The native fixture applies DOS write protection.
else:
    log=(root/'amiga/.run/gdb-out.log').read_text()
    marker='PASS file-read: Line-A open/read/seek/EOF/position/close bytes=exact CCR=checked windows=10 DOS-reads=6 max=65536 cleanup=1 GetVol=WD/root/null-name FCB=index/exact/errors HVol=directory/state/errors WD=query/close/filter'
    if a.write:marker='PASS file-write: Line-A/backend bytes=exact windows=1039 writes=25 max=65536 flushes=19 EOF=17/3 cleanup=2 sharing=coherent permissions=0-4/locked volume=name/ref catalog=metadata/durable forks=independent installed=original index=HFS volparms=exact opendf=dot/aliases vinfo=native/catalog async=51/nested/user resources=406/exact permission-steps=59 mutation-faults=6 staging=9/exact'
    if a.status or re.search(r'FAIL|Error in sourced command file|Program received signal',log) or log.count(marker)!=1:
        raise SystemExit('FAIL file-read: missing completion or runner/observer failure')
    if a.write and (drive/'write-probe.bin').read_bytes()!=bytes((i*37+(i>>8))&255 for i in range(17)):
        raise SystemExit('FAIL file-write: host file length/bytes after close')
    if a.write and (drive/'mutation-probe.bin').read_bytes()!=bytes(((i*37+(i>>8))&255)^0xa5 for i in range(3)):
        raise SystemExit('FAIL file-write: dirty shutdown file length/bytes')
    if a.write and (drive/'sharing-probe.bin').read_bytes()!=bytes.fromhex('abcdef015678'):
        raise SystemExit('FAIL file-write: shared-writer host bytes after close')
    if a.write:
        if log.count('PASS resource dirty disk: exact EEEE/FFFF bodies, metadata and cleanup')!=1:raise SystemExit('FAIL file-write: dirty lifecycle disk acceptance missing')
        if log.count('PASS resource permissions disk: exact bodies/IDs/names/attributes/order, empty data fork, no transaction leftovers')!=3:raise SystemExit('FAIL file-write: permissions disk acceptance missing')
        for phase in ['mutation','isolation','rollback','map-selected','map-peers','map-final','map-rollback-empty','map-rollback-peers']:
            if log.count('PASS resource '+phase+' disk: exact bodies/IDs/names/attributes/order, empty data fork, no transaction leftovers')!=(2 if 'rollback' in phase else 1):raise SystemExit('FAIL file-write: resource mutation/isolation disk acceptance missing')
        if log.count('PASS resource files disk: six exact resources, names/IDs/order, independent data forks, no transaction leftovers')!=1:
            raise SystemExit('FAIL file-write: resource-file disk acceptance missing')
        for basename in ['Resource Dirty A','Resource Dirty B','Resource Permissions','Resource Mutation','Resource Isolation','Resource Map Edits','Resource Probe A','Resource Probe B']:
            for suffix in ['', '.rsrc','.finfo','.rsrc.aitd-new','.rsrc.aitd-old']:
                if (drive/'Saved Games'/(basename+suffix)).exists():raise SystemExit('FAIL file-write: resource-file scratch cleanup')
        from resource_fork import read_resource_fork
        payload=bytes((i*37+(i>>8))&255 for i in range(70003))
        for stem in ['stage-probe.rsrc','stage-created.rsrc']:
            path=drive/stem;resources=read_resource_fork(path)
            if path.stat().st_size!=70314 or len(resources)!=1 or (resources[0].kind,resources[0].rid,resources[0].attrs,resources[0].name,resources[0].body)!=(b'RSRC',128,0,'',payload):
                raise SystemExit('FAIL file-write: staged resource metadata/payload')
            for suffix in ['.aitd-new','.aitd-old']:
                if (drive/(stem+suffix)).exists():raise SystemExit('FAIL file-write: staging transaction left temporary/backup')
        for stem,sentinel,absent in [('stage-stale.rsrc','.aitd-new','.aitd-old'),('stage-backup.rsrc','.aitd-old','.aitd-new')]:
            if (drive/stem).read_bytes()!=b'OLD!' or (drive/(stem+sentinel)).read_bytes()!=b'KEEP' or (drive/(stem+absent)).exists():
                raise SystemExit('FAIL file-write: stale staging evidence changed')
        import struct
        saves=drive/'Saved Games';file=saves/'metadata-durable.bin'
        metadata=(saves/'metadata-durable.bin.finfo').read_bytes()
        checksum=2166136261
        for byte in metadata[:28]:checksum=((checksum^byte)*16777619)&0xffffffff
        if file.read_bytes()!=bytes.fromhex('12345678') or len(metadata)!=32 or metadata[:24]!=b'AFI1'+bytes.fromhex('54455354414954440400001200340000abcd0102') or struct.unpack('>I',metadata[28:])[0]!=checksum or struct.unpack('>I',metadata[24:28])[0] in [0,0xabcd0304]:
            raise SystemExit('FAIL file-write: durable metadata/data bytes')
        for basename in ['.opendf-probe','catalog-probe.bin','metadata-seed.bin']:
            if (saves/basename).exists() or (saves/(basename+'.finfo')).exists():raise SystemExit('FAIL file-write: delete left a fork/metadata companion')
        for basename in ['iZx','i_x','iAx','i0x','i`x']:
            if (saves/basename).exists() or (saves/(basename+'.finfo')).exists():raise SystemExit('FAIL file-write: index scratch cleanup')
        import hashlib
        if hashlib.sha256((drive/'data'/'Alone In The Dark').read_bytes()).hexdigest()!='b5848c063652b7223e3e350905b3a9054247b8536942753f435b1051a6352db2' or (drive/'data'/'Alone In The Dark.data').read_bytes()!=bytes.fromhex('12345678'):
            raise SystemExit('FAIL file-write: application fork separation/hash')
        for basename in ['.async-probe','.opendf-probe','fork-probe.bin','fork-seed.bin']:
            for suffix in ['', '.rsrc','.finfo']:
                if (saves/(basename+suffix)).exists():raise SystemExit('FAIL file-write: dual-fork deletion')
        if (saves/'fork-durable.bin').read_bytes()!=bytes.fromhex('12345678') or (saves/'fork-durable.bin.rsrc').read_bytes()!=bytes.fromhex('abcdef012345'):
            raise SystemExit('FAIL file-write: independent durable fork bytes')
        for suffix in ['', '.rsrc','.finfo','.uaem','.rsrc.uaem','.finfo.uaem']:(saves/('fork-durable.bin'+suffix)).unlink(missing_ok=True)
        for suffix in ['.data','.data.uaem']:(drive/'data'/('Alone In The Dark'+suffix)).unlink(missing_ok=True)
        prefs=drive/'prefs'
        if not prefs.is_dir() or any(prefs.iterdir()):raise SystemExit('FAIL file-write: optional prefs creation/deletion')
        prefs.rmdir()
        # Remove only this fixture's verified output, keeping production runs clean.
        for suffix in ['', '.finfo','.uaem','.finfo.uaem']:(saves/('metadata-durable.bin'+suffix)).unlink(missing_ok=True)
    print(marker)
