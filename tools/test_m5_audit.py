#!/usr/bin/env python3
"""Reject missing evidence, timer stalls, late notes and corrupted stack guards."""
import struct,tempfile,unittest
from pathlib import Path
from check_m5_audit import check

LOG="""M5_STARTUP stage=5 tick=100
M5_LOAD stage=5 tick=200
M5_MACHINE clockHz=709379 cpuFlags=7 chip=2096128 fast=8388608 initialChip=2000000 initialFast=7000000
M5_MEMORY allocations=300 failures=0 errors=0 appZone=2000000 systemZone=304 minFast=3800000 minChip=1400000
M5_IRQ calls=1000 events=400 eventLate=0 maxClocks=4000 minInterval=11000 maxInterval=12500 maxLateEClocks=600
M5_GAP maxClocks=7000000
M5_NOTES count=1200 late=0 maxLate=0 activeGap=700000 activeTicks=60 song=137
PASS native continuous firstfloor circuit
[Inferior 1 (Remote target) detached]
"""
class Audit(unittest.TestCase):
 def setUp(self):
  self.tmp=tempfile.TemporaryDirectory();self.folder=Path(self.tmp.name)
  for name in ('music','deferred'):(self.folder/(name+'-stack.bin')).write_bytes(bytes([0xa5])*7800+bytes(392))
  (self.folder/'note-log.bin').write_bytes(b''.join(struct.pack('>5I',137,60,i,i,20) for i in range(1024)))
 def tearDown(self):self.tmp.cleanup()
 def test_complete_ring(self):self.assertEqual(check(LOG,self.folder,0,'68030',8192,'PASS native continuous firstfloor circuit')['stack_headroom_bytes']['music'],7800)
 def test_rejections(self):
  for old,new in [('late=0','late=1'),('maxInterval=12500','maxInterval=40000'),('failures=0','failures=1'),('errors=0','errors=1'),('activeTicks=60','activeTicks=0'),('cpuFlags=7','cpuFlags=3'),('[Inferior 1 (Remote target) detached]','')]:
   with self.subTest(old=old),self.assertRaises(ValueError):check(LOG.replace(old,new),self.folder,0,'68030',8192,'PASS native continuous firstfloor circuit')
 def test_event_disagrees(self):
  p=self.folder/'note-log.bin';data=bytearray(p.read_bytes());struct.pack_into('>I',data,12,1);p.write_bytes(data)
  with self.assertRaises(ValueError):check(LOG,self.folder,0,'68030',8192,'PASS native continuous firstfloor circuit')
 def test_stack_guard(self):
  (self.folder/'music-stack.bin').write_bytes(bytes(8192))
  with self.assertRaises(ValueError):check(LOG,self.folder,0,'68030',8192,'PASS native continuous firstfloor circuit')
 def test_failed_runner(self):
  with self.assertRaises(ValueError):check(LOG,self.folder,124,'68030',8192,'PASS native continuous firstfloor circuit')
if __name__=='__main__':unittest.main()
