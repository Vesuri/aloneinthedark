import hashlib
from pathlib import Path
import local_temp as tempfile
import unittest
from unittest.mock import patch
import install_layout as layout

class LayoutTests(unittest.TestCase):
    def test_paths(self):
        self.assertEqual(layout.installed_path('ListBod2.PAK'),Path('Alone Data/ListBod2.PAK'))
        for name in ('Alone Data/ListBody.PAK','Quick Reference','Alone In The Dark'):
            self.assertEqual(layout.installed_path(name),Path(name))
    def test_migration_is_exact_and_repeatable(self):
        data=b'original body fixture';info=b'original metadata fixture'
        with tempfile.TemporaryDirectory() as directory,patch.object(layout,'BODY_SHA',hashlib.sha256(data).hexdigest()):
            root=Path(directory);body=root/layout.BODY;metadata=root/(layout.BODY+'.finfo')
            body.write_bytes(data);metadata.write_bytes(b'user metadata')
            with self.assertRaises(ValueError):layout.retire_legacy(root,data,info)
            self.assertEqual(body.read_bytes(),data)
            self.assertEqual(metadata.read_bytes(),b'user metadata')
            metadata.write_bytes(info)
            companion=root/(layout.BODY+'.rsrc');companion.write_bytes(b'user resource')
            with self.assertRaises(ValueError):layout.retire_legacy(root,data,info)
            self.assertTrue(body.exists());self.assertTrue(metadata.exists());companion.unlink()
            with self.assertRaises(ValueError):layout.retire_legacy(root,b'wrong original',info)
            layout.retire_legacy(root,data,info);layout.retire_legacy(root,data,info)
            self.assertFalse(body.exists());self.assertFalse(metadata.exists())
            other=root/'other';other.write_bytes(data);body.symlink_to(other)
            with self.assertRaises(ValueError):layout.retire_legacy(root,data,info)
            self.assertEqual(other.read_bytes(),data)
            other.unlink()
            with self.assertRaises(ValueError):layout.retire_legacy(root,data,info)

if __name__=='__main__':unittest.main()
