#!/usr/bin/env python3
"""CREL-aware static trap census, with header-inclusive (segment, offset) sites.

Promoted from the planning census. The live roots are CODE 1, main, DATA
function pointers, and referenced jump-table / prologue-bearing PC targets.
Indirect transfers remain explicitly listed; this is not proof of execution.
"""
import argparse
import collections
import re
import struct
from pathlib import Path
from resource_fork import parse_resource_fork
from capstone import Cs, CS_ARCH_M68K, CS_MODE_M68K_040, CsError
from capstone.m68k import (M68K_OP_BR_DISP, M68K_OP_MEM, M68K_OP_IMM, M68K_OP_REG,
                           M68K_AM_PCI_DISP, M68K_AM_PCI_INDEX_8_BIT_DISP,
                           M68K_AM_ABSOLUTE_DATA_SHORT, M68K_AM_ABSOLUTE_DATA_LONG,
                           M68K_AM_REGI_ADDR_DISP)
from m68k_sweep import is_020_only

md = Cs(CS_ARCH_M68K, CS_MODE_M68K_040); md.detail = True
NAMES = {}
CODE = {}
RELOC = {}
R = {}
JT = []
SEGNAME = {}

def trapname(w):
    if w in NAMES: return NAMES[w]
    if w & 0x0800:
        k = 0xA800 | (w & 0x3FF)
    else:
        k = 0xA000 | (w & 0xFF)
    n = NAMES.get(k, '?')
    return n + ('(autopop)' if (w & 0x0800 and w & 0x0400) else '(flags)')

def load(path):
    global R, SEGNAME, CODE, RELOC, JT
    rs = parse_resource_fork(Path(path).read_bytes())
    R = {(r.kind, r.rid): r for r in rs}
    SEGNAME = {r.rid: r.name for r in rs if r.kind == b'CODE'}
    CODE = {r.rid: r.body for r in rs if r.kind == b'CODE' and r.rid != 0}
    RELOC = {}
    for n in CODE:
        m = {}
        c = R.get((b'CREL', n))
        if c:
            for o in struct.unpack(f'>{len(c.body)//2}H', c.body):
                if (o & ~1) < 4 or (o & ~1) + 4 > len(CODE[n]):
                    raise ValueError(f'CREL out of bounds in CODE {n}')
                m[o & ~1] = 'STRS' if o & 1 else 'A5'
        RELOC[n] = m
    code0 = R[(b'CODE', 0)].body
    above, below, length, offset = struct.unpack_from('>IIII', code0)
    if (above, below, length, offset) != (3776, 75616, 3744, 32) or len(code0) != 3760:
        raise ValueError('CODE 0 / unsupported AitD 1.0 layout')
    JT = []
    for i in range(16, len(code0), 8):
        off, push, seg, trap = struct.unpack_from('>HHHH', code0, i)
        if (push != 0x3f3c or trap != 0xa9f0 or seg not in CODE
                or off & 1 or off + 4 >= len(CODE[seg])):
            raise ValueError(f'unsupported CODE 0 entry at {i:#x}')
        JT.append((seg, off + 4))

def jt_index(a5off):
    if 34 <= a5off < 34 + 8 * len(JT) and (a5off - 34) % 8 == 0:
        return (a5off - 34) // 8
    return None

def seg_label(n): return f"{n}:{SEGNAME.get(n,'') or 'CODE1'}"

STOP = {"rts", "rte", "rtr", "bra", "illegal", "jmp", "rtd"}
BR = re.compile(r"^(b(ra|sr|hi|ls|cc|cs|ne|eq|vc|vs|pl|mi|ge|lt|gt|le)|db[a-z]{1,3}|jsr|jmp)$")

def ops(i):
    try: return i.operands
    except CsError: return []

class Walker:
    def __init__(self):
        self.seen = {n: set() for n in CODE}
        self.insn_at = {n: {} for n in CODE}
        self.traps = []        # (seg, pc, word, context list)
        self.lowmem = []       # (seg, pc, addr, text)
        self.absother = []
        self.blind = []        # (seg, pc, text)
        self.jtcalls = collections.Counter()
        self.codeptrs = collections.defaultdict(set)  # seg -> pc-relative lea/pea targets
        self.jt_taken = collections.Counter()          # jt entries whose address is taken (not called)
        self.i020 = collections.Counter()
        self.i020_kind = collections.defaultdict(collections.Counter)
        self.a5calls = []
        self.switches = []
        self.pending = []
        self.ptr_roots = []
        self.jtsites = collections.defaultdict(list)
        self.intra = collections.defaultdict(list)

    def walk(self, seg, roots):
        code = CODE[seg]; rel = RELOC[seg]
        todo = list(roots)
        while todo:
            pc = todo.pop()
            ctx = []
            while 0 <= pc < len(code) - 1 and pc not in self.seen[seg]:
                w = struct.unpack_from('>H', code, pc)[0]
                if 0xA000 <= w <= 0xAFFF:
                    self.seen[seg].update((pc, pc + 1))
                    self.traps.append((seg, pc, w, list(ctx[-10:])))
                    ctx.append(f"_{trapname(w)}")
                    pc += 2
                    if (w & 0x0C00) == 0x0C00 or w in (0xA9F4, 0xA9C9):   # autopop / ExitToShell / SysError
                        break
                    continue
                try:
                    insn = next(iter(md.disasm(code[pc:pc + 16], pc, count=1)), None)
                except CsError:
                    insn = None
                if insn is None or insn.size == 0 or insn.mnemonic == 'dc.w':
                    self.blind.append((seg, pc, 'undecodable'))
                    break
                for k in range(insn.size): self.seen[seg].add(pc + k)
                self.insn_at[seg][pc] = insn
                mn = insn.mnemonic.lower(); base = mn.split('.')[0]
                why = is_020_only(insn)
                if why:
                    self.i020[seg] += 1
                    self.i020_kind[seg][why.split(' ')[0] if 'scaled' not in why and 'full' not in why else why.split(' (')[0][:24]] += 1
                txt = f"{mn} {insn.op_str}"
                # relocated long operands
                relocs = [(o, rel[o]) for o in range(pc + 2, pc + insn.size - 3, 2) if o in rel]
                a5targets = []
                for o, kind in relocs:
                    v = struct.unpack_from('>I', code, o)[0]
                    if kind == 'A5':
                        s = v if v < 0x80000000 else v - (1 << 32)
                        a5targets.append(s)
                        txt += f"  [A5{s:+#x}]"
                    else:
                        strs = R[(b'STRS', 0)].body
                        e = strs.find(b'\0', v)
                        txt += f"  [STRS+{v:#x} {strs[v:min(e, v+40)]!r}]"
                ctx.append(txt)
                # low memory
                for op in ops(insn):
                    if op.type == M68K_OP_MEM and op.address_mode in (M68K_AM_ABSOLUTE_DATA_SHORT, M68K_AM_ABSOLUTE_DATA_LONG):
                        a = op.imm & 0xffffffff
                        if not relocs:
                            if a < 0x2000 or a >= 0xFFFF8000:
                                self.lowmem.append((seg, pc, a, txt))
                            else:
                                self.absother.append((seg, pc, a, txt))
                    if op.type == M68K_OP_MEM and op.address_mode == M68K_AM_PCI_DISP and base in ('lea', 'pea'):
                        self.codeptrs[seg].add(pc + 2 + op.mem.disp)
                # control flow
                if base in ('jsr', 'jmp'):
                    tgt_jt = None
                    if a5targets and insn.size == 6:
                        tgt_jt = jt_index(a5targets[0])
                    m = re.match(r'^\$([0-9a-f]+)\(a5\)$', insn.op_str)
                    if m:
                        tgt_jt = jt_index(int(m.group(1), 16))
                    if tgt_jt is not None:
                        self.jtcalls[tgt_jt] += 1
                        self.jtsites[tgt_jt].append((seg, pc))
                        self.pending.append(tgt_jt)
                        ctx[-1] += f"  -> JT{tgt_jt} {seg_label(JT[tgt_jt][0])}+{JT[tgt_jt][1]:#06x}"
                        if base == 'jmp': break
                        pc += insn.size; continue
                    t = self.target(insn)
                    sw = self.switch_targets(seg, code, pc, insn) if base == 'jmp' and t is None else None
                    if sw:
                        self.switches.append((seg, pc, len(sw)))
                        todo.extend(x for x in sw if x not in self.seen[seg])
                    elif t is not None:
                        if base == 'jsr': self.intra[(seg, t)].append(pc)
                        if 0 <= t < len(code) and t not in self.seen[seg]: todo.append(t)
                    else:
                        if not a5targets:
                            self.blind.append((seg, pc, txt))
                    if base == 'jmp': break
                    pc += insn.size; continue
                mm = re.search(r'\$([0-9a-f]+)\(a5\)', insn.op_str)
                if mm and base in ('pea', 'lea') and jt_index(int(mm.group(1), 16)) is not None:
                    j = jt_index(int(mm.group(1), 16))
                    self.jt_taken[j] += 1; self.pending.append(j)
                    ctx[-1] += f"  (&JT{j} {seg_label(JT[j][0])}+{JT[j][1]:#06x})"
                if a5targets and base in ('pea', 'move', 'lea', 'movea'):
                    j = jt_index(a5targets[0])
                    if j is not None:
                        self.jt_taken[j] += 1
                        self.pending.append(j)
                        ctx[-1] += f"  (&JT{j} {seg_label(JT[j][0])}+{JT[j][1]:#06x})"
                if BR.match(base):
                    t = self.target(insn)
                    if base == 'bsr' and t is not None: self.intra[(seg, t)].append(pc)
                    if t is not None and 0 <= t < len(code):
                        if t not in self.seen[seg]: todo.append(t)
                    else:
                        self.blind.append((seg, pc, txt))
                if base in STOP: break
                pc += insn.size

    def switch_targets(self, seg, code, pc, insn):
        # idiom: cmpi.w #N,Dn ; bhi.w dflt ; lea T(pc),Ax ; adda.w (Ax,Dn.w*2),Ax ; jmp (Ax)
        m = re.match(r'^\(a(\d)\)$', insn.op_str)
        if not m: return None
        ax = m.group(1)
        # scan back up to 5 instructions via insn_at
        addrs = sorted(a for a in self.insn_at[seg] if pc - 24 <= a < pc)
        seq = [self.insn_at[seg][a] for a in addrs]
        if len(seq) < 2: return None
        adda, lea = seq[-1], seq[-2]
        if not (adda.mnemonic.startswith('adda.w') and re.match(rf'^\(a{ax}, d(\d)\.w \* 2\), a{ax}$', adda.op_str)):
            return None
        if not (lea.mnemonic.startswith('lea') and 'pc' in lea.op_str):
            return None
        tbl = self.target(lea)
        n = None
        for q in reversed(seq[:-2]):
            mm = re.match(r'^#\$([0-9a-f]+), d\d$', q.op_str)
            if q.mnemonic.startswith('cmp') and mm:
                n = int(mm.group(1), 16) + 1; break
        if n is None or n > 512: return None
        if tbl is None or tbl < 0 or tbl + 2 * n > len(code):
            raise ValueError(f'invalid switch table at {seg}:{pc:#x}')
        out = []
        for k in range(n):
            d = struct.unpack_from('>h', code, tbl + 2 * k)[0]
            target = tbl + d
            if target & 1 or not 0 <= target < len(code) - 1:
                raise ValueError(f'invalid switch target at {seg}:{pc:#x}')
            out.append(target)
        self.seen[seg].update(range(tbl, tbl + 2 * n))
        return out

    @staticmethod
    def target(insn):
        for op in ops(insn):
            if op.type == M68K_OP_BR_DISP:
                return insn.address + 2 + op.br_disp.disp
            if op.type == M68K_OP_MEM and op.address_mode == M68K_AM_PCI_DISP:
                return insn.address + 2 + op.mem.disp
        return None

def run(extra=False):
    W = Walker()
    per = collections.defaultdict(list)
    for s, o in JT: per[s].append(o)
    for s in sorted(CODE):
        W.walk(s, per.get(s, []))
    if extra:
        # second pass: pc-relative LEA/PEA targets that look like code, iterate
        for _ in range(5):
            added = False
            for s in sorted(CODE):
                new = [t for t in W.codeptrs[s] if t not in W.seen[s] and 0 <= t < len(CODE[s]) - 1
                       and CODE[s][t:t+2] in (b'\x4e\x56', b'\x48\xe7', b'\x2f\x0b', b'\x2f\x0a')]
                if new:
                    added = True; W.walk(s, new)
            if not added: break
    return W

def run_live():
    g, below, offsets = data_roots()
    W = Walker()
    roots = list(range(10)) + [69]   # CODE1 header +$0C -> A5+$24A = JT69 (main)
    for o in offsets:
        if o & 1: continue
        v = struct.unpack_from('>I', g, (o & ~1) + below)[0]
        v = v - (1 << 32) if v >= 1 << 31 else v
        j = jt_index(v)
        if j is not None: roots.append(j)
    # Original CODE 1+$043E installs LoadSeg/UnLoadSeg through emitted JSR
    # stubs. Both handlers start by dropping that JSR return address, so the
    # prologue heuristic misses them. M0.2's log executes their traps too.
    # The cached flush targets likewise require explicit byte-checked roots.
    for pc, expected in ((0x60, '588f48e7fff8'), (0xcc, '588f206f0004'),
                         (0x21e, '203a000a2040'), (0x26e, 'a0bd4e75')):
        if CODE[1][pc:pc + len(expected)//2].hex() != expected:
            raise ValueError(f'CODE 1 / runtime-installed entry bytes at {pc:#x}')
        W.walk(1, [pc])
    W.pending.extend(roots)
    done = set()
    while W.pending:
        j = W.pending.pop()
        if j in done: continue
        done.add(j)
        s, o = JT[j]
        W.walk(s, [o])
        if not W.pending:
            for sg in sorted(CODE):
                new = [t for t in W.codeptrs[sg] if t not in W.seen[sg] and 0 <= t < len(CODE[sg]) - 1
                       and CODE[sg][t:t+2] in (b'\x4e\x56', b'\x48\xe7')]
                if new:
                    W.ptr_roots.extend((sg, t) for t in new)
                    W.walk(sg, new)
    W.live_jt = done
    return W


def data_roots():
    """Expand DATA/ZERO only to discover DREL function pointers (not relocation)."""
    below = struct.unpack_from('>I', R[(b'CODE', 0)].body, 4)[0]
    data, zero = R[(b'DATA', 0)].body, R[(b'ZERO', 0)].body
    g = bytearray(below)
    pos = di = zi = 0
    while pos < below:
        if di + 2 > len(data):
            raise ValueError('DATA exhausted')
        word = data[di:di + 2]
        di += 2
        g[pos:pos + 2] = word
        pos += 2
        if word == b'\0\0':
            count = struct.unpack_from('>H', zero, zi)[0]
            zi += 2
            pos += count
        if pos > below:
            raise ValueError('DATA/ZERO overflow')
    if di != len(data) or zi != len(zero):
        raise ValueError('DATA/ZERO unconsumed bytes')
    drel = R[(b'DREL', 0)].body
    offsets = []
    i = 0
    while i < len(drel):
        word = struct.unpack_from('>h', drel, i)[0]
        i += 2
        if word >= 0:
            word = -((word << 16) | struct.unpack_from('>H', drel, i)[0])
            i += 2
        if not 0 <= (word & ~1) + below <= below - 4:
            raise ValueError('DREL out of bounds')
        offsets.append(word)
    return g, below, offsets


def last_d0(ctx):
    for c in reversed(ctx):
        if c.startswith('_') or BR.match(c.split(' ')[0].split('.')[0]): return None
        m=re.match(r'^(moveq|move\.l|move\.w) #(-?\$?[0-9a-f]+), d0',c)
        if m: return m.group(2)
        if re.search(r'\bd0\b', c) and not c.startswith(('cmp', 'tst')): return None
    return None

MGR=[
 ('Segment Loader / Trap Mgr / System', lambda w,n: n in ('LoadSeg','UnloadSeg','ExitToShell','GetTrapAddress','SetTrapAddress','GetOSTrapAddress','GetToolTrapAddress','SysError','Debugger','DebugStr','SysEnvirons','Gestalt','HWPriv','vCacheFlush','StripAddress','SysBeep','OSDispatch','AliasDispatch','Pack2(autopop)','DECSTR68K','FP68K')),
 ('Memory Manager', lambda w,n: n in ('SetZone','GetZone','FreeMem','DisposePtr','SetPtrSize','GetPtrSize','DisposeHandle','SetHandleSize','GetHandleSize','HLock','HUnlock','SetApplLimit','BlockMove','MoreMasters','HPurge','HNoPurge','CompactMem','MaxApplZone','MoveHHi','HGetState','HSetState','NewPtr','NewHandle','NewPtrClear','NewHandleClear','NewPtrSys','PtrToHand','RecoverHandle')),
 ('File Manager', lambda w,n: (w & 0x800)==0 and re.match(r'^(H?(Open|Close|Read|Write|Create|Delete|GetFileInfo|SetFileInfo|GetEOF|SetEOF|FlushVol|GetVol|SetVol|SetFPos|GetVInfo|OpenRF)|FSDispatch|HFSDispatch|OpenRF)',n) is not None),
 ('Resource Manager', lambda w,n: n in ('HOpenResFile','HCreateResFile','Get1Resource','Get1NamedResource','DetachResource','CurResFile','OpenResFile','UseResFile','CloseResFile','SetResLoad','GetResource','GetNamedResource','ReleaseResource','GetResInfo','ChangedResource','AddResource','RmveResource','ResError','WriteResource','CreateResFile','OpenRFPerm','OpenResFile','CloseResFile','WriteResource')),
 ('Sound / MIDI Manager', lambda w,n: n.startswith('Sound') or n.startswith('Snd')),
 ('Vertical Retrace Mgr', lambda w,n: n in ('VInstall','VRemove')),
 ('Event Mgr / OS events', lambda w,n: n in ('FlushEvents','WaitNextEvent','GetNextEvent','GetMouse','StillDown','Button','TickCount','GetKeys','SystemClick','SystemTask','Pack8')),
 ('QDOffscreen (GWorld)', lambda w,n: n=='QDExtensions'),
 ('Color QuickDraw / GDevice', lambda w,n: w>=0xAA00 and w<0xAA40),
 ('Palette Manager', lambda w,n: n in ('NewPalette','ActivatePalette','SetPalette','PaletteDispatch')),
 ('Window Manager', lambda w,n: w in range(0xA910,0xA930) or n=='GetNewCWindow'),
 ('Menu Manager', lambda w,n: w in range(0xA930,0xA952) or n=='GetRMenu'),
 ('Control/Dialog Manager', lambda w,n: w in range(0xA95D,0xA99A) or n in ('SelectDialogItemText',)),
 ('Desk/Scrap/TextEdit', lambda w,n: n in ('OpenDeskAcc','SysEdit','TEInit','TECopy','TECut','TEPaste','ZeroScrap','GetScrap','PutScrap')),
 ('Cursor/Font/Utility', lambda w,n: n in ('InitCursor','SetCursor','ObscureCursor','GetCursor','Random','HiWord','InitFonts','GetFNum','TrackBox','SetPt')),
 ('QuickDraw (classic)', lambda w,n: w>=0xA800),
]
def mgr(w):
    n=trapname(w)
    for m,f in MGR:
        if f(w,n): return m
    return 'Other'
SELNAME={
 0xAB1D:{'$80006':'SetGWorld','$80005':'GetGWorld','$40017':'GetGWorldPixMap','$40001':'LockPixels','$40002':'UnlockPixels','$160000':'NewGWorld','$4000f':'GetPixBaseAddr','$40004':'DisposeGWorld'},
 0xA800:{'$40004':'MIDISignIn','$1c0004':'MIDIAddPort','$4c0004':'MIDIRemovePort','$80004':'MIDISignOut','$c0008':'SndSoundManagerVersion'},
 0xAAA2:{'$a13':'SetDepth','$a14':'HasDepth','$40d':'SaveFore','$40f':'RestoreFore'},
 0xA260:{'$1':'PBOpenWD','$2':'PBCloseWD','$7':'PBGetWDInfo','$8':'PBGetFCBInfo','$9':'PBGetCatInfo','$30':'PBHGetVolParms','$1a':'PBHOpenDF'},
 0xA660:{'$1':'PBOpenWD async','$2':'PBCloseWD async','$7':'PBGetWDInfo async','$8':'PBGetFCBInfo async'},
 0xA060:{'$1a':'PBHOpenDF'},
 0xA816:{'$91f':'AEInstallEventHandler','$812':'AEGetParamDesc','$407':'AECountItems','$100a':'AEGetNthPtr','$21b':'AEProcessAppleEvent'},
 0xA823:{'$0':'FindFolder'},
 0xA198:{'$1':'FlushInstructionCache','$3':'FlushDataCache'},
}

def report(walker, base):
    live, exported = collections.defaultdict(list), collections.defaultdict(list)
    for s, pc, word, ctx in walker.traps:
        live[word].append((s, pc, ctx))
    for s, pc, word, ctx in base.traps:
        exported[word].append((s, pc, ctx))
    lines = ['# Trap census', '',
             f'Live sites: {len(walker.traps)}; distinct trap words: {len(live)}.',
             'Live roots: CODE 1, main, DATA pointers and referenced code.',
             'JT includes all exported jump-table entries, including unreached library code.',
             'Offsets include CODE headers. Selectors are local static evidence; unknown stays unknown.', '']
    for manager in [name for name, _ in MGR] + ['Other']:
        words = [w for w in sorted(set(live) | set(exported)) if mgr(w) == manager]
        if not words:
            continue
        lines += [f'## {manager}', '', '| Trap | Name | Live | JT | Live selectors (D0) |',
                  '| --- | --- | ---: | ---: | --- |']
        for word in words:
            selectors = ''
            if word in SELNAME:
                counts = collections.Counter(last_d0(ctx) for _, _, ctx in live[word])
                selectors = '; '.join(f'{SELNAME[word].get(k, k or "UNKNOWN")} ({k or "UNKNOWN"}) ×{n}'
                                      for k, n in sorted(counts.items(), key=lambda x: str(x[0])))
            lines.append(f'| ${word:04X} | {trapname(word)} | {len(live[word])} | {len(exported[word])} | {selectors} |')
        lines.append('')
    lines += ['## Live sites', '', '| Segment | Offset | Trap | Name |', '| --- | --- | --- | --- |']
    for s, pc, word, _ in sorted(walker.traps):
        lines.append(f'| {seg_label(s)} | ${pc:04X} | ${word:04X} | {trapname(word)} |')
    lines += ['', '## Unresolved static transfers / decode stops', '',
              'These require runtime evidence; they are not silently treated as covered.', '']
    for s, pc, reason in sorted(walker.blind):
        lines.append(f'- ({seg_label(s)}, ${pc:04X}): `{reason}`')
    return '\n'.join(lines) + '\n'


def selftest():
    global CODE, RELOC, JT, SEGNAME
    CODE = {1: bytes.fromhex('6604 a001 4e75 a002 4e75')}
    RELOC = {1: {}}
    JT = []
    SEGNAME = {1: 'fixture'}
    w = Walker(); w.walk(1, [0])
    assert {(pc, trap) for _, pc, trap, _ in w.traps} == {(2, 0xa001), (6, 0xa002)}
    CODE = {1: bytes.fromhex('4eb9 00000022 a001 4e75'), 2: bytes.fromhex('a002 4e75')}
    RELOC = {1: {2: 'A5'}, 2: {}}
    JT = [(2, 0)]
    w = Walker(); w.walk(1, [0])
    assert w.pending == [0]
    w.walk(2, [0])
    assert {trap for _, _, trap, _ in w.traps} == {0xa001, 0xa002}
    assert not w.lowmem
    # cmpi.w #1,d0; bhi default; lea table(pc),a1;
    # adda.w (a1,d0.w*2),a1; jmp (a1); table; two cases; default.
    CODE = {1: bytes.fromhex('0c400001 6216 43fa0008 d2f10200 4ed1 00040008 a0014e75 a0024e75 a0034e75')}
    RELOC = {1: {}}
    w = Walker(); w.walk(1, [0])
    assert w.switches == [(1, 14, 2)]
    assert {pc for _, pc, _, _ in w.traps} == {20, 24, 28}
    assert last_d0(['move.l #$80006, d0']) == '$80006'
    assert last_d0(['move.l #$80006, d0', '_AnyTrap']) is None
    print('PASS trap-census-selftest branch=2 crel_jsr=1 switch=3 selector=2')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('resource', nargs='?', default='tmp/runtime-data/Alone In The Dark')
    parser.add_argument('--names', default='tmp/trap_names.lua')
    parser.add_argument('--output', default='tmp/trap-census.md')
    parser.add_argument('--selftest', action='store_true')
    args = parser.parse_args()
    if args.selftest:
        selftest()
        return
    global NAMES
    NAMES = {int(a, 16): b for a, b in re.findall(r'\[0x([0-9A-F]+)\] = "(\w+)"', Path(args.names).read_text())}
    if len(NAMES) < 500:
        raise ValueError('TRAP NAMES / incomplete generated table')
    load(args.resource)
    live, base = run_live(), run()
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(report(live, base))
    counts = len(live.traps), len({t[2] for t in live.traps})
    if counts != (1129, 244):
        raise ValueError(f'CENSUS BASELINE / expected (1129, 244), got {counts}; inspect {output}')
    print(f'PASS trap-census sites={counts[0]} distinct={counts[1]} unresolved={len(live.blind)} report={output}')


if __name__ == '__main__':
    main()
