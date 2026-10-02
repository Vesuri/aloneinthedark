#!/usr/bin/env python3
"""Preference isolation must survive successful and failed native probes."""
from pathlib import Path
import tempfile
import unittest
from regression_preferences import isolated_preferences


class Preferences(unittest.TestCase):
    def test_existing_preferences_and_metadata_survive(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); prefs = root/'prefs'; prefs.mkdir()
            data = prefs/'Alone Prefs.rsrc'; data.write_bytes(b'original fork')
            data.chmod(0o440)
            metadata = prefs/'Alone Prefs.rsrc.uaem'; metadata.write_bytes(b'metadata')
            inode = data.stat().st_ino
            with isolated_preferences(prefs, root/'archives') as archive:
                self.assertFalse(prefs.exists())
                prefs.mkdir(); (prefs/'Alone Prefs.rsrc').write_bytes(b'')
            self.assertEqual(data.read_bytes(), b'original fork')
            self.assertEqual(metadata.read_bytes(), b'metadata')
            self.assertEqual(data.stat().st_ino, inode)
            self.assertEqual(data.stat().st_mode & 0o777, 0o440)
            self.assertEqual((archive/'fixture/Alone Prefs.rsrc').read_bytes(), b'')

    def test_restore_after_failure(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); prefs = root/'prefs'; prefs.mkdir()
            (prefs/'kept').write_bytes(b'keep')
            with self.assertRaisesRegex(RuntimeError, 'probe failed'):
                with isolated_preferences(prefs, root/'archives') as archive:
                    prefs.mkdir(); (prefs/'partial').write_bytes(b'partial')
                    raise RuntimeError('probe failed')
            self.assertEqual((prefs/'kept').read_bytes(), b'keep')
            self.assertEqual((archive/'fixture/partial').read_bytes(), b'partial')

    def test_initially_absent_preferences_remain_absent(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); prefs = root/'prefs'
            for create in (False, True):
                with isolated_preferences(prefs, root/'archives'):
                    if create:
                        prefs.mkdir(); (prefs/'partial').write_bytes(b'')
                self.assertFalse(prefs.exists())

    def test_reject_existing_file_or_link_without_changes(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); prefs = root/'prefs'; prefs.write_bytes(b'keep')
            with self.assertRaises(ValueError):
                with isolated_preferences(prefs, root/'archives'): pass
            self.assertEqual(prefs.read_bytes(), b'keep')
            target = root/'real'; target.mkdir(); prefs.unlink(); prefs.symlink_to(target)
            with self.assertRaises(ValueError):
                with isolated_preferences(prefs, root/'archives'): pass
            self.assertTrue(prefs.is_symlink())
            self.assertTrue(target.is_dir())


if __name__ == '__main__':
    unittest.main()
