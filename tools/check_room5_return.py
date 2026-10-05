#!/usr/bin/env python3
"""Verify post-combat wardrobe interaction, actual hallway return and active time."""
import argparse
from pathlib import Path
import re
import struct
from check_menu_keyboard import require
from check_room5_combat import check as check_combat, records


def check(mac, native, folder, mac_status, native_status):
    for name, log, status, marker in (
        ('Mac', mac, mac_status, 'PASS original room5 return: wardrobe Search, retained inventory and manual hallway'),
        ('Amiga', native, native_status, 'PASS ROOM5 return wardrobe Search, retained inventory and published manual hallway'),
    ):
        require(status == 0 and log.count(marker) == 1, name+' normal return completion')
        require(not re.search(r'FAIL|TIMEOUT|LUA ERROR|VP ERROR|Error in|Program received signal', log), name+' no observer failure')
    prefix='\n'.join(line for line in native.splitlines()
        if not (line.startswith('ROOM5_NATIVE stage=') and int(re.search(r'stage=(\d+)',line)[1])>23))
    check_combat(mac, prefix, folder, mac_status, native_status)
    rows=records(native, 'ROOM5_NATIVE');states={r['stage']:r for r in rows}
    returned=records(native, 'ROOM5_RETURN');phases={r['stage']:r for r in returned}
    inputs=records(native,'RETURN_INPUT')
    require([r['stage'] for r in inputs]==[r['stage'] for r in returned] and all(r['dropped']==0 for r in inputs), 'native synthetic transitions never overflow input queue')
    require(inputs[-1]['openEvents']>=1, 'native actual delivered Open/Search event')
    require([r['stage'] for r in returned]==list(range(1,21))+[21,22,23]+list(range(24,49)), 'all return controller phases once')
    require(all(states[s]['var90']==64 for s in range(26,49)), 'native actual Open/Search selection before movement and retained')
    require(all(phases[s]['floor']==1 and phases[s]['room']==5 for s in range(24,47)), 'native wardrobe and doorway remain room5')
    require(phases[47]['floor']==1 and phases[47]['room']==1 and phases[48]['room']==1, 'native actual room5 to hallway transition')
    require(-280<=states[30]['z']<=-100 and 752<=states[31]['beta']<=784, 'native aligned wardrobe approach')
    require(-2400<=states[42]['x']<=-2200 and (states[43]['beta']<=16 or states[43]['beta']>=1008), 'native measured northern doorway alignment')
    require(states[48]['frames']>states[47]['frames'] and states[48]['anim']==4 and states[48]['track']==1, 'native later completed hallway manual publication')
    require(all(states[s]['npc']==-1 and states[s]['var20']==0 and states[s]['var57']==0 and states[s]['var21']==states[23]['var21'] for s in range(24,49)), 'native enemy remains removed and hero retains post-combat health')
    source={r['phase']:list(map(int,r['values'].split(','))) for r in records(mac,'ROOM5_VARS')}
    require(all(source[p][90]==64 for p in ('return-open-mode','wardrobe-search-after-combat','exit-door-open','returned-hallway')), 'original actual Open/Search selection')
    require(source['returned-hallway'][21]==source['room5-combat-result'][21]>0, 'original retained living health')
    for name, file in (
        ('Mac','hallway-session-lamp-use-returned-hallway-a5.bin'),
        ('Amiga','room5-native-48-a5.bin'),
    ):
        data=(folder/file).read_bytes();require(len(data)==75616,name+' final A5 extent')
        w=lambda o:struct.unpack_from('>h',data,75616+o)[0]
        hero=-0xb292+160;enemy=-0x115f2+62*52;lamp=-0x115f2+13*52
        require(tuple(w(hero+i) for i in (0,2,0x2e,0x30,0x3e,0x52))==(1,12,1,1,4,1),name+' final living manual hallway hero')
        require(tuple(w(enemy+i) for i in (0,28,30))==(-1,-1,-1),name+' retained enemy removal')
        require(tuple(w(i) for i in (-0xd8a6,-0xd8a4,-0xd8a2,-0xd8a8))==(2,2,13,2),name+' retained Actions/lamp inventory')
        require(tuple(w(lamp+i) for i in (12,28,30))==(-31223,-1,-1),name+' retained lamp ownership')
    activity=records(mac,'ACTIVE_GAMEPLAY_FINAL');require(len(activity)==1,'one original active-time result')
    a=activity[0];b=phases[48]
    for name,total,move,turn,kick,samples in (
        ('Mac',a['ticks'],a['move'],a['turn'],a['kick'],a['samples']),
        ('Amiga',b['activity'],b['move'],b['turn'],b['kick'],b['samples']),
    ):
        require(total==move+turn+kick and min(move,turn,kick)>0 and samples<=total<=2*samples, name+' conservative active movement/turn/kick accounting')
    require(all(y['activity']>=x['activity'] for x,y in zip(returned,returned[1:])), 'native active-time monotonic')
    require(phases[23]['activity']==phases[24]['activity']==phases[25]['activity'], 'native mode-change hold and idle waits contribute zero activity')
    pixels=(folder/'room5-native-48-screen.bin').read_bytes()
    require(len(pixels)==307200 and len(set(pixels))>32 and len((folder/'room5-native-48-clut.bin').read_bytes())==2056, 'native final populated scene/palette extent')
    require(len((folder/'hallway-session-lamp-use-mac-returned-hallway-rgb.bin').read_bytes())==1228800, 'original final scene extent')
    print('PASS room5 return: Open/Search, wardrobe alignment, retained health/inventory/removal, actual room5 to room1 and later manual publication; active ticks Mac=%d Amiga=%d (not the ten-minute gate)'%(a['ticks'],b['activity']))


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('mac',type=Path);p.add_argument('native',type=Path)
    p.add_argument('--mac-status',type=int,required=True);p.add_argument('--native-status',type=int,required=True)
    p.add_argument('--folder',type=Path,default=Path('tmp/m3-room5-return'))
    a=p.parse_args()
    try:check(a.mac.read_text(),a.native.read_text(),a.folder,a.mac_status,a.native_status)
    except (ValueError,OSError,KeyError) as error:raise SystemExit('FAIL room5 return: '+str(error))
