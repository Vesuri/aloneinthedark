#!/usr/bin/env python3
"""Sanitized song-format fixtures and optional original preflight comparison."""
import argparse,os,re,subprocess,tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def check_clock(text,status,decoded):
    if status!=0 or any(x in text for x in ('FAIL','LUA ERROR','timeout','Error in')) or text.count('PASS original song clock events=3736 steps=8785')!=1 or text.count('Exited via the debugger')!=1:
        raise ValueError('original clock completion')
    notes=re.findall(r'^SONG_CLOCK_EVENT n=(\d+) on=(\w+) offset=(\w+) instrument=(\w+) note=(\w+) velocity=(\w+) channel=(\w+) sequence=(\w+) tick=\w+ step=(\w+) countdown=\w+$',text,re.M)
    events=re.findall(r'^SONG_EVENT n=(\d+) on=(\w+) offset=(\w+) instrument=(\w+) note=(\w+) velocity=(\w+) channel=(\w+)$',decoded,re.M)
    timed=re.findall(r'^SONG_TIMED_EVENT n=(\d+) offset=(\w+) pulse=(\w+) step=(\w+)$',decoded,re.M)
    if len(notes)!=3736 or [n[:7] for n in notes]!=events or [(n[0],n[2],n[7],n[8]) for n in notes]!=timed:
        raise ValueError('complete timed note stream')
    print('PASS song clock: 3736 exact live notes at original sequencer steps through pulse 8785')

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--reference',type=Path);p.add_argument('--status',type=int)
    p.add_argument('--driver',type=Path);p.add_argument('--driver-status',type=int)
    p.add_argument('--clock',type=Path);p.add_argument('--clock-status',type=int)
    a=p.parse_args()
    if a.clock and not a.reference: raise ValueError('clock requires original inputs')
    with tempfile.TemporaryDirectory(prefix='aitd-song-') as directory:
        work=Path(directory);exe=work/'check'
        subprocess.run([os.environ.get('HOST_CXX','c++'),'-std=c++17','-Wall','-Wextra','-Werror','-fsanitize=address,undefined',str(ROOT/'tools/test_song_inputs.cpp'),'-o',str(exe)],check=True)
        if not a.reference:
            subprocess.run([str(exe)],check=True,timeout=30);return
        text=a.reference.read_text()
        if a.status!=0 or any(x in text for x in ('FAIL','LUA ERROR','timeout','Error in')) or text.count('PASS original song preflight events=3736')!=1 or text.count('Exited via the debugger')!=1:
            raise ValueError('original event completion')
        from check_driver0 import check
        if not a.driver: raise ValueError('missing original ownership capture')
        check(a.driver.read_text(),a.driver_status)
        from resource_fork import read_resource_fork
        resources={(r.kind,r.rid):r.body for r in read_resource_fork(ROOT/'tmp/runtime-data/Alone In The Dark')}
        song=ROOT/'tmp/song-events-song.bin';midi=ROOT/'tmp/song-events-midi.bin'
        if song.read_bytes()!=resources[b'SONG',135] or midi.read_bytes()!=resources[b'MIDI',905]: raise ValueError('captured song/MIDI payload')
        for (kind,rid),body in resources.items():
            if kind in (b'INST',b'snd '): (work/f'{kind.decode().strip()}_{rid}').write_bytes(body)
        run=subprocess.run([str(exe),str(song),str(midi),str(work)],text=True,capture_output=True,timeout=30)
        if run.returncode: raise ValueError(run.stderr.strip() or 'native host fixture failed')
        result=run.stdout
        reference=re.findall(r'^SONG_EVENT .*$',text,re.M);decoded=re.findall(r'^SONG_EVENT .*$',result,re.M)
        if len(reference)!=3736 or reference!=decoded: raise ValueError('complete note/instrument event stream')
        if a.clock: check_clock(a.clock.read_text(),a.clock_status,result)
        ids=list(map(int,re.findall(r'^SONG_INSTRUMENT id=(\d+)',result,re.M)))
        state=(ROOT/'tmp/song-events-state.bin').read_bytes()
        if len(state)!=0x3048 or bytes(0 if i in ids else 255 for i in range(128))!=state[0x72:0xf2]: raise ValueError('instrument-use map')
        samples=list(map(int,re.findall(r'^SONG_SAMPLE id=(\d+)',result,re.M)))
        driver=a.driver.read_text();calls=re.findall(r'^DRIVER0_SERVICE_ENTER .*?trap=A9A0 .*?args=(\w+)',driver,re.M)
        original=[int(raw[:4],16) for raw in calls if bytes.fromhex(raw[4:12])==b'snd ']
        if len(samples)!=28 or samples!=original: raise ValueError('sample dependency order')
        if result.count('PASS song resource graph instruments=7 samples=28')!=1: raise ValueError('complete resource graph')
        print('PASS song inputs: 3736 exact original note events, original payloads, 7 instruments/28 samples and bounded format fixtures')
if __name__=='__main__':
    try:main()
    except (ValueError,OSError,KeyError,subprocess.SubprocessError) as error:raise SystemExit('FAIL song inputs: '+str(error))
