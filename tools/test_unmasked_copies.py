#!/usr/bin/env python3
"""Cycle partition checks, including interrupt descendants and absent callers."""
import unittest
from types import SimpleNamespace
from aprof_report import call_tree
from report_unmasked_copies import breakdown

class Partition(unittest.TestCase):
    def profile(self):
        nodes = {0:(0,0,0,0,0), 1:(0,100,0,0,1),
                 2:(1,0xa000a8ec,10,10,2), 3:(2,200,0,20,2),
                 4:(3,300,0,30,2), 5:(4,400,27,4,1),
                 6:(5,500,0,6,1), 7:(2,110,0,7,1)}
        children, order, inclusive = call_tree(nodes)
        return SimpleNamespace(nodes=nodes, children=children, order=order,
            inclusive=inclusive, segment=lambda pc: (100,120,'Dark') if 100<=pc<120 else None,
            labels={0:'root',1:'Dark+$1DE6',2:'TRAP CopyBits',3:'copyPortBits8',
                    4:'CopyBits8::directRows',5:'EXC27',6:'helper',7:'Dark callback'})
    def test_partition(self):
        count,total,cost = breakdown(self.profile(), 'Dark+$1DE6')
        self.assertEqual((count,total),(2,77))
        self.assertEqual(cost['pixel rows (excluding interrupts)'],30)
        self.assertEqual(cost['interrupts and original callbacks'],17)
        self.assertEqual(cost['adapter and copy setup'],20)
        self.assertEqual(sum(cost.values()),total)
    def test_missing(self):
        with self.assertRaises(ValueError): breakdown(self.profile(),'missing')

if __name__ == '__main__': unittest.main()
