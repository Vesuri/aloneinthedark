#!/usr/bin/env python3
"""Host fixtures for source-metadata validation, including timezone independence."""
import struct
import unittest
from installed_metadata import from_entry, encode
class Tests(unittest.TestCase):
    def fixture(self):
        header=bytearray(112);header[1]=13;header[2]=4;header[3:7]=b'Test'
        finder=bytes.fromhex('44415441414954440100001200340000')
        header[66:76]=finder[:10]
        struct.pack_into('>IIIIII',header,76,0xa701add8,0xaa77d6fb,0,4,0,4)
        entry=dict(XADDataOffset=134,XADFileName='Dir/Test',XADFileSize=4,XADDataLength=4,StuffItCompressionMethod=13,
                   XADFileType=0x44415441,XADFileCreator=0x41495444,XADFinderFlags=0x100)
        return bytes(22)+header+b'abcd',entry,finder
    def test_exact(self):
        archive,entry,finder=self.fixture();record=from_entry(archive,entry,finder)
        self.assertEqual(record,encode(finder,0xa701add8,0xaa77d6fb))
        # Displayed lsar dates are deliberately irrelevant: original integers win.
        entry['XADCreationDate']='1904-01-01 00:00:00 +0000'
        self.assertEqual(record,from_entry(archive,entry,finder))
    def test_reject(self):
        archive,entry,finder=self.fixture()
        for key,value in [('XADDataOffset',133),('XADFileName','Else'),('XADFileSize',5),('XADDataLength',5),('StuffItCompressionMethod',0),('XADFileType',0),('XADFinderFlags',0)]:
            changed=dict(entry);changed[key]=value
            with self.subTest(key=key),self.assertRaises(ValueError):from_entry(archive,changed,finder)
        with self.assertRaises(ValueError):from_entry(archive,entry,bytes(16))
        with self.assertRaises(ValueError):from_entry(archive[:-1],entry,finder)
        malformed=bytearray(archive);struct.pack_into('>I',malformed,22+84,1)
        with self.assertRaises(ValueError):from_entry(malformed,entry,finder)
if __name__=='__main__':unittest.main()
