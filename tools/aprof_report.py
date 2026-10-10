#!/usr/bin/env python3
"""Summarize an exact emulated-cycle profile written by amiga/aprof.sh.

  aprof_report.py report NAME              summary, buckets, chip bus, flat, call tree, traps
  aprof_report.py annotate NAME FUNCTION   hottest instructions of a native function
  aprof_report.py subtree NAME LABEL...    original/port time below call-tree labels

Inputs are tmp/aprof/NAME.{prof,log,elf,jt.bin}. Original-code functions are named
Segment+$offset (offsets include the CODE header); their starts are LINK A6 prologues
in tmp/segments plus call targets seen in the profile. Times are emulated: the
profiler counts FS-UAE cycle units for every instruction, so warp does not matter.
"""
import argparse, bisect, collections, re, struct, subprocess, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'tmp/aprof'
OBJDUMP = 'm68k-amiga-elf-objdump'
LINE_A = 10

# Exclusive self-time buckets for native code, by function-name fragment (first match).
BUCKETS = [
    ('Presentation: C2P', ('c2p1x1_8_c5_gen', 'aitdKalmsC2PRect')),
    ('Presentation: other', ('AitdScreen::presentMacFrame', 'AitdScreen::queueFrame', 'Planar8', 'presentMacRuntime', 'AmigaHardware::blitter', '_blitter', 'AmigaHardware::setDMAChannels')),
    ('QuickDraw: CopyBits', ('CopyBits8', 'RegionRows', 'copyPortBits8', 'memmove', 'memcpy', 'StepCopy', 'MaskCopy')),
    ('QuickDraw: fills, lines, regions', ('FillRect8', 'Line8', 'lineGWorld', 'paintRect', 'penLine', 'Polygon',
                                          'RegionExpand', 'lineWindow', 'paintPort', 'FramePoly', 'markDirtyBounds')),
    ('Trap entry and dispatch', ('aitd_line_a_handler', 'aitd_line_a_trap_entry', 'aitdLineADispatch', 'aitdAuditTrapEntry', 'clipRectTrap', 'findWindowTrap', 'blockMoveTrap', 'obscureCursorTrap', 'serviceQuickTrap', 'dispatchMacTrap', 'isUserService',
                                 'routePatchedTrap', 'dispatch', 'aitd_user', 'bookFrame', 'sceneFrameBoundary',
                                 'finishBookFrame', 'graphicsQuery')),
    ('Port state lookups', ('rgbColor', 'GWorld8::colorIndex', 'setGWorld', 'getGWorld', 'gWorldForPort', 'MacHeap',
                            'colorWindowFrame', 'windowSlot', 'handleZone')),
    ('VBL scheduling and effect polling', ('scheduleVBLTask', 'serviceNativeEffects', 'aitdVBLCallback')),
    ('Audio, interrupts and VBI', ('Song', 'song', 'Paula', 'musicInterrupt', 'vbi', 'Vbi', 'VBI', 'Mouse', 'mouse')),
]


def parse_profile(text):
    """Return (header, pcs, nodes): pcs[pc]=(units, executions, chip_units, chip_accesses),
    nodes[id]=(parent, target, kind, self_units, calls). kind 0 is JSR/BSR, otherwise
    the exception vector; Line-A targets are 0xA0000000 | trap word."""
    header, pcs, nodes = {}, {}, {}
    lines = text.splitlines()
    if not lines or lines[0] != 'AITDPROF 1':
        raise ValueError('not an AITDPROF 1 profile')
    for line in lines[1:]:
        f = line.split()
        if f[0] == 'P':
            chip = (int(f[4]), int(f[5])) if len(f) > 5 else (0, 0)
            pcs[int(f[1], 16)] = (int(f[2]), int(f[3])) + chip
        elif f[0] == 'N':
            nodes[int(f[1])] = (int(f[2]), int(f[3], 16), int(f[4]), int(f[5]), int(f[6]))
        elif len(f) == 2:
            header[f[0]] = int(f[1], 16) if f[0] == 'cacr' else int(f[1])
    if 0 not in nodes or 'units' not in header:
        raise ValueError('incomplete profile')
    return header, pcs, nodes


def parse_log(text):
    """Segments at start/stop, relocated ELF sections, A5, interval counters."""
    log = {'segs': [], 'stopsegs': [], 'sections': {}, 'a5': None, 'delta': None, 'room': None, 'hz': 0}
    for line in text.splitlines():
        m = re.match(r'(SEG|SEGSTOP) \d+ (\S+) ([0-9a-f]+) ([0-9a-f]+)$', line)
        if m:
            key = 'segs' if m.group(1) == 'SEG' else 'stopsegs'
            log[key].append((int(m.group(3), 16), int(m.group(4), 16), m.group(2)))
        m = re.match(r'\s*\[\d+\]\s+0x([0-9a-f]+)->0x([0-9a-f]+) at 0x[0-9a-f]+: (\S+) ', line)
        if m and int(m.group(1), 16):
            log['sections'][m.group(3)] = (int(m.group(1), 16), int(m.group(2), 16))
        m = re.match(r'A5 ([0-9a-f]+)$', line)
        if m:
            log['a5'] = int(m.group(1), 16)
        m = re.match(r'DELTA fields=(\d+) frames=(\d+) steps=(\d+)$', line)
        if m:
            log['delta'] = tuple(map(int, m.groups()))
        m = re.match(r'ROOM start=(\S+) stop=(\S+)$', line)
        if m:
            log['room'] = m.groups()
        m = re.match(r'CONFIG (\S+) .*frequency_hz=(\d+)', line)
        if m:
            log['config'], log['hz'] = m.group(1), int(m.group(2))
    log['segs'].sort()
    log['stopsegs'].sort()
    return log


def parse_jump_table(data, a5):
    """Loaded entries (segment, JMP abs.L) keyed by the JSR target A5+34+8n."""
    table = {}
    for n in range(len(data) // 8):
        _, op, addr = struct.unpack('>HHI', data[8 * n:8 * n + 8])
        if op == 0x4EF9:
            table[a5 + 34 + 8 * n] = (n, addr)
    return table


def link_starts(code):
    """Offsets of LINK A6 prologues in a CODE resource (header included)."""
    return {i for i in range(4, len(code) - 1, 2) if code[i] == 0x4E and code[i + 1] == 0x56}


def call_tree(nodes):
    """Children lists, depth-first order and inclusive units per node."""
    children = collections.defaultdict(list)
    for n, (parent, *_rest) in nodes.items():
        if n:
            children[parent].append(n)
    order, stack = [], [0]
    while stack:
        n = stack.pop()
        order.append(n)
        stack.extend(children[n])
    inclusive = {}
    for n in reversed(order):
        inclusive[n] = nodes[n][3] + sum(inclusive[c] for c in children[n])
    return children, order, inclusive


def trap_name(word, traps):
    if word in traps:
        return traps[word]
    # Toolbox traps ignore the auto-pop bit; OS traps ignore their flag bits.
    masked = word & ~0x0400 if word & 0x0800 else word & 0xF8FF
    return traps.get(masked, 'A%03X' % (word & 0xFFF))


def bucket(region, function):
    if region.startswith('ORIG'):
        return 'Original Mac game code'
    if region != 'NATIVE':
        return 'Kickstart and other'
    for name, keys in BUCKETS:
        if any(k in function for k in keys):
            return name
    return 'Other native'


def short(fn, n=80):
    fn = re.sub(r'\(.*\)( const)?$', '', fn)
    return fn if len(fn) <= n else fn[:n - 3] + '...'


class Profile:
    def __init__(self, name):
        self.name = name
        paths = {k: OUT / f'{name}.{k}' for k in ('prof', 'log', 'elf', 'jt.bin')}
        for k in ('prof', 'log', 'elf'):
            if not paths[k].exists():
                raise SystemExit(f'APROF / missing {paths[k]}')
        self.header, self.pcs, self.nodes = parse_profile(paths['prof'].read_text())
        self.log = parse_log(paths['log'].read_text(errors='replace'))
        if not self.log['delta'] or not self.log['segs']:
            raise SystemExit('APROF / log has no completed interval')
        if self.log['stopsegs'] and self.log['stopsegs'] != self.log['segs']:
            raise SystemExit('APROF / CODE segments moved during the interval')
        self.fields, self.frames, self.steps = self.log['delta']
        self.units = self.header['units']
        self.units_per_ms = self.header['CYCLE_UNIT'] * self.header.get('colorclock_hz', 3546895) / 1000.0
        self.jt = {}
        if self.log['a5'] and paths['jt.bin'].exists():
            self.jt = parse_jump_table(paths['jt.bin'].read_bytes(), self.log['a5'])
        self.traps = {}
        names = ROOT / 'tmp/trap_names.lua'
        if names.exists():
            for m in re.finditer(r'\[0x([0-9A-F]{4})\] = "(\w+)"', names.read_text()):
                self.traps[int(m.group(1), 16)] = m.group(2)
        self._symbols(paths['elf'])
        self._segment_functions()
        self.children, self.order, self.inclusive = call_tree(self.nodes)
        self.labels = {n: self.node_label(n) for n in self.nodes}

    def _symbols(self, elf):
        sections = self.log['sections']
        heads = subprocess.run([OBJDUMP, '-h', str(elf)], capture_output=True, text=True, check=True).stdout
        self.link = {f[1]: int(f[3], 16) for f in (l.split() for l in heads.splitlines()) if len(f) >= 7 and f[0].isdigit()}
        table = subprocess.run([OBJDUMP, '-t', '-C', str(elf)], capture_output=True, text=True, check=True).stdout
        symbols = []
        for line in table.splitlines():
            m = re.match(r'([0-9a-f]{8}) (.{7}) (\S+)\s+[0-9a-f]{8} (.+)$', line)
            if not m or m.group(3) not in ('.text', 'code') or m.group(3) not in sections:
                continue
            # The assembly C2P and trap entries are not typed as functions.
            if 'F' not in m.group(2) and not m.group(4).startswith(('_', 'c2p', 'aitd')):
                continue
            symbols.append((int(m.group(1), 16) - self.link[m.group(3)] + sections[m.group(3)][0], m.group(4).strip()))
        symbols.sort()
        self.symbol_addrs = [a for a, _ in symbols]
        self.symbol_names = [s for _, s in symbols]
        text = [v for k, v in sections.items() if k in ('.text', 'code')]
        self.text_range = (min(v[0] for v in text), max(v[1] for v in text))

    def _segment_functions(self):
        self.segs = self.log['segs']
        self.seg_begins = [s[0] for s in self.segs]
        starts = {}
        for begin, end, seg in self.segs:
            files = list((ROOT / 'tmp/segments').glob(f'CODE_*_{seg}'))
            starts[seg] = link_starts(files[0].read_bytes()) if files else set()
        for parent, target, kind, _, _ in self.nodes.values():
            if kind == 0:
                target = self.jt.get(target, (0, target))[1]
                seg = self.segment(target)
                if seg:
                    starts[seg[2]].add(target - seg[0])
        self.seg_starts = {k: sorted(v) for k, v in starts.items()}

    def segment(self, pc):
        i = bisect.bisect_right(self.seg_begins, pc) - 1
        if i >= 0 and self.segs[i][0] <= pc < self.segs[i][1]:
            return self.segs[i]
        return None

    def classify(self, pc):
        """(region, function) for any address."""
        if pc in self.jt:
            region, fn = self.classify(self.jt[pc][1])
            return region, f'JT{self.jt[pc][0]}->{fn}'
        seg = self.segment(pc)
        if seg:
            starts = self.seg_starts[seg[2]]
            j = bisect.bisect_right(starts, pc - seg[0]) - 1
            return 'ORIG ' + seg[2], f'{seg[2]}+${starts[j]:04X}' if j >= 0 else f'{seg[2]}+?'
        if self.text_range[0] <= pc < self.text_range[1]:
            j = bisect.bisect_right(self.symbol_addrs, pc) - 1
            return 'NATIVE', self.symbol_names[j] if j >= 0 else 'native?'
        if 0xF80000 <= pc < 0x1000000:
            return 'ROM', f'ROM ${pc & ~0xFF:06X}'
        return 'OTHER', f'${pc:06X}'

    def node_label(self, n):
        parent, target, kind, _, _ = self.nodes[n]
        if n == 0:
            return '<root>'
        if kind == LINE_A:
            return 'TRAP ' + trap_name(target & 0xFFFF, self.traps)
        if kind:
            return f'EXC{kind} {short(self.classify(target)[1], 50)}'
        prefix = ''
        if target in self.jt:
            prefix = f'JT{self.jt[target][0]}->'
            target = self.jt[target][1]
        seg = self.segment(target)
        if seg:
            return f'{prefix}{seg[2]}+${target - seg[0]:04X}'
        return prefix + short(self.classify(target)[1], 70)

    def pct(self, u):
        return 100.0 * u / self.units

    def ms(self, u):
        return u / self.units_per_ms / self.steps

    def cpu_cycles(self, u):
        return u / self.units_per_ms / 1000.0 * self.log['hz']


def report(p, top):
    step = 'step'
    total_ms = p.units / p.units_per_ms
    h = p.header
    print(f'== {p.name} ({p.log.get("config", "?")}): {p.steps} steps, {p.frames} frames, {p.fields} fields, '
          f'{total_ms:.1f} ms emulated, {total_ms / p.steps:.2f} ms/{step}')
    if p.log['room']:
        print(f'   room/camera {p.log["room"][0]} -> {p.log["room"][1]}')
    print(f'   CACR=${h.get("cacr", 0):X}; unmatched RTS {h["unmatched_rts"]}, RTE {h["unmatched_rte"]}, '
          f'call-stack overflows {h["overflow"]}; {len(p.jt)} jump-table entries resolved')

    flat = collections.Counter(); execs = collections.Counter(); buckets = collections.Counter()
    for pc, (u, k, _, _) in p.pcs.items():
        key = p.classify(pc)
        flat[key] += u; execs[key] += k; buckets[bucket(*key)] += u
    buckets['Exception entry and STOP gaps'] += h['gap']
    print(f'\n-- Exclusive time by bucket, ms per {step} --')
    for b, u in buckets.most_common():
        print(f'{p.pct(u):6.2f}%  {p.ms(u):7.2f} ms  {b}')

    chip = [(pc, v[2], v[3]) for pc, v in p.pcs.items() if v[3]]
    if chip:
        cu = sum(c for _, c, _ in chip); cn = sum(n for _, _, n in chip)
        cyc = f', {p.cpu_cycles(cu) / cn:.1f} CPU cycles/access' if p.log['hz'] else ''
        print(f'\n-- CPU Chip-bus accesses: {p.pct(cu):.1f}% of time, {p.ms(cu):.2f} ms/{step}, '
              f'{cn / p.steps:.0f} accesses/{step}{cyc} --')
        by_fn = collections.Counter(); by_n = collections.Counter()
        for pc, c, n in chip:
            key = p.classify(pc); by_fn[key] += c; by_n[key] += n
        for key, c in by_fn.most_common(10):
            print(f'{p.pct(c):6.2f}%  {p.ms(c):7.2f} ms  {by_n[key] / p.steps:8.0f} accesses  {key[0]:<10} {short(key[1], 60)}')

    print(f'\n-- Exclusive time by function, top {top} --')
    for key, u in flat.most_common(top):
        print(f'{p.pct(u):6.2f}%  {p.ms(u):7.2f} ms  {execs[key] / p.steps:9.0f} instr/{step}  {key[0]:<12} {short(key[1])}')

    included = collections.Counter(); calls = collections.Counter()
    for n in p.order[1:]:
        label = p.labels[n]
        calls[label] += p.nodes[n][4]
        a = p.nodes[n][0]
        while a and p.labels[a] != label:
            a = p.nodes[a][0]
        if not a:  # count recursion once
            included[label] += p.inclusive[n]
    print(f'\n-- Inclusive time by call target, top {top} --')
    for label, u in included.most_common(top):
        print(f'{p.pct(u):6.2f}%  {p.ms(u):7.2f} ms  {calls[label] / p.steps:8.1f} calls/{step}  {label}')

    traps = collections.Counter(); trap_calls = collections.Counter()
    for n in p.order[1:]:
        if p.nodes[n][2] != LINE_A:
            continue
        a = p.nodes[n][0]
        while a and p.nodes[a][2] != LINE_A:
            a = p.nodes[a][0]
        if not a:  # outermost traps only
            traps[p.labels[n]] += p.inclusive[n]; trap_calls[p.labels[n]] += p.nodes[n][4]
    print(f'\n-- Outermost Toolbox traps, inclusive ({p.pct(sum(traps.values())):.1f}% of time) --')
    for label, u in traps.most_common(25):
        per_call = u / max(1, trap_calls[label]) / p.units_per_ms * 1000
        print(f'{p.pct(u):6.2f}%  {p.ms(u):7.2f} ms  {trap_calls[label] / p.steps:8.1f} calls/{step}  {per_call:8.1f} us/call  {label}')

    tree = OUT / f'{p.name}.tree.txt'
    with tree.open('w') as f:
        def dump(n, depth):
            if p.inclusive[n] < p.units * 0.002 or depth > 40:
                return
            f.write(f'{"  " * depth}{p.pct(p.inclusive[n]):6.2f}% (self {p.pct(p.nodes[n][3]):5.2f}%) '
                    f'{p.nodes[n][4]:8d} calls  {p.labels[n]}\n')
            for c in sorted(p.children[n], key=lambda c: -p.inclusive[c]):
                dump(c, depth + 1)
        dump(0, 0)
    hot = OUT / f'{p.name}.hot.txt'
    with hot.open('w') as f:
        for pc, (u, k, cu, cn) in sorted(p.pcs.items(), key=lambda kv: -kv[1][0])[:500]:
            region, fn = p.classify(pc)
            seg = p.segment(pc)
            where = f'{seg[2]}+${pc - seg[0]:04X}' if seg else ''
            f.write(f'{pc:06x} {p.pct(u):6.3f}% {k:10d}x {p.cpu_cycles(u) / max(1, k):7.1f} cyc  '
                    f'chip {cn:7d}  {region:<12} {where:<14} {short(fn, 60)}\n')
    print(f'\nwrote {tree.relative_to(ROOT)} and {hot.relative_to(ROOT)}')


def annotate(p, function, top):
    sections = p.log['sections']
    text = subprocess.run([OBJDUMP, '-d', '-C', '-j', '.text', '-j', 'code', str(OUT / f'{p.name}.elf')],
                          capture_output=True, text=True, check=True).stdout
    instructions, section, current = {}, None, None
    for line in text.splitlines():
        m = re.match(r'Disassembly of section (\S+):', line)
        if m:
            section = m.group(1); continue
        m = re.match(r'[0-9a-f]+ <(.*)>:', line)
        if m:
            current = m.group(1); continue
        m = re.match(r'\s*([0-9a-f]+):\s+(?:[0-9a-f]{4} )+\s*(.*)', line)
        if m and current and function in current:
            instructions[int(m.group(1), 16) - p.link[section] + sections[section][0]] = m.group(2).strip()
    if not instructions:
        raise SystemExit(f'APROF / no native function matches {function}')
    rows = sorted(((p.pcs.get(pc, (0, 0, 0, 0)), pc, ins) for pc, ins in instructions.items()), reverse=True)
    print(f'{function}: {p.pct(sum(r[0][0] for r in rows)):.2f}% of the interval')
    for (u, k, cu, cn), pc, ins in rows[:top]:
        print(f'{pc:06x} {p.pct(u):6.3f}% {k:9d}x {p.cpu_cycles(u) / max(1, k):6.1f} cyc  chip {cn:7d}  {ins}')


def subtree(p, labels):
    for want in labels:
        original = port = 0
        for n in p.nodes:
            if p.labels[n] != want:
                continue
            stack = [n]
            while stack:
                x = stack.pop(); stack.extend(p.children[x])
                _, target, kind, self_units, _ = p.nodes[x]
                target = p.jt.get(target, (0, target))[1]
                if not kind and p.segment(target):
                    original += self_units
                else:
                    port += self_units
        print(f'{want:<28} original {p.ms(original):6.2f} ms  port {p.ms(port):6.2f} ms  '
              f'total {p.ms(original + port):6.2f} ms/step ({p.pct(original + port):.1f}%)')


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest='command', required=True)
    r = sub.add_parser('report'); r.add_argument('name'); r.add_argument('--top', type=int, default=40)
    a = sub.add_parser('annotate'); a.add_argument('name'); a.add_argument('function'); a.add_argument('--top', type=int, default=25)
    s = sub.add_parser('subtree'); s.add_argument('name'); s.add_argument('labels', nargs='+')
    args = ap.parse_args()
    p = Profile(args.name)
    if args.command == 'report':
        report(p, args.top)
    elif args.command == 'annotate':
        annotate(p, args.function, args.top)
    else:
        subtree(p, args.labels)


if __name__ == '__main__':
    main()
