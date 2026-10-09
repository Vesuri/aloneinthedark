#!/usr/bin/env python3
"""Reject mismatched states and incomplete runs before reading capture files."""
import unittest
from compare_frames import capture, check_pixels

ROWS = '\n'.join(f'INTRO_FRAME n={n} segment={segment} offset={offset:X} d0=0'
                 for n, segment, offset in [(1,5,0x1c94),(2,5,0x1f46),(3,13,0x2ed4),(4,4,0x5220)])
REFERENCE = ROWS+'\nPASS original intro frames=4\nExited via the debugger\n'
NATIVE = ROWS+'\nPASS full intro C2P frames=956 partial=840 failures=0 queued=956 presented=956 book=840/840 ticks=14970\n[Inferior 1 (Remote target) detached]\n'


class Checks(unittest.TestCase):
    def test_complete_states(self):
        capture(REFERENCE, 0, 'reference')
        capture(NATIVE, 0, 'native')

    def test_state_pairing_and_skipped_intro(self):
        for text in (REFERENCE.replace('offset=1F46','offset=1F48'),
                     REFERENCE.replace('offset=5220 d0=0','offset=5220 d0=1'),
                     REFERENCE.replace('n=2','n=1'), REFERENCE+ROWS+'\n'):
            with self.subTest(text=text), self.assertRaises(ValueError):
                capture(text, 0, 'reference')

    def test_native_coverage(self):
        for old, new in [('partial=840','partial=0'), ('failures=0','failures=1'),
                         ('presented=956','presented=955'), ('book=840/840','book=840/839')]:
            with self.subTest(old=old), self.assertRaises(ValueError):
                capture(NATIVE.replace(old,new), 0, 'native')

    def test_terminal_failure(self):
        for text, status in [(REFERENCE,124), (REFERENCE+'FAIL late error\n',0),
                             (REFERENCE.replace('Exited via the debugger',''),0)]:
            with self.subTest(status=status), self.assertRaises(ValueError):
                capture(text,status,'reference')

    def test_exact_caption_pixels(self):
        original = bytes([18])*307200
        check_pixels(original, original, (3,13,0x2ed4))
        # Even a single changed pixel in the former caption exception is rejected.
        for x,y in ((37,190),(20,20),(319,199)):
            damaged = bytearray(original)
            damaged[(y+150)*640+x+160] = 26
            with self.subTest(x=x,y=y), self.assertRaises(ValueError):
                check_pixels(damaged, original, (3,13,0x2ed4))


if __name__ == '__main__':
    unittest.main()
