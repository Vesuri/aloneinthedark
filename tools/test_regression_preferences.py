#!/usr/bin/env python3
"""Preference/save isolation must preserve existing files and metadata on failure."""
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from types import SimpleNamespace
import regression_preferences
from regression_preferences import isolated_preferences


class Preferences(unittest.TestCase):
    def test_selected_diagnostic_directory_is_restored_on_failed_run(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); disk = root/'amiga/.run-audio/dh1'
            for name in ('prefs', 'Saved Games'):
                (disk/name).mkdir(parents=True)
                (disk/name/'kept').write_bytes(name.encode())
            ordinary = root/'amiga/.run/dh1/prefs'
            ordinary.mkdir(parents=True); (ordinary/'kept').write_bytes(b'ordinary')
            def run(args, env):
                self.assertEqual(env['DIAG_RUN_DIR'], '.run-audio')
                self.assertEqual(env['AITD_REGRESSION_PREFS_ISOLATED'], '1')
                self.assertFalse((disk/'prefs').exists())
                self.assertFalse((disk/'Saved Games').exists())
                self.assertEqual((ordinary/'kept').read_bytes(), b'ordinary')
                (disk/'prefs').mkdir(); (disk/'prefs/partial').write_bytes(b'fixture')
                return SimpleNamespace(returncode=17)
            with patch.object(regression_preferences, 'ROOT', root), \
                    patch.dict('os.environ', {'DIAG_RUN_DIR': '.run-audio'}), \
                    patch.object(regression_preferences.subprocess, 'run', side_effect=run):
                self.assertEqual(regression_preferences.main(), 17)
            for name in ('prefs', 'Saved Games'):
                self.assertEqual((disk/name/'kept').read_bytes(), name.encode())
            self.assertEqual((ordinary/'kept').read_bytes(), b'ordinary')

    def test_saves_and_directory_metadata_survive_failure(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); saves = root/'Saved Games'; saves.mkdir()
            data = saves/'SAVE0.ITD'; data.write_bytes(b'existing save')
            fork = saves/'SAVE0.ITD.rsrc'; fork.write_bytes(b'thumbnail')
            sidecar = root/'Saved Games.uaem'; sidecar.write_bytes(b'directory metadata')
            inode = data.stat().st_ino
            with self.assertRaisesRegex(RuntimeError, 'probe failed'):
                with isolated_preferences(saves, root/'archives', label='saves') as archive:
                    self.assertFalse(saves.exists())
                    self.assertFalse(sidecar.exists())
                    saves.mkdir(); (saves/'scratch').write_bytes(b'partial')
                    sidecar.write_bytes(b'fixture metadata')
                    raise RuntimeError('probe failed')
            self.assertEqual(data.read_bytes(), b'existing save')
            self.assertEqual(data.stat().st_ino, inode)
            self.assertEqual(fork.read_bytes(), b'thumbnail')
            self.assertEqual(sidecar.read_bytes(), b'directory metadata')
            self.assertEqual((archive/'fixture/scratch').read_bytes(), b'partial')
            self.assertEqual((archive/'fixture.uaem').read_bytes(), b'fixture metadata')

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
