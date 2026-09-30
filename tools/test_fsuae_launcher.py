#!/usr/bin/env python3
"""Verify debugger-port selection and refusal without starting or killing a process."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[1]
class Checks(unittest.TestCase):
    def run_launcher(self,port=None,holder=''):
        with tempfile.TemporaryDirectory(prefix='aitd-launcher-') as work:
            helper=Path(work)/'shared.sh'
            helper.write_text('fsuae_stop_previous() { echo OWNED_PROCESS_CHECK; }\n')
            env=os.environ.copy();env.pop('DEBUG_PORT',None)
            env.update(FSUAE_COMMON=str(helper),MOCK_HOLDER=holder)
            if port is not None:env['DEBUG_PORT']=port
            script='lsof() { printf "%s" "$MOCK_HOLDER"; }; kill() { echo FORBIDDEN_KILL; }; . ./fsuae.sh; fsuae_claim_port'
            return subprocess.run(['bash','-c',script],cwd=ROOT/'amiga',env=env,capture_output=True,text=True)
    def test_default_and_override(self):
        for port,want in [(None,'24377'),('24378','24378')]:
            with self.subTest(port=port):
                result=self.run_launcher(port)
                self.assertEqual(result.returncode,0,result.stderr)
                self.assertIn('gdb stub port: '+want,result.stdout)
                self.assertEqual(result.stdout.count('OWNED_PROCESS_CHECK'),1)
    def test_busy_port_does_not_kill_listener(self):
        result=self.run_launcher(holder='44215')
        self.assertEqual(result.returncode,1)
        self.assertIn('DEBUG PORT BUSY: 24377 (pid 44215)',result.stderr)
        self.assertNotIn('FORBIDDEN_KILL',result.stdout+result.stderr)
        self.assertNotIn('gdb stub port:',result.stdout)
if __name__=='__main__':unittest.main()
