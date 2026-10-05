#!/usr/bin/env python3
"""Check a naturally spawned bedroom encounter and completed death handling."""
import argparse
from pathlib import Path
import re
import struct
from check_menu_keyboard import require
from check_firstfloor_session import check as check_prefix


def check(mac, native, folder, mac_status, native_status):
    for label, log, status, marker in (
        ('Mac', mac, mac_status, 'PASS original bedroom encounter: spawned enemy, Close selection, Fight, damage, death and manual gameplay'),
        ('Amiga', native, native_status, 'PASS COMBAT spawned enemy, Fight, attacks, victory and published manual gameplay'),
    ):
        require(status == 0 and log.count(marker) == 1, label+' normal encounter completion')
        require(not re.search(r'FAIL|TIMEOUT|LUA ERROR|Error in|Program received signal', log), label+' no diagnostic failure')
    # Keep the complete previously verified key-route prefix, its artwork and
    # state captures. Exclude only the independent encounter's added phases.
    end = mac.index('PASS original lamp Use, hallway and bedroom key pickup')
    source_prefix = mac[:end] + '\n'.join(line for line in mac[end:].splitlines()
        if not line.startswith('EXPLORE phase='))
    check_prefix(source_prefix, native, folder, mac_status, native_status, key=True)
    def records(log, tag):
        result=[]
        for line in log.splitlines():
            if line.startswith(tag+' '):
                result.append(dict((k, int(v) if re.fullmatch(r'-?\d+', v) else v)
                    for k,v in re.findall(r'(\w+)=([^ ]+)', line)))
        return result
    source = {r['phase']:r for r in records(mac, 'COMBAT_STATE')}
    rows=records(native, 'COMBAT_NATIVE')
    states={r['stage']:r for r in rows}
    ordered=[r['stage'] for r in rows if r['stage'] != 34]
    require(ordered==list(range(1,34))+[35,36], 'all native encounter phases')
    require(sum(r['stage']==34 for r in rows)>=1, 'positive native attack loop')
    for label, initial, active, final in (
        ('Mac', source['closed-door'], source['before-fight'], source['combat-result']),
        ('Amiga', states[1], states[32], states[36]),
    ):
        require(initial['npc']>=0 and tuple(initial[k] for k in ('var20','var21','var30','var31','var40'))==(0,20,0,1,10), label+' natural closed door and live enemy spawn')
        require(active['npc']>=0 and active['var20']==1 and active['var30']==1 and active['var31']==1, label+' reopened door activates actual encounter')
        require(final['npc']==-1 and final['var40']<=0 and final['var20']==0 and final['var21']>0, label+' enemy defeated and death handling complete, living hero')
        require(final['var90']==16 and final['tick']>active['tick']>initial['tick'], label+' retained Fight mode and advancing gameplay')
    require(mac.count('FIRSTFLOOR_FIGHT_ACCEPTED tick=')==1 and mac.count('CLOSE_SELECTED var90=128')==1, 'original accepted Fight branch and actual Close selection')
    require(states[25]['var90']==128 and states[26]['var90']==16 and states[26]['fight']==1, 'native Close and delivered/accepted Fight before door reopening')
    require(states[28]['var30']==1 and states[28]['var20']==0, 'native door reopening precedes enemy activation')
    require(states[32]['anim']==262 and states[32]['track']==1, 'actual native kick, not merely key delivery')
    require(states[36]['anim']==4 and states[36]['track']==1 and states[36]['frames']>states[35]['frames'], 'new published manual gameplay after victory')
    turns=records(mac, 'COMBAT_TURN')
    require(len(turns)==1 and turns[0]['target']==768 and abs(turns[0]['beta']-768)<=16, 'original deliberate turn completed')
    source_aims=records(mac, 'COMBAT_AIM')
    native_aims=records(native, 'COMBAT_AIM')
    require(source_aims and all(((r['target']-r['beta'])&1023)<=16 or ((r['target']-r['beta'])&1023)>=1008 for r in source_aims), 'original attacks face the selected enemy heading')
    require(any(a['target']==b['target'] and b['tick']>a['tick'] and a['beta']!=b['beta']
        and (((b['target']-b['beta'])&1023)<=16 or ((b['target']-b['beta'])&1023)>=1008)
        for a,b in zip(native_aims,native_aims[1:])), 'native consumed turn reaches enemy heading')
    require(any(r['var40']<10 and r['npc']>=0 for r in rows), 'native damage observed while enemy remains active')
    require(any(r['var40']<=0 and r['npcAnim']==46 and r['npc']>=0 for r in source.values()), 'original death animation before deletion')
    for label,name in (('Mac','key-session-lamp-use-combat-observed-a5.bin'),('Amiga','combat-native-36-a5.bin')):
        data=(folder/name).read_bytes();require(len(data)==75616, label+' final A5 extent')
        w=lambda o:struct.unpack_from('>h',data,75616+o)[0]
        actor=-0xb292+160;enemy=-0x115f2+35*52
        require(tuple(w(actor+i) for i in (0,2,0x2e,0x30,0x3e,0x52))==(1,12,1,2,4,1), label+' living manual bedroom actor')
        require(tuple(w(enemy+i) for i in (0,28,30))==(-1,-1,-1), label+' actual enemy world removal')
        require(tuple(w(i) for i in (-0xd8a6,-0xd8a4,-0xd8a2,-0xd8a0,-0xd8a8))==(3,2,37,13,2), label+' Actions, key and lamp retained')
    print('PASS bedroom encounter: natural spawn, Close/Fight selection, door reopening, kick/damage, enemy death/removal and published living manual gameplay')


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('mac',type=Path);p.add_argument('native',type=Path)
    p.add_argument('--mac-status',type=int,required=True);p.add_argument('--native-status',type=int,required=True)
    p.add_argument('--folder',type=Path,default=Path('tmp/m3-combat'))
    a=p.parse_args()
    try:check(a.mac.read_text(),a.native.read_text(),a.folder,a.mac_status,a.native_status)
    except (ValueError,OSError,KeyError) as error:raise SystemExit('FAIL combat route: '+str(error))
