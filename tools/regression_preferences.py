#!/usr/bin/env python3
"""Run one native regression with isolated, recoverable preferences and saves."""
from contextlib import contextmanager
import os
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]


@contextmanager
def isolated_preferences(prefs, archive_parent, label='prefs'):
    if prefs.is_symlink() or (prefs.exists() and not prefs.is_dir()):
        raise ValueError('regression preferences must be a directory, not a link or file')
    archive_parent.mkdir(parents=True, exist_ok=True)
    metadata = prefs.with_name(prefs.name+'.uaem')
    if metadata.is_symlink() or (metadata.exists() and not metadata.is_file()):
        raise ValueError('regression directory metadata must be a regular file')
    archive = Path(tempfile.mkdtemp(prefix=f'regression-{label}-', dir=archive_parent))
    original = archive/'original'
    saved = prefs.exists()
    if saved:
        prefs.rename(original)
    saved_metadata = metadata.exists()
    if saved_metadata:
        metadata.rename(archive/'original.uaem')
    try:
        yield archive
    finally:
        # Keep incomplete probe output for diagnosis, including empty resource
        # forks left when a boot observer stops original startup early.
        if prefs.exists() or prefs.is_symlink():
            prefs.rename(archive/'fixture')
        if metadata.exists() or metadata.is_symlink():
            metadata.rename(archive/'fixture.uaem')
        if saved:
            prefs.parent.mkdir(parents=True, exist_ok=True)
            original.rename(prefs)
        if saved_metadata:
            (archive/'original.uaem').rename(metadata)


def main():
    env = os.environ.copy()
    env['AITD_REGRESSION_PREFS_ISOLATED'] = '1'
    run = os.environ.get('DIAG_RUN_DIR', '.run')
    import re
    if not re.fullmatch(r'\.run(?:-[a-z0-9][a-z0-9_-]*)?', run):
        raise ValueError('invalid diagnostic directory')
    prefs = ROOT/'amiga'/run/'dh1/prefs'
    saves = ROOT/'amiga'/run/'dh1/Saved Games'
    with isolated_preferences(prefs, ROOT/'amiga/.run') as archive, \
            isolated_preferences(saves, ROOT/'amiga/.run', label='saves') as save_archive:
        print(f'Regression preferences isolated; fixture archive: {archive}', flush=True)
        print(f'Regression saves isolated; fixture archive: {save_archive}', flush=True)
        result = subprocess.run(['bash', str(ROOT/'amiga/regression.sh'), *sys.argv[1:]], env=env)
    print('Regression preferences and saves restored.', flush=True)
    return result.returncode


if __name__ == '__main__':
    raise SystemExit(main())
