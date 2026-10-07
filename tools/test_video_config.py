#!/usr/bin/env python3
"""Check named PAL/NTSC emulator configurations without launching an emulator."""
import os
from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]


class Checks(unittest.TestCase):
    def config(self, **values):
        env = os.environ.copy()
        for name in ('AMIGA_CONFIG', 'AMIGA_MODEL', 'AMIGA_VIDEO', 'EXTRA_ARGS', 'CHIP_MEMORY', 'FAST_MEMORY', 'AMIGA_FAST_KB'):
            env.pop(name, None)
        env.update(values)
        return subprocess.run(['bash', '-c', 'set -e\n. amiga/config.sh\nprintf "%s\\n" "${AITD_MACHINE_ARGS[@]}"'],
                              cwd=ROOT, env=env, text=True, capture_output=True)

    def test_video_and_machine_combinations(self):
        for model in ('a1200-020', 'a4000-020', 'a4000-030', 'a4000-030-reference'):
            for video, ntsc, clock in (('PAL', 0, 14187580), ('NTSC', 1, 14318180)):
                with self.subTest(model=model, video=video):
                    result = self.config(AMIGA_CONFIG=model, AMIGA_VIDEO=video)
                    self.assertEqual(result.returncode, 0, result.stderr)
                    args = result.stdout.splitlines()
                    self.assertEqual(sum(x.startswith('--ntsc_mode=') for x in args), 1)
                    self.assertIn(f'--ntsc_mode={ntsc}', args)
                    self.assertIn('--uae_ntsc='+('true' if ntsc else 'false'), args)
                    frequency = 15667200 if model == 'a4000-030-reference' else clock if model == 'a1200-020' else 0
                    self.assertIn(f'--uae_cpu_frequency={frequency}', args)
                    self.assertIn('--cpu='+('68030' if model.startswith('a4000-030') else '68EC020'), args)
                    self.assertIn('--uae_cpu_speed='+('real' if frequency else 'max'), args)
                    self.assertIn('--uae_cpu_cycle_exact='+('true' if frequency else 'false'), args)

    def test_explicit_memory_variants(self):
        for size in ('2048','4096','8192'):
            result=self.config(AMIGA_FAST_KB=size)
            self.assertEqual(result.returncode,0,result.stderr)
            self.assertIn('--fast_memory='+size,result.stdout.splitlines())
            self.assertIn('--cpu=68030',result.stdout.splitlines())
            self.assertIn('--uae_cpu_frequency=15667200',result.stdout.splitlines())
        for size in ('0','6144','-1','garbage'):
            self.assertNotEqual(self.config(AMIGA_FAST_KB=size).returncode,0)

    def test_default_and_invalid_video(self):
        self.assertIn('--ntsc_mode=0', self.config().stdout.splitlines())
        self.assertIn('--cpu=68030', self.config().stdout.splitlines())
        self.assertIn('--uae_cpu_frequency=15667200', self.config().stdout.splitlines())
        self.assertNotEqual(self.config(AMIGA_VIDEO='SECAM').returncode, 0)

    def test_independent_video_override_rejected(self):
        for override in ('--ntsc_mode=1', '--uae_ntsc=true'):
            self.assertNotEqual(self.config(EXTRA_ARGS=override).returncode, 0)


if __name__ == '__main__':
    unittest.main()
