#!/usr/bin/env python3
"""Check the paired living room5 -> room4 -> western hallway -> bathroom route."""
import argparse
from pathlib import Path
import re
import struct
from check_menu_keyboard import require
from check_room5_combat import records


def check(mac, native, folder, mac_status, native_status):
    for name, log, status, marker in (
        ('Mac', mac, mac_status, 'PASS original room3 entry through living room4 bypass'),
        ('Amiga', native, native_status, 'PASS ROOM3 bathroom through living room4 bypass'),
    ):
        require(status == 0 and log.count(marker) == 1, name+' normal route completion')
        require(not re.search(r'FAIL|TIMEOUT|LUA ERROR|VP ERROR|Error in|Program received signal', log), name+' no failure')
    rows=records(native,'ROOM3_NATIVE');phases={r['stage']:r for r in rows}
    require(rows and all(r['drops']==0 for r in rows),'no native synthetic input drops')
    require(all(y['stage']>x['stage'] and y['tick']>=x['tick'] for x,y in zip(rows,rows[1:])), 'forward native phases')
    source={}
    for label,values in re.findall(r'ROOM5_VARS phase=(\S+) values=([0-9,-]+)',mac):
        source[label]=[int(v) for v in values.split(',')]
    for stage,label,room in ((42,'room4-manual',4),(53,'hallway-west-side',1),(66,'room3-manual',3)):
        r=phases[stage]
        require((r['floor'],r['room'],r['body'],r['animation'],r['track'],r['action'])==(1,room,12,4,1,64) and r['health']>0, 'native living manual destination '+str(stage))
        require(r['frames']>phases[40 if stage==42 else 42 if stage==53 else 60]['frames'], 'fresh completed scene '+str(stage))
        vars_data=(folder/f'native-{stage}-vars.bin').read_bytes()
        require(len(vars_data)==400,'native variable extent')
        native_vars=struct.unpack('>200h',vars_data)
        for name,values in (('Mac',source[label]),('Amiga',native_vars)):
            require(values[20]==0 and values[21]>0 and values[57]<=0 and values[90]==64,name+' living health, removed enemy and real Open/Search mode')
        for name,file in (
            ('Mac',f'hallway-session-lamp-use-{label}-a5.bin'),
            ('Amiga',f'native-{stage}-a5.bin'),
        ):
            data=(folder/file).read_bytes();require(len(data)==75616,name+' A5 extent')
            w=lambda o:struct.unpack_from('>h',data,75616+o)[0]
            hero=-0xb292+160;enemy=-0x115f2+62*52;lamp=-0x115f2+13*52
            require(tuple(w(hero+i) for i in (0,2,0x2e,0x30,0x3e,0x52))==(1,12,1,room,4,1),name+' real destination actor')
            if room==1:require(w(hero+0x1c)<1300,name+' hallway west of original fall zone')
            require(tuple(w(enemy+i) for i in (0,28,30))==(-1,-1,-1),name+' enemy remains removed')
            require(tuple(w(i) for i in (-0xd8a6,-0xd8a4,-0xd8a2,-0xd8a8))==(2,2,13,2),name+' retained Actions/lamp inventory')
            require(tuple(w(lamp+i) for i in (12,28,30))==(-31223,-1,-1),name+' retained lamp ownership')
        pixels=(folder/f'native-{stage}-screen.bin').read_bytes()
        require(len(pixels)==307200 and len(set(pixels))>32 and len((folder/f'native-{stage}-clut.bin').read_bytes())==2056, 'populated native scene/palette')
        require(len((folder/f'hallway-session-lamp-use-mac-{label}-rgb.bin').read_bytes())==1228800,'original logical scene extent')
    print('PASS bathroom: real living room5-room4-western hallway-room3, actual Open/Search, enemy removal, retained inventory, fresh scenes and zero dropped keys; not the ten-minute gate')


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('mac',type=Path);p.add_argument('native',type=Path)
    p.add_argument('--mac-status',type=int,required=True);p.add_argument('--native-status',type=int,required=True)
    p.add_argument('--folder',type=Path,default=Path('tmp/m3-room3'))
    a=p.parse_args()
    try:check(a.mac.read_text(),a.native.read_text(),a.folder,a.mac_status,a.native_status)
    except (ValueError,OSError,KeyError) as error:raise SystemExit('FAIL room3 route: '+str(error))
