#!/usr/bin/env python3
"""Bounded native catalog fixtures: retain ordinary files, reject unknown layouts.

Run after production boot has built the executable, with amiga/env.sh sourced.
Only uniquely named scratch paths created by this run are removed.
"""
import os
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parent.parent
assets = root/'amiga/.run/dh1/data'
name = assets/'namespace-owned-probe'
companion = assets/'namespace-owned-probe.rsrc'
if name.exists() or companion.exists():
    raise SystemExit('FAIL namespace: scratch already exists; inspect before retrying')
assets.mkdir(parents=True, exist_ok=True)
env = dict(os.environ, GDB_ENTRY='aitdBuildFileCatalog',
           GDBSCRIPT='file_namespace.gdb', EXTRA_ARGS='--warp_mode=1', GDBTAIL='30')
for kind, expected in [
    ('ordinary', 'NAMESPACE catalog=complete entries=43'),
    ('directory', 'NAMESPACE stop=CATALOG / UNSUPPORTED DIRECTORY'),
    ('orphan', 'NAMESPACE stop=CATALOG / ORPHAN COMPANION')]:
    path = companion if kind == 'orphan' else name
    if kind == 'directory': path.mkdir()
    else: path.write_bytes(b'owned namespace fixture')
    try:
        result = subprocess.run(['./diag_run.sh', '60'], cwd=root/'amiga', env=env,
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        (root/('tmp/m2-namespace-'+kind+'.log')).write_text(result.stdout)
        if result.returncode or result.stdout.count(expected) != 1 or 'FAIL ' in result.stdout:
            raise SystemExit('FAIL namespace '+kind+': runner/result; see tmp log')
        print('PASS namespace '+kind+': '+expected, flush=True)
    finally:
        if kind == 'directory': path.rmdir()
        else: path.unlink()
        Path(str(path)+'.uaem').unlink(missing_ok=True)
