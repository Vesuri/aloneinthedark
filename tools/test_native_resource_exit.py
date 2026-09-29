#!/usr/bin/env python3
"""Exit evidence must reject timeout, incomplete, duplicated and wrong-phase logs."""
import unittest
from check_native_resource_exit import validate_log

class ExitEvidence(unittest.TestCase):
    def test_phase_evidence(self):
        for phase in (1,2,3):
            text=(f'PASS resource-exit phase={phase} original-return=1 restored=1 main-result=0 crt-return=1'
                  if phase!=3 else 'PASS resource-exit fault stop=RESOURCE EXIT IO ERROR resident=EXIT service=active stream=open')
            validate_log(text,0,phase)
            for bad,status in ((text,124),(text,1),(text,None),('',0),(text*2,0),
                               (text+'\nDIAG / GDB TIMEOUT',0),(text+'\nFAIL cleanup',0),
                               (text+'\nError in sourced command file',0)):
                with self.subTest(phase=phase,status=status,bad=bad),self.assertRaises(ValueError):
                    validate_log(bad,status,phase)
            with self.assertRaises(ValueError):validate_log(text,0,phase%3+1)
            if phase==3:
                with self.assertRaises(ValueError):validate_log(text.replace('RESOURCE EXIT IO ERROR','UNEXPECTED STOP'),0,phase)

if __name__=='__main__':unittest.main()
