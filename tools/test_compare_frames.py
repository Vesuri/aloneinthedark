#!/usr/bin/env python3
"""Reject mismatched states and incomplete runs before reading capture files."""
import unittest
from compare_frames import capture, explained_placeholder, placeholder_policy

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

    def test_placeholder_exception_requires_owned_ink(self):
        ink,areas=placeholder_policy(3)
        index=lambda x,y:(y+150)*640+x+160
        original=bytes([18])*307200
        native=bytearray(original)
        for x,y in ink:native[index(x,y)]=26
        explained_placeholder(3,native,original,list(ink))
        # A blank caption cannot pass as an explained font difference.
        with self.assertRaises(ValueError):
            explained_placeholder(3,original,original,[])
        # Nor can added ink, changed paper, or an out-of-caption mark.
        l,t,r,b=areas[0]
        clear=next((x,y) for y in range(t,b) for x in range(l,r) if (x,y) not in ink)
        for point,value in [(clear,26),(clear,19),((20,20),26)]:
            damaged=bytearray(native);damaged[index(*point)]=value
            with self.subTest(point=point,value=value), self.assertRaises(ValueError):
                explained_placeholder(3,damaged,original,list(ink)+[point])


if __name__ == '__main__':
    unittest.main()
