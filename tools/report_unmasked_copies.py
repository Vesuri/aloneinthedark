#!/usr/bin/env python3
"""Report FRAME.9 caller costs from an unmodified monster fight profile.

Call-tree exclusive time is partitioned, never summed with overlapping subtrees.
Inline dispatch/services remain together; this is not per-caller PC attribution.
"""
import argparse
import collections
from aprof_report import Profile

CALLERS = ('Dark+$1DE6', 'JT452->Misc2+$23C8')

def breakdown(p, caller):
    roots = [n for n in p.order if p.labels[n] == 'TRAP CopyBits'
             and p.labels[p.nodes[n][0]] == caller]
    count = sum(p.nodes[n][4] for n in roots)
    if not count:
        raise ValueError('missing caller: ' + caller)
    costs = collections.Counter()
    def visit(n, service=False):
        parent, target, kind, units, calls = p.nodes[n]
        label = p.labels[n]
        service = service or kind not in (0, 10) or (kind == 0 and p.segment(target) is not None)
        if service:
            category = 'interrupts and original callbacks'
        elif 'CopyBits8::directRows' in label:
            category = 'pixel rows (excluding interrupts)'
        elif 'copyPortBits8' in label or 'CopyBits8::copy' in label:
            category = 'adapter and copy setup'
        elif 'markDirtyBounds' in label:
            category = 'dirty bounds'
        else:
            category = 'dispatch, guards and other services'
        costs[category] += units
        for child in p.children[n]:
            visit(child, service)
    for root in roots:
        visit(root)
    total = sum(p.inclusive[n] for n in roots)
    if sum(costs.values()) != total:
        raise ValueError('cost partition does not conserve cycles')
    return count, total, costs

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('name', help='monster fight profile name')
    args = parser.parse_args()
    p = Profile(args.name)
    print(f'{p.steps} frames; full phase {p.ms(p.units):.3f} ms/frame')
    for caller in CALLERS:
        count, total, costs = breakdown(p, caller)
        print(f'{caller}: {count} calls, {total/p.units_per_ms*1000/count:.2f} us/call, '
              f'{p.ms(total):.3f} ms/frame')
        for label, units in sorted(costs.items()):
            print(f'  {label}: {p.ms(units):.4f} ms/frame')

if __name__ == '__main__':
    main()
