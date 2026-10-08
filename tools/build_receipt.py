#!/usr/bin/env python3
"""Bind packaging eligibility to the bytes and feature flags of the linked build."""
import hashlib
import json
from pathlib import Path
import sys

PRODUCTION_DEFINES = {'-DAITD_MAPPED_COPY_ASM', '-DAITD_CIA_MUSIC', '-DAITD_SCENE_FRAME_BATCH'}

def require_production(executable):
    receipt = json.loads(Path(str(executable)+'.build.json').read_text())
    if receipt['sha256'] != hashlib.sha256(executable.read_bytes()).hexdigest():
        raise ValueError('Executable differs from its build receipt; clean-build production first')
    if set(receipt['defines'].split()) != PRODUCTION_DEFINES or receipt['probes']:
        raise ValueError('Refusing diagnostic or non-production feature flags')

if __name__ == '__main__':
    executable=Path(sys.argv[1])
    Path(str(executable)+'.build.json').write_text(json.dumps({
        'sha256':hashlib.sha256(executable.read_bytes()).hexdigest(),
        'defines':sys.argv[2], 'probes':sys.argv[3],
    },sort_keys=True)+'\n')
