#!/usr/bin/env python3
import tempfile,unittest
from pathlib import Path
from summarize_gameplay_profile import summarize
class Profile(unittest.TestCase):
 def setUp(self):
  self.tmp=tempfile.TemporaryDirectory();self.p=Path(self.tmp.name)
  (self.p/'segments.txt').write_text('SEG 0 Dark 1000 2000\n')
  (self.p/'counters.txt').write_text('fields=100 presented=20 scenes=20 ticks=120\n')
  (self.p/'samples.txt').write_text('S 1100 0 9000 3 2\n  #0  0x1100 in ?? ()\nS 3000 0 9000 3 2\n  #0  c2p1x1_8_c5_gen ()\n  #1  AitdScreen::presentMacFrame ()\n')
 def tearDown(self):self.tmp.cleanup()
 def test_exclusive_total(self):
  p=summarize(self.p);self.assertEqual(p['samples'],2);self.assertEqual(p['ms_per_frame'],100)
  counts={x['phase']:x['samples'] for x in p['phases']}
  self.assertEqual(counts['Original game code'],1);self.assertEqual(counts['C2P'],1)
  self.assertEqual(sum(counts.values()),2);self.assertEqual(sum(x['ms_per_frame'] for x in p['phases']),100)
 def test_room_change_rejected(self):
  p=self.p/'samples.txt';p.write_text(p.read_text().replace('3 2','4 2'))
  with self.assertRaises(ValueError):summarize(self.p)
 def test_incomplete_interval_rejected(self):
  (self.p/'counters.txt').write_text('start [1,2,3,4]\n')
  with self.assertRaises(ValueError):summarize(self.p)
if __name__=='__main__':unittest.main()
