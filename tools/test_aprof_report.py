#!/usr/bin/env python3
import struct
import unittest
from aprof_report import bucket, call_tree, link_starts, parse_jump_table, parse_log, parse_profile, trap_name

PROFILE = '''AITDPROF 1
units 1000
vsyncs 2
CYCLE_UNIT 512
colorclock_hz 3546895
cacr 2001
gap 10
unmatched_rts 0
unmatched_rte 0
overflow 0
P 1000 600 3 0 0
P 2000 300 2 120 4
N 0 0 0 0 0 0
N 1 0 1000 0 100 1
N 2 1 a000a9ec 10 500 2
N 3 2 1000 0 50 1
'''


class AprofReport(unittest.TestCase):
    def test_profile_fields(self):
        header, pcs, nodes = parse_profile(PROFILE)
        self.assertEqual(header['cacr'], 0x2001)
        self.assertEqual(pcs[0x2000], (300, 2, 120, 4))
        self.assertEqual(nodes[2], (1, 0xA000A9EC, 10, 500, 2))

    def test_rejects_other_formats(self):
        with self.assertRaises(ValueError):
            parse_profile('AITDPROF 2\nunits 1\n')
        with self.assertRaises(ValueError):
            parse_profile('AITDPROF 1\nunits 1\n')

    def test_inclusive_tree(self):
        _, _, nodes = parse_profile(PROFILE)
        children, order, inclusive = call_tree(nodes)
        self.assertEqual(order[0], 0)
        self.assertEqual(inclusive[3], 50)
        self.assertEqual(inclusive[2], 550)
        self.assertEqual(inclusive[0], 650)

    def test_log_interval_and_segments(self):
        log = parse_log('CONFIG a4000-030-reference model=A4000 cpu=68030 frequency_hz=15667200 chipset=AGA\n'
                        'SEG 6 Dark3 3adeb0 3b26f6\nSEG 4 Dark 32a0d0 330cfc\nA5 6513d8\n'
                        ' [0]      0x21c488->0x25ffc8 at 0x00002000: .text ALLOC LOAD\n'
                        'DELTA fields=516 frames=100 steps=100\nROOM start=0/0 stop=0/0\n'
                        'SEGSTOP 4 Dark 32a0d0 330cfc\n')
        self.assertEqual(log['segs'][0], (0x32A0D0, 0x330CFC, 'Dark'))
        self.assertEqual(log['stopsegs'], [(0x32A0D0, 0x330CFC, 'Dark')])
        self.assertEqual(log['sections']['.text'], (0x21C488, 0x25FFC8))
        self.assertEqual((log['a5'], log['delta'], log['hz']), (0x6513D8, (516, 100, 100), 15667200))

    def test_loaded_jump_table_entries_only(self):
        # Entry 0 loaded (seg, JMP abs.L); entry 1 still in its unloaded _LoadSeg form.
        data = struct.pack('>HHI', 6, 0x4EF9, 0x3AFC00) + struct.pack('>HHHH', 0x10, 0x3F3C, 6, 0xA9F0)
        self.assertEqual(parse_jump_table(data, 0x6513D8), {0x6513D8 + 34: (0, 0x3AFC00)})

    def test_link_prologues_after_header(self):
        code = bytes([0x4E, 0x56, 0, 0, 0x4E, 0x56, 0, 0, 0x4E, 0x75, 0x4E, 0x56])
        self.assertEqual(link_starts(code), {4, 10})

    def test_trap_names_ignore_flag_bits(self):
        traps = {0xA9EC: 'CopyBits', 0xA02E: 'BlockMove'}
        self.assertEqual(trap_name(0xA9EC, traps), 'CopyBits')
        self.assertEqual(trap_name(0xADEC, traps), 'CopyBits')  # auto-pop
        self.assertEqual(trap_name(0xA22E, traps), 'BlockMove')  # OS flag bits
        self.assertEqual(trap_name(0xA123, traps), 'A123')

    def test_buckets(self):
        self.assertEqual(bucket('ORIG Dark3', 'Dark3+$1D50'), 'Original Mac game code')
        self.assertEqual(bucket('NATIVE', 'c2p1x1_8_c5_gen'), 'Presentation: C2P')
        self.assertEqual(bucket('NATIVE', 'aitdLineADispatch'), 'Trap entry and dispatch')
        self.assertEqual(bucket('NATIVE', 'unlistedHelper'), 'Other native')
        self.assertEqual(bucket('ROM', 'ROM $F81100'), 'Kickstart and other')


if __name__ == '__main__':
    unittest.main()
