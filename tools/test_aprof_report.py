#!/usr/bin/env python3
import copy
from types import SimpleNamespace
from check_monster_audit import HEADER, read_audit
from aprof_monster import FRAME, decode_frames, phases_from_log, compare
from aprof_report import excluded_nodes
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


class MonsterAudit(unittest.TestCase):
    def report(self, pal=1):
        states = [(137,4,-1), (136,4,-1), (136,4,23), (136,237,22), (131,272,23)]
        header = HEADER.pack(0x41495444,0x4d4f4e31,1,5,5,pal,1,15,0x80008000,0x80008000,1,0,1,2,3,4)
        rows = b''.join(FRAME.pack(200+i,100+i*6,i,(65530+i*30)&65535,
            song,carnby,monster,0,100,0,0) for i,(song,carnby,monster) in enumerate(states))
        return header+rows

    def test_complete_and_field_wrap(self):
        result = read_audit(self.report())
        self.assertEqual(result['backend'],'WHDLoad')
        self.assertEqual(result['cacr_start'],0x80008000)
        self.assertEqual(len(result['phases']),4)
        self.assertEqual(result['phases'][0]['fields'],30)
        self.assertEqual(result['phases'][0]['stalls'][0]['seconds'],0.6)
        self.assertEqual(read_audit(self.report(0))['phases'][0]['stalls'][0]['seconds'],0.5)

    def test_nonstall_cadence(self):
        data=bytearray(self.report())
        for i in range(5):
            struct.pack_into('>H',data,HEADER.size+i*FRAME.size+12,100+i*5)
        phase=read_audit(data)['phases'][3]
        self.assertEqual(phase['steady_fields_per_frame'],5)
        self.assertEqual(phase['steady_fps'],10)
        self.assertEqual(phase['stalls'],[])

    def test_rejects_incomplete_corrupt_and_bad_events(self):
        data = self.report()
        for broken in (data[:63],data[:-1],data+b'x'):
            with self.assertRaises(ValueError): read_audit(broken)
        for index,value in ((0,0),(2,2),(3,16385),(4,98),(5,2),(6,2),(10,0),(12,4)):
            broken=bytearray(data);struct.pack_into('>I',broken,index*4,value)
            with self.subTest(index=index),self.assertRaises(ValueError): read_audit(broken)
        broken=bytearray(data);struct.pack_into('>H',broken,HEADER.size+FRAME.size+14,137)
        with self.assertRaises(ValueError): read_audit(broken)


class MonsterReport(unittest.TestCase):
    def frames(self):
        states = [(137,4,-1), (136,4,-1), (136,4,23), (136,237,22), (131,272,23)]
        return decode_frames(b''.join(FRAME.pack(200+i, 100+i*6, i,
            (65530+i*10)&65535, song, carnby, monster, 0, 100, 0, 0)
            for i,(song,carnby,monster) in enumerate(states)))

    def log(self):
        phases = ('attic','entry','approach','fight')
        return ''.join(f'PHASE_START {p} row={i}\nPHASE_END {p} row={i+1}\n'
                       for i,p in enumerate(phases))+'COMPLETE\n'

    def test_frame_wrap_and_phase_events(self):
        rows = self.frames()
        self.assertEqual(rows[1]['delta_fields'], 10)
        self.assertEqual(len(phases_from_log(self.log(), rows)), 4)

    def test_rejects_incomplete_or_wrong_state(self):
        with self.assertRaises(ValueError):
            decode_frames(b'bad')
        with self.assertRaises(ValueError):
            phases_from_log(self.log().replace('COMPLETE','TIMEOUT'), self.frames())
        rows = self.frames(); rows[3]['carnby'] = 4
        with self.assertRaises(ValueError):
            phases_from_log(self.log(), rows)
        with self.assertRaises(ValueError):
            phases_from_log(self.log().replace('START fight row=3','START fight row=2'), self.frames())

    def test_subtree_exclusion_is_not_double_counted(self):
        p = SimpleNamespace(order=[0,1,2,3,4], labels={0:'root',1:'JT120->song',2:'camera',3:'child',4:'keep'},
                            nodes={0:(0,),1:(0,),2:(1,),3:(2,),4:(0,)})
        self.assertEqual(excluded_nodes(p, ['song','camera']), {1,2,3})

    def test_repeatability_ignores_scene_numbers_but_checks_states(self):
        phase = dict(phase='attic',start={'song':137},end={'song':136},fields=100,
                     stalls=[dict(scene=300,fields=40,event='song',before={'song':137},after={'song':136})])
        a = dict(config='PAL', phases=[copy.deepcopy(phase) for _ in range(4)])
        b = copy.deepcopy(a); b['phases'][0]['fields']=102
        b['phases'][0]['stalls'][0]['scene']=310
        self.assertEqual(compare(a,b), [])
        b['phases'][0]['fields']=103
        self.assertTrue(compare(a,b))
        b = copy.deepcopy(a); b['window_frame_stops']=100
        self.assertTrue(compare(a,b))
        b = copy.deepcopy(a); b['phases'][0]['stalls'][0]['after']['song']=132
        self.assertTrue(compare(a,b))


if __name__ == '__main__':
    unittest.main()
