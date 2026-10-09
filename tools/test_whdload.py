#!/usr/bin/env python3
"""Run isolated WHDLoad tests and retain its own core dumps under tmp/.

Source amiga/env.sh first. ROMs and original data are local inputs, never shipped.
Use QUITPROBE=1 for quit, FILEPROBE=1 for file-read, SAVELOAD=1 for save-load,
and LOADONLY=1 for load-save; EXPLOREROUTE=1 INTROSKIP=1 for stairs;
ESCAPEPROBE=1 for escape.
timed uses production. Always clean-build flags.
"""
import argparse
import platform
import os
from pathlib import Path
import shutil
import struct
import subprocess
import local_temp as tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
SHARE = Path.home()/'.local/share/amiga'

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--mode', choices=('smoke', 'boot', 'load', 'quit', 'timed', 'stairs', 'escape', 'file-read', 'save-load', 'load-save'), default='quit')
    p.add_argument('--whdload', type=Path,
                   default=Path(os.environ.get('WHDLOAD', SHARE/'WHDLoad'))/'C/WHDLoad')
    p.add_argument('--workbench', type=Path,
                   default=Path(os.environ.get('WORKBENCH_ADF', SHARE/'Workbenchv2.04rev37.67Workbench.adf')))
    p.add_argument('--rom', type=Path, default=Path(os.environ.get('KICKSTART', SHARE/'Kickstarts/kick40063.A600')))
    p.add_argument('--rtb', type=Path, default=os.environ.get('KICKSTART_RTB'))
    p.add_argument('--host-rom', type=Path, default=Path(os.environ.get('WHDLOAD_HOST_KICKSTART', SHARE/'Kickstarts/kick40068.A1200')))
    p.add_argument('--exe', type=Path, default=ROOT/'amiga/out/AloneInTheDark.exe')
    p.add_argument('--seconds', type=int, default=90, help='host safety ceiling')
    p.add_argument('--ticks', type=int, default=1500, help='WHDLoad timeout in PAL fields')
    p.add_argument('--cpu', default='68030')
    p.add_argument('--jit', action='store_true', help='enable JIT for explicit reproduction runs')
    p.add_argument('--no-warp', action='store_true', help='run at normal PAL field rate')
    p.add_argument('--save-source', type=Path, help='Saved Games drawer from a preceding run')
    p.add_argument('--no-preload', action='store_true')
    p.add_argument('--check-stack', action='store_true', help='require completed STACKPROBE report and 4 KB process stack')
    args = p.parse_args()
    if args.rtb is None:
        args.rtb = Path(str(args.rom)+'.RTB')
    slave = {'smoke':'Smoke.slave', 'boot':'BootTest.slave', 'load':'LoadTest.slave'}.get(args.mode, 'AloneInTheDark.slave')
    base = Path(tempfile.mkdtemp(prefix='whdload-test-', dir=ROOT/'tmp'))
    print('Fixture:', base, flush=True)
    boot, game = base/'boot', base/'game'
    for d in (boot/'s', boot/'devs/Kickstarts', game, base/'state'):
        d.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(args.whdload, game/'WHDLoad')
    shutil.copyfile(ROOT/'build/whdload'/slave, game/'AloneInTheDark.slave')
    if args.mode != 'smoke':
        shutil.copyfile(args.rom, boot/'devs/Kickstarts'/args.rom.name)
        shutil.copyfile(args.rtb, boot/'devs/Kickstarts'/(args.rom.name+'.RTB'))
    if args.mode in ('load', 'quit', 'timed', 'stairs', 'escape', 'file-read', 'save-load', 'load-save'):
        shutil.copyfile(args.exe, game/'AloneInTheDark')
    if args.mode in ('quit', 'timed', 'stairs', 'escape', 'file-read', 'save-load', 'load-save'):
        (game/'Saved Games').mkdir();(game/'prefs').mkdir()
        subprocess.run(['bash', '-c', '. ./stage_original_data.sh; stage_aitd_original_data "$1"',
                        'stage', str(game)], cwd=ROOT/'amiga', check=True)
    if args.save_source:
        for path in args.save_source.iterdir():
            if path.is_file() and not path.name.endswith('.uaem'):
                shutil.copyfile(path,game/'Saved Games'/path.name)
    if args.mode == 'file-read':
        (game/'read-probe.bin').write_bytes(bytes((i*37+(i>>8))&255 for i in range(200003)))
    (boot/'s/WHDLoad.prefs').write_text('Expert\nReadDelay=0\n')
    preload = '' if args.no_preload else 'PRELOAD '
    filelog = '' if args.mode in ('stairs', 'escape') else 'FILELOG '
    (boot/'s/startup-sequence').write_text(
        'DF0:C/Assign C: DF0:C\nDF0:C/Assign LIBS: DF0:Libs\n'
        'DF0:C/Assign DEVS: DH0:devs\nStack 16384\nFailAt 999\nC:Avail >DH0:memory\n'
        f'CD DH1:\nWHDLoad AloneInTheDark.slave {preload}SPLASHDELAY=0 NOREQ COREDUMP {filelog}TIMEOUT={args.ticks} >DH0:result\n'
        'If WARN\nEcho failed >DH0:failed\nElse\nEcho passed >DH0:passed\nEndIf\n')
    arm=SHARE/'fs-uae-arm/fs-uae'
    emulator=os.environ.get('FSUAE',str(arm) if platform.machine()=='arm64' and arm.exists() else 'fs-uae')
    with (base/'emulator.log').open('w') as log:
        emu = subprocess.Popen([emulator, '--amiga_model=A4000', '--cpu='+args.cpu,
            '--uae_cpu_model='+args.cpu.split('-')[0], '--uae_cpu_24bit_addressing=false','--uae_mmu_model=0','--uae_fpu_model=0',
            '--uae_z3mapping=uae',
            '--jit_compiler='+str(int(args.jit)), '--chip_memory=2048', '--fast_memory=8192','--uae_z3mem_size=0','--uae_a3000mem_size=0','--uae_cpu_speed=max',
            '--kickstart_file='+str(args.host_rom),
            '--hard_drive_0='+str(boot), '--hard_drive_0_priority=10', '--hard_drive_1='+str(game),
            '--floppy_drive_0='+str(args.workbench),
            '--joystick_port_0=mouse', '--joystick_port_1=nothing', '--warp_mode='+str(int(not args.no_warp)), '--fullscreen=0',
            '--window_width=720', '--window_height=568', '--state_dir='+str(base/'state'),'--logs_dir='+str(base/'logs')], stdout=log, stderr=log)
        try:
            deadline = time.monotonic()+args.seconds
            while time.monotonic()<deadline and not any((boot/n).exists() for n in ('passed','failed')):
                if emu.poll() is not None:
                    raise RuntimeError('FS-UAE exited unexpectedly')
                if (boot/'result').exists() and (boot/'result').stat().st_size>8192: break
                time.sleep(.25)
            output = (boot/'result').open(errors='replace').read(512) if (boot/'result').exists() else ''
            report = (game/'.whdl_register').read_text(encoding='latin1') if (game/'.whdl_register').exists() else ''
            assert report, f'No WHDLoad core dump: {base}\n{output}'
            if args.mode in ('timed', 'stairs', 'escape'):
                assert 'DEBUG caused.' in report, report + output
                if args.mode == 'timed':
                    files = (game/'.whdl_log').read_text(encoding='latin1')
                    assert any('[ReadOff]' in line and 'name=data/Alone In The Dark' in line
                               for line in files.splitlines()), files
                    assert 'overlay.rsrc' not in files, 'Embedded overlay unexpectedly read from disk'
                assert not (game/'overlay.rsrc').exists()
                memory = (game/'.whdl_expmem').read_bytes()
                magic = b'AITDWHDR'
                assert memory.count(magic) == 1, 'Expected one loaded WHDLoad ABI block'
                offset = memory.index(magic) + len(magic)
                assert memory[offset:offset+4] == b'\0\1\0\0'
                assert int.from_bytes(memory[offset+4:offset+8], 'big') != 0
                print('PASS: WHDLoad resload ABI binding and embedded overlay verified')
                if args.mode == 'stairs':
                    assert memory.count(b'AITDSTRS') == 1, 'Expected stairs diagnostic report'
                    values = struct.unpack_from('>10I', memory, memory.index(b'AITDSTRS')+8)
                    stage,tick,frames,x,z,beta,animation,floor,room,track = values
                    print('STAIRS WHDLoad report:', values, flush=True)
                    assert stage == 19 and frames > 0, 'Stair route did not complete'
                    assert (animation,floor,room,track) == (4,1,6,1), 'No living manual storeroom actor'
                    print('PASS: WHDLoad ordinary attic descent to manual room 6')
                if args.mode == 'escape':
                    assert memory.count(b'AITDESCP') == 1, 'Expected Escape-menu report'
                    values = struct.unpack_from('>22I', memory, memory.index(b'AITDESCP')+8)
                    assert values[0] == 9, ('Escape sequence incomplete', values)
                    states = list(zip(values[2::2], values[3::2]))
                    print('ESCAPE WHDLoad tick/frame pairs:', states, flush=True)
                    assert all(b[0] > a[0] for a,b in zip(states,states[1:])), 'Guest time did not advance'
                    assert states[3][1] == states[2][1] and states[7][1] == states[6][1], 'Menu did not stay open'
                    assert states[5][1] > states[4][1] and states[9][1] > states[8][1], 'Gameplay did not resume'
                    print('PASS: WHDLoad Escape opens/closes menu with short and long holds')
            else:
                assert (boot/'passed').exists() and 'Return OK.' in report, report + output
                if args.mode == 'smoke':
                    assert (game/'smoke-passed').read_bytes() == b'PASS'
                if args.mode in ('save-load', 'load-save'):
                    memory = (game/'.whdl_expmem').read_bytes()
                    assert memory.count(b'AITDSAVE') == 1, 'Expected save/load report'
                    values = struct.unpack_from('>6I', memory, memory.index(b'AITDSAVE')+8)
                    assert values[0] == 6 and values[2] > 10000 and values[3] == 1, values
                    assert values[1] > 10000 if args.mode == 'save-load' else values[1] == 0, values
                    saves = [path for path in (game/'Saved Games').iterdir() if path.name == 'SAVE0.ITD']
                    assert len(saves) == 1 and saves[0].stat().st_size == 36254, 'Missing persisted original save'
                    if args.mode == 'load-save':
                        assert args.save_source and saves[0].read_bytes() == (args.save_source/'SAVE0.ITD').read_bytes()
                        print('PASS: fresh launch loaded previous run’s save without rewriting its data')
                    print(f'PASS: original Save, walk away, Load restores coordinates, Quit; written/read={values[1:3]}')
                if args.mode == 'file-read':
                    memory = (game/'.whdl_expmem').read_bytes()
                    assert memory.count(b'AITDFILE') == 1, 'Expected one completed file probe report'
                    values = struct.unpack_from('>13I', memory, memory.index(b'AITDFILE')+8)
                    assert values == (39,0,1,0,6,262168,65536,0,0,1,0,0,0), values
                    print('PASS: original read/seek/EOF/cache/CCR fixture, 262168 exact bytes, '
                          'six reads <=65536, zero OS windows, closed handles and restored Line-A')
                if args.check_stack:
                    memory = (game/'.whdl_expmem').read_bytes()
                    assert memory.count(b'AITDSTAK') == 1, 'Expected one stack probe report'
                    values = struct.unpack_from('>7I', memory, memory.index(b'AITDSTAK')+8)
                    process_size, process_used, mac_size, mac_used, song_used, deferred_used, done = values
                    assert done == 1 and process_size == 4096, values
                    assert 0 < process_used < process_size-512, values
                    assert 0 < mac_used < mac_size-512, values
                    assert song_used < 8192-512 and deferred_used < 8192-512, values
                    print(f'STACK process={process_used}/{process_size} Mac={mac_used}/{mac_size} '
                          f'song={song_used}/8192 deferred={deferred_used}/8192')
                print(f'PASS: {args.mode} slave returned normally; WHDLoad core saved')
        finally:
            emu.terminate()
            try: emu.wait(timeout=5)
            except subprocess.TimeoutExpired: emu.kill(); emu.wait()

if __name__ == '__main__':
    main()
