#!/usr/bin/env python3
"""Classify the measured startup fixture without modifying its preferences."""
import argparse
from pathlib import Path
import tempfile
import struct
import unittest
from resource_fork import read_resource_fork

DEFAULT=bytes.fromhex('ff800001010101010000')
def state(folder):
    data=folder/'Alone Prefs';fork=folder/'Alone Prefs.rsrc';info=folder/'Alone Prefs.finfo'
    if not any(p.exists() or p.is_symlink() for p in (data,fork,info)):return False
    if any(p.is_symlink() or not p.is_file() for p in (data,fork,info)) or data.stat().st_size!=0:
        raise ValueError('incomplete or nonregular Alone Prefs fixture')
    rows=read_resource_fork(fork)
    if len(rows)!=1 or (rows[0].kind,rows[0].rid,rows[0].attrs,rows[0].name,rows[0].body)!=(b'PREF',128,0,'',DEFAULT):
        raise ValueError('unmeasured Alone Prefs contents; preserve them and use an isolated fixture')
    return True

def script(existing):
    windows,entered,completed=(34,42,42) if existing else (60,50,50)
    return (f'set $startup_catalog={42+int(existing)}\nset $startup_windows={windows}\nset $startup_entered={entered}\nset $startup_completed={completed}\n'
            f'printf "STARTUP_PREFS existing={int(existing)} windows={windows} services={entered}/{completed}\\n"\n')

class Checks(unittest.TestCase):
    def test_missing_partial_and_symlink(self):
        with tempfile.TemporaryDirectory() as work:
            folder=Path(work);self.assertFalse(state(folder))
            (folder/'Alone Prefs').write_bytes(b'')
            with self.assertRaises(ValueError):state(folder)
            (folder/'Alone Prefs').unlink();(folder/'Alone Prefs').symlink_to(folder/'absent')
            with self.assertRaises(ValueError):state(folder)
    def test_existing_and_changed(self):
        with tempfile.TemporaryDirectory() as work:
            folder=Path(work);(folder/'Alone Prefs').write_bytes(b'');(folder/'Alone Prefs.finfo').write_bytes(b'fixture')
            header=struct.pack('>IIII',256,270,14,50)
            resource_map=header+bytes(8)+struct.pack('>HHH4sHHhHII',28,50,0,b'PREF',0,10,128,0xffff,0,0)
            raw=header+bytes(240)+struct.pack('>I',10)+DEFAULT+resource_map
            (folder/'Alone Prefs.rsrc').write_bytes(raw);self.assertTrue(state(folder))
            bad=bytearray(raw);bad[260]^=1;(folder/'Alone Prefs.rsrc').write_bytes(bad)
            with self.assertRaises(ValueError):state(folder)
            (folder/'Alone Prefs.rsrc').write_bytes(raw[:-1])
            with self.assertRaises(ValueError):state(folder)
    def test_exact_modes(self):
        self.assertIn('windows=60 services=50/50',script(False))
        self.assertIn('windows=34 services=42/42',script(True))

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--folder',type=Path);p.add_argument('--gdb',type=Path);p.add_argument('--selftest',action='store_true');a=p.parse_args()
    if a.selftest:raise SystemExit(not unittest.TextTestRunner().run(unittest.defaultTestLoader.loadTestsFromTestCase(Checks)).wasSuccessful())
    try:
        # Remove stale observer state before inspecting a potentially unsupported fixture.
        a.gdb.unlink(missing_ok=True);a.gdb.write_text(script(state(a.folder)))
    except (ValueError,OSError,AttributeError) as error:raise SystemExit('FAIL startup preferences: '+str(error))
