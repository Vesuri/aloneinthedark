#!/usr/bin/env python3
"""Reject corrupt/incomplete/extra release members and diagnostic build receipts."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
from build_receipt import PRODUCTION_DEFINES, require_production
from package_release import member, PREFIX

root=Path(__file__).resolve().parents[1]
archive=Path(sys.argv[1]).resolve();raw=archive.read_bytes()
with tempfile.TemporaryDirectory(prefix='aitd-release-reject-') as directory:
    work=Path(directory)
    broken_header=bytearray(raw);broken_header[1]^=1
    body=bytearray(raw);body[2+body[0]-1]^=1
    body[1]=sum(body[2:2+body[0]])&255  # preserve header checksum, break payload CRC
    cases={
        'header':bytes(broken_header), 'crc':bytes(body), 'truncated':raw[:-3],
        'extra':raw[:-1]+member(PREFIX+'/unexpected',b'not a release file'*100)+b'\0',
    }
    for name,data in cases.items():
        path=work/(name+'.lha');path.write_bytes(data)
        result=subprocess.run([sys.executable,str(root/'tools/check_release.py'),str(path)],capture_output=True)
        assert result.returncode != 0 and b'AssertionError' in result.stderr,(name,result.stderr)
    exe=work/'Alone';exe.write_bytes(b'fixture')
    receipt={'sha256':hashlib.sha256(exe.read_bytes()).hexdigest(),'defines':' '.join(sorted(PRODUCTION_DEFINES)),'probes':''}
    path=Path(str(exe)+'.build.json');path.write_text(json.dumps(receipt));require_production(exe)
    for extra,probes in ((' -DAITD_INGAME',''),(' -DAITD_INTRO_SKIP',''),('','1')):
        invalid=dict(receipt,defines=receipt['defines']+extra,probes=probes);path.write_text(json.dumps(invalid))
        try: require_production(exe)
        except ValueError: pass
        else: raise AssertionError('diagnostic receipt accepted')
    path.write_text(json.dumps(receipt));exe.write_bytes(b'changed build')
    try: require_production(exe)
    except ValueError: pass
    else: raise AssertionError('stale receipt accepted')
print('PASS: release rejects header/CRC/truncation/extra members and diagnostic/stale build receipts')
