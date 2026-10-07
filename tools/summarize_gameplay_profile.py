#!/usr/bin/env python3
"""Exclusive statistical accounting of gameplay PC samples (not nested timers)."""
import argparse,json,re
from collections import Counter
from pathlib import Path

def summarize(folder):
    segments=[]
    for line in (folder/'segments.txt').read_text().splitlines():
        _,index,name,begin,end=line.split();begin,end=int(begin,16),int(end,16)
        if begin and end>begin:segments.append((begin,end,name))
    samples=[]
    for line in (folder/'samples.txt').read_text().splitlines():
        if line.startswith('S '):
            fields=line.split();samples.append({'pc':int(fields[1],16),'room':int(fields[4]),'camera':int(fields[5]),'bt':[]})
        elif samples and line.lstrip().startswith('#'):samples[-1]['bt'].append(line)
    if not samples:raise ValueError('no samples')
    counters=(folder/'counters.txt').read_text()
    m=re.search(r'fields=(\d+) presented=(\d+) scenes=(\d+) ticks=(\d+)',counters)
    if not m:raise ValueError('missing completed interval')
    fields,presented,scenes,ticks=map(int,m.groups())
    if fields<=0 or scenes<=0:raise ValueError('empty interval')
    if any(s['room']!=3 for s in samples):raise ValueError('left the measured idle room')
    counts=Counter();leafs=Counter()
    names_rx=re.compile(r'#\d+\s+(?:0x[0-9a-f]+ in )?([^\s(]+) \(')
    for sample in samples:
        names=[m.group(1) for line in sample['bt'] for m in [names_rx.search(line)] if m and m.group(1)!='??']
        nameset=set(names);leaf=names[0] if names else 'unknown';leafs[leaf]+=1
        def has(*parts):return any(any(part in name for part in parts) for name in nameset)
        if any(begin<=sample['pc']<end for begin,end,_ in segments):phase='Original game code'
        elif has('aitdSongInterrupt','advanceNativeSong','advanceOwnedNativeSong','musicInterrupt','aitd_song_vbi','aitdSongDeferred','playSongNote'):phase='Audio sequencer/interrupt'
        elif has('vbiServer','windowVBI','vbiUpdate','vbiHandler'):phase='Display/input interrupt'
        elif has('aitdSystemWindow','readResourceDOS','fileReadDOS','openResourceDOS'):phase='System windows / I/O'
        elif has('c2p1x1_8_c5_gen','aitdKalmsC2PRect'):phase='C2P'
        elif has('AgaPalette','convertPalette'):phase='Palette'
        elif has('CopyBits8::','copyPortBits8'):phase='CopyBits'
        elif has('Line8::','lineGWorld','RegionExpand::','PolygonRegion::','paintPort','FramePoly','RectBounds::intersect'):phase='Drawing traps / geometry'
        elif has('AitdScreen::presentMacFrame','Planar8::','queueFrame'):phase='Other display / synchronization'
        elif names:phase='Other native / trap services'
        else:phase='Unresolved / OS'
        counts[phase]+=1
    categories=['Original game code','Drawing traps / geometry','CopyBits','C2P','Palette','Audio sequencer/interrupt','System windows / I/O','Display/input interrupt','Other display / synchronization','Other native / trap services','Unresolved / OS']
    elapsed_ms=fields*20;frame_ms=elapsed_ms/scenes;n=len(samples)
    rows=[dict(phase=phase,samples=counts[phase],percent=100*counts[phase]/n,ms_per_frame=frame_ms*counts[phase]/n) for phase in categories]
    assert sum(row['samples'] for row in rows)==n
    return dict(samples=n,fields=fields,scenes=scenes,elapsed_ms=elapsed_ms,ms_per_frame=frame_ms,phases=rows,leaves=leafs.most_common(30))

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('folder',type=Path);a=p.parse_args()
    try:result=summarize(a.folder)
    except (ValueError,OSError) as e:raise SystemExit('FAIL gameplay profile: '+str(e))
    print(json.dumps(result,indent=2))
