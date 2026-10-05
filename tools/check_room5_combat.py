#!/usr/bin/env python3
"""Verify natural room5 enemy activation, actual attacks and completed removal."""
import argparse
from pathlib import Path
import re
import struct
from check_menu_keyboard import require
from check_south_rooms import check as check_prefix


def records(log, tag):
    return [dict((k, int(v) if re.fullmatch(r'-?\d+', v) else v)
                 for k, v in re.findall(r'(\w+)=([^ ]+)', line))
            for line in log.splitlines() if line.startswith(tag+' ')]


def check(mac, native, folder, mac_status, native_status):
    for label, log, status, marker in (
        ('Mac', mac, mac_status, 'PASS original room5 encounter: natural enemy, Fight, aiming, damage, death/removal and living manual gameplay'),
        ('Amiga', native, native_status, 'PASS ROOM5 encounter natural enemy, Fight, aiming, damage, death/removal and published living manual gameplay'),
    ):
        require(status == 0 and log.count(marker) == 1, label+' normal room5 completion')
        require(not re.search(r'FAIL|TIMEOUT|LUA ERROR|VP ERROR|Error in|Program received signal', log), label+' no observer failure')
    check_prefix(mac, native, folder, mac_status, native_status)
    values={r['phase']: list(map(int, r['values'].split(','))) for r in records(mac, 'ROOM5_VARS')}
    rows=records(native, 'ROOM5_NATIVE');states={r['stage']:r for r in rows}
    require([r['stage'] for r in rows if r['stage']!=21]==list(range(1,21))+[22,23], 'all native room5 approach/completion phases')
    require(any(r['stage']==21 for r in rows), 'native attack loop entered')
    source_initial=values['room5-encounter-start'];source_final=values['room5-combat-result']
    require(tuple(source_initial[i] for i in (20,21,55,56,57))==(1,20,1,1,10), 'original natural enemy counter/spawn/health')
    require(tuple(source_final[i] for i in (20,55,56,57,90))==(0,1,1,0,16) and source_final[21]>0, 'original death cleanup and living Fight-mode hero')
    require(tuple(states[1][k] for k in ('var20','var55','var56','var57'))==(1,1,1,10) and states[1]['npc']>=0, 'native natural enemy counter/spawn/health')
    # The slower approach can let the enemy hit before the combat controller's
    # first checkpoint. Hero health is timing-dependent, not a fixed start pose.
    require(0<states[1]['var21']<=20, 'native initially living hero within original health bound')
    require(all(0<r['var21']<=20 for r in rows) and
            all(b['var21']<=a['var21'] for a,b in zip(rows,rows[1:])) and
            states[23]['var21']<states[1]['var21'], 'native actual hero damage, no healing and survival')
    require(states[2]['var90']==16 and states[2]['fight']==1, 'native delivered and accepted Fight selection')
    require(states[20]['z']<=-650 or states[20]['var21']<20, 'native approach ends at target or measured enemy damage')
    require(any(r['var57']<10 and r['npc']>=0 for r in rows), 'native damage observed before enemy removal')
    require(any(v[57]<10 and v[57]>0 for p,v in values.items() if p.startswith('room5-kick-')), 'original damage observed before enemy removal')
    final=states[23]
    require(final['npc']==-1 and final['var20']==0 and final['var57']==0 and final['var21']>0 and final['var90']==16, 'native completed removal and living Fight-mode hero')
    require(final['anim']==4 and final['track']==1 and final['frames']>states[22]['frames'], 'native later completed manual gameplay frame')
    require(final['tick']>states[22]['tick']>states[21]['tick']>states[1]['tick'], 'native advancing encounter time')
    require(records(mac, 'ROOM5_KICK') and all(r['animation']==262 for r in records(mac, 'ROOM5_KICK')), 'actual original kicks observed')
    require(records(native, 'ROOM5_KICK') and all(r['animation']==262 for r in records(native, 'ROOM5_KICK')) and final['kicks']>0, 'actual native kicks observed')
    require(any(r['object']==62 and r['body']==73 and r['life']==84 and r['animation']==57 for r in records(mac, 'ROOM5_ENEMY')), 'original enemy death animation')
    for label, name in (
        ('Mac','hallway-session-lamp-use-room5-combat-result-a5.bin'),
        ('Amiga','room5-native-23-a5.bin'),
    ):
        data=(folder/name).read_bytes();require(len(data)==75616, label+' final A5 extent')
        w=lambda o:struct.unpack_from('>h',data,75616+o)[0]
        hero=-0xb292+160;enemy=-0x115f2+62*52
        require(tuple(w(hero+i) for i in (0,2,0x2e,0x30,0x3e,0x52))==(1,12,1,5,4,1), label+' final room5 manual hero identity')
        require(tuple(w(enemy+i) for i in (0,28,30))==(-1,-1,-1), label+' enemy world removal')
        require(tuple(w(i) for i in (-0xd8a6,-0xd8a4,-0xd8a2,-0xd8a8))==(2,2,13,2), label+' retained Actions/lamp inventory')
    pixels=(folder/'room5-native-23-screen.bin').read_bytes()
    require(len(pixels)==307200 and len(set(pixels))>32 and len((folder/'room5-native-23-clut.bin').read_bytes())==2056, 'native final populated scene and palette')
    print('PASS room5 encounter: natural enemy 62/body 73, Fight, approach, actual kicks/damage, death/removal and newly completed living manual gameplay')


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('mac',type=Path);p.add_argument('native',type=Path)
    p.add_argument('--mac-status',type=int,required=True);p.add_argument('--native-status',type=int,required=True)
    p.add_argument('--folder',type=Path,default=Path('tmp/m3-room5-combat'))
    a=p.parse_args()
    try:check(a.mac.read_text(),a.native.read_text(),a.folder,a.mac_status,a.native_status)
    except (ValueError,OSError,KeyError) as error:raise SystemExit('FAIL room5 combat: '+str(error))
