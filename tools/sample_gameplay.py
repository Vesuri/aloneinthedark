#!/usr/bin/env python3
"""Statistical PC sampler: interrupt the FS-UAE gdb stub at random host
intervals. Emulated time is frozen while stopped, so these are statistical estimates. Host-time sampling can be biased by
emulator throughput; repeat runs and retain an unresolved category."""
import argparse, os, queue, random, re, signal, subprocess, sys, threading, time

ap = argparse.ArgumentParser()
ap.add_argument('--gdb'); ap.add_argument('--elf'); ap.add_argument('--connect')
ap.add_argument('--setup'); ap.add_argument('--out'); ap.add_argument('--samples', type=int)
ap.add_argument('--settle', type=int, default=200, help='fields to run after load before sampling')
ap.add_argument('--load-timeout', type=float, default=900)
a = ap.parse_args()

p = subprocess.Popen([a.gdb, '-q', '-nx', '-x', a.connect, '-x', a.setup, a.elf],
                     stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                     text=True, errors="replace", bufsize=1)
q = queue.Queue()
log = open(os.path.join(a.out, 'gdb.log'), 'w')
def reader():
    for line in p.stdout:
        log.write(line); log.flush(); q.put(line.rstrip('\n'))
    q.put(None)
threading.Thread(target=reader, daemon=True).start()

def wait_for(pat, timeout):
    end = time.time() + timeout; rx = re.compile(pat); got = []
    while True:
        try: line = q.get(timeout=max(0.01, end - time.time()))
        except queue.Empty: raise SystemExit(f'timeout waiting for {pat}')
        if line is None: raise SystemExit('gdb exited')
        got.append(line)
        if rx.search(line): return got
        if 'LOUDSTOP' in line: print(line); raise SystemExit('loud stop')

marker = 0
def cmd(text, timeout=60):
    global marker; marker += 1
    p.stdin.write(text + f'\necho @@{marker}\\n\n'); p.stdin.flush()
    got = wait_for(rf'@@{marker}$', timeout)
    return [l.replace('(gdb) ', '') for l in got[:-1]]

def run_and_interrupt(delay):
    p.stdin.write('continue\n'); p.stdin.flush()
    wait_for(r'Continuing\.', 30)
    time.sleep(delay)
    os.kill(p.pid, signal.SIGINT)
    lines = wait_for(r'SIGINT|signal|stopped|Breakpoint', 60)
    for l in lines:
        if 'LOUDSTOP' in l: raise SystemExit(l)

loaded=wait_for(r'LOADED stage=', a.load_timeout)
if not any('LOADED stage=5' in line for line in loaded):raise SystemExit('FAIL ordinary Load checkpoint')
COUNT = 'printf "C %u %u %u %u\\n",g_vbiCount,g_macFramesPresented,g_macSceneFramesCompleted,g_macTicks'
def counters():
    for l in cmd(COUNT):
        if l.startswith('C '): return list(map(int, l.split()[1:]))
c0 = counters()
# settle: run in host-time chunks until enough fields elapsed
while (counters()[0] - c0[0]) % 65536 < a.settle:
    run_and_interrupt(0.5)
start = counters()
segs = []
seg_count = next(int(line.split()[1]) for line in cmd('printf "SEGC %u\\n",sizeof(s_segments)/sizeof(s_segments[0])') if line.startswith("SEGC "))
for i in range(seg_count):
    r = cmd(f'printf "SEG {i} %s %x %x\\n",s_segments[{i}].name,s_segments[{i}].begin,s_segments[{i}].end')
    for l in r:
        if l.startswith('SEG') and len(l.split()) == 5: segs.append(l)
    if any('No symbol' in l or 'Cannot' in l for l in r): break
with open(os.path.join(a.out, 'segments.txt'), 'w') as f: f.write('\n'.join(segs) + '\n')
textlo, texthi = None, None
for l in subprocess.run(['m68k-amiga-elf-objdump', '-h', a.elf], capture_output=True, text=True).stdout.splitlines():
    m = re.match(r'\s*\d+\s+\.text\s+([0-9a-f]+)\s+([0-9a-f]+)', l)
    if m: textlo = int(m.group(2), 16); texthi = textlo + int(m.group(1), 16)
out = open(os.path.join(a.out, 'samples.txt'), 'w')
t0 = time.time()
for n in range(a.samples):
    run_and_interrupt(random.uniform(0.02, 0.09))
    r = cmd('printf "S %x %x %x %u %u\\n",$pc,$sr,$sp,*(unsigned short*)(s_a5WorldStorage+75616-0xb292+160+0x30),*(unsigned short*)(s_a5WorldStorage+75616-0xcd70)')
    s = next((l for l in r if l.startswith('S ')), None)
    if not s: continue
    pc = int(s.split()[1], 16)
    bt = []
    # Native ELF code is linked at 0 and relocated by the hunk loader; let gdb decide.
    r = cmd('bt 12', timeout=30)
    bt = [l for l in r if l.startswith('#')]
    out.write(s + '\n' + ''.join('  ' + l + '\n' for l in bt)); out.flush()
    if n % 100 == 0: print(f'{n} samples {time.time()-t0:.0f}s', flush=True)
end = counters()
with open(os.path.join(a.out, 'counters.txt'), 'w') as f:
    f.write(f'start {start}\nend {end}\n')
    fields = (end[0] - start[0]) % 65536
    f.write(f'fields={fields} presented={end[1]-start[1]} scenes={end[2]-start[2]} ticks={end[3]-start[3]}\n')
    if fields: f.write(f'presented_fps={50*(end[1]-start[1])/fields:.2f} scene_fps={50*(end[2]-start[2])/fields:.2f}\n')
print(open(os.path.join(a.out, 'counters.txt')).read())
p.stdin.write('kill\nquit\n'); p.stdin.flush()
try: p.wait(10)
except Exception: p.kill()
