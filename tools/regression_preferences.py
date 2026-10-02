#!/usr/bin/env python3
"""Run one native regression with isolated, recoverable preferences."""
from contextlib import contextmanager
import os
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]


@contextmanager
def isolated_preferences(prefs, archive_parent):
    if prefs.is_symlink() or (prefs.exists() and not prefs.is_dir()):
        raise ValueError('regression preferences must be a directory, not a link or file')
    archive_parent.mkdir(parents=True, exist_ok=True)
    archive = Path(tempfile.mkdtemp(prefix='regression-prefs-', dir=archive_parent))
    original = archive/'original'
    saved = prefs.exists()
    if saved:
        prefs.rename(original)
    try:
        yield archive
    finally:
        # Keep incomplete probe output for diagnosis, including empty resource
        # forks left when a boot observer stops original startup early.
        if prefs.exists() or prefs.is_symlink():
            prefs.rename(archive/'fixture')
        if saved:
            prefs.parent.mkdir(parents=True, exist_ok=True)
            original.rename(prefs)


def main():
    env = os.environ.copy()
    env['AITD_REGRESSION_PREFS_ISOLATED'] = '1'
    prefs = ROOT/'amiga/.run/dh1/prefs'
    with isolated_preferences(prefs, ROOT/'amiga/.run') as archive:
        print(f'Regression preferences isolated; fixture archive: {archive}', flush=True)
        result = subprocess.run(['bash', str(ROOT/'amiga/regression.sh'), *sys.argv[1:]], env=env)
    print('Regression preferences restored.', flush=True)
    return result.returncode


if __name__ == '__main__':
    raise SystemExit(main())
