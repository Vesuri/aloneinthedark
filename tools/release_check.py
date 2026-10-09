#!/usr/bin/env python3
"""Build twice from clean state, verify native boot and audit deterministic LH5 output."""
import argparse
import hashlib
import os
from pathlib import Path
import subprocess
import local_temp as tempfile

ROOT=Path(__file__).resolve().parents[1]
def run(*command, **kwargs):
    subprocess.run(command,cwd=ROOT,check=True,**kwargs)
def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()
def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--package-only',action='store_true',help='build and package once; skip the full release gate')
    args=p.parse_args()
    logs=ROOT/'tmp/release-check';logs.mkdir(parents=True,exist_ok=True)
    # Enforce production defaults even when invoked from a parent make.
    os.environ.pop('MAKEFLAGS',None);os.environ.pop('MFLAGS',None);os.environ.pop('MAKEOVERRIDES',None)
    if not args.package_only:
        with (logs/'host-tests.log').open('w') as out:
            run('make','host-tests',stdout=out,stderr=subprocess.STDOUT)
        print('PASS: host test suite',flush=True)
        run('make','installer-test')
    run('make','installer','slave')
    executable=ROOT/'amiga/out/Alone.exe'
    first=None
    for iteration in range(1 if args.package_only else 2):
        with (logs/f'build-{iteration}.log').open('w') as out:
            run('make','-C','amiga','clean',stdout=out,stderr=subprocess.STDOUT)
            run('make','-C','amiga','-j8',stdout=out,stderr=subprocess.STDOUT)
        current=digest(executable)
        if first is not None: assert current==first,'production executable is not deterministic'
        first=current
    from build_receipt import require_production
    require_production(executable)
    print('PASS: clean production executable '+first,flush=True)
    if not args.package_only:
        env=dict(os.environ,DIAG_RUN_DIR='.run-release',GDBSCRIPT='boot.gdb')
        with (logs/'native-boot.log').open('w') as out:
            run('bash','amiga/diag_run.sh','180',env=env,stdout=out,stderr=subprocess.STDOUT)
        run('python3','tools/regression_result.py','amiga/.run-release/gdb-out.log','--status','0')
        run('python3','tools/test_whdload.py','--mode','timed','--ticks','6000','--seconds','180')
    run('python3','tools/package_release.py',str(executable),'dist')
    archive=ROOT/'dist'/('AloneInTheDark-'+(ROOT/'VERSION').read_text().strip()+'.lha')
    run('python3','tools/check_release.py',str(archive))
    if not args.package_only:
        run('python3','tools/test_release.py',str(archive))
        with tempfile.TemporaryDirectory(prefix='aitd-release-') as folder:
            run('python3','tools/package_release.py',str(executable),folder)
            assert archive.read_bytes()==(Path(folder)/archive.name).read_bytes(),'archive is not deterministic'
        print('PASS: independently repeated archive is byte-identical',flush=True)
    print(f'RELEASE {archive.name} sha256={digest(archive)}',flush=True)
if __name__=='__main__': main()
