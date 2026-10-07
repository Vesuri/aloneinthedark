#!/usr/bin/env python3
"""Audit explicit original sound-command entry references and configuration gates.

Uses all aligned original bytes as well as CREL/DREL, not just the conservative
trap walk. Private-root findings concern this shipped resource image.
"""
import argparse
import struct
from pathlib import Path
import trap_census as census
from a5world_check import expand, offsets

CROSS = {(13,0x1c84):3,(5,0x3c62):10,(5,0x3f66):10,
         (8,0x2bc):1,(8,0x2ce):0,(8,0x338):3,(8,0x474):1,
         (8,0x486):0,(8,0x4b2):2,(8,0x6c4):2}
LOCAL = {0x122c:2,0x1368:2,0x1dbe:2,0x1ec4:2,0x24d8:102,
         0x25ea:101,0x275e:100,0x287e:102,0x31e4:104,
         0x35bc:103,0x3674:102,0x36c4:102}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def references(segment, target):
    result=[]
    data=census.CODE[segment]
    for at in range(4,len(data)-4,2):
        instruction=next(census.md.disasm(data[at:at+16],at,count=1),None)
        if not instruction:
            continue
        name=instruction.mnemonic.split('.')[0]
        if name in ('jsr','jmp','lea','pea') or name.startswith('b'):
            if census.Walker.target(instruction)==target:
                result.append(at)
    return result


def audit(resource):
    census.load(resource)
    require(census.JT[29]==(3,0x18d4) and census.JT[32:34]==[(3,0x1de4),(3,0x1e24)], 'sound entry identities')
    # Every aligned long equal to the generic dispatcher's A5 offset is a JSR
    # operand; any new address-taking or other use requires manual review.
    raw={(seg,at-2) for seg,data in census.CODE.items() for at in range(4,len(data)-3,2)
         if data[at:at+4]==bytes.fromhex('0000010a')}
    require(raw==set(CROSS), 'complete generic sound-entry references')
    for (seg,at),command in CROSS.items():
        data=census.CODE[seg]
        require(data[at:at+6]==bytes.fromhex('4eb90000010a') and census.RELOC[seg].get(at+2)=='A5', 'relocated sound command call')
        push=bytes.fromhex('3f3c')+struct.pack('>H',command) if command else bytes.fromhex('4267')
        require(push in data[at-10:at], 'literal cross-segment command')
    require(set(references(3,0x18d4))==set(LOCAL), 'complete local dispatcher references')
    for at,command in LOCAL.items():
        require(bytes.fromhex('3f3c')+struct.pack('>H',command) in census.CODE[3][at-14:at], 'literal local command')
    globals_,_=expand(census.R[b'DATA',0].body,census.R[b'ZERO',0].body,75616)
    require(globals_[75616-0x68a]==0 and globals_[75616-0x73c:75616-0x73a]==b'\0\0','initial prepared/MIDI state')
    for relocation in offsets(census.R[b'DREL',0].body,75616)[0]:
        if relocation&1:
            continue
        value=struct.unpack_from('>I',globals_,75616+relocation)[0]
        require(value not in (0x10a,0x122,0x12a),'no DATA sound entry pointer')
    core=census.CODE[3]
    require(core[0x1252:0x1258].hex()=='1b7c0001f976','prepared-state enable')
    flag_uses=[(seg,at) for seg,data in census.CODE.items() for at in range(4,len(data)-2,2) if data[at:at+2]==bytes.fromhex('f976')]
    require(flag_uses==[(3,at) for at in (0x1256,0x1328,0x13bc,0x1418)],'all prepared-state operands')
    require(references(3,0x1196)==[0x1b08] and references(3,0x1478)==[0x1b24], 'prepare/pause only dispatched entry')
    # Selector 23 has real callers missed by the root-based walk. Their outer
    # function, not the inner setter, is the unreferenced root.
    require(references(3,0x31b2)==[0x3930,0x393e], 'selector 23 setter callers')
    require(not references(3,0x3918) and (3,0x3918) not in census.JT,'unreferenced selector 23 outer setter')
    # Gloss pause/resume also have real local callers in a private updater.
    require(references(8,0x36e)==[0x226] and references(8,0x394)==[0x20a], 'Gloss pause/resume callers')
    require(not references(8,0x1e2) and (8,0x1e2) not in census.JT,'unreferenced Gloss updater')
    require(census.CODE[8][0x388:0x38e].hex()=='4eb900000122' and census.CODE[8][0x3ae:0x3b4].hex()=='4eb90000012a','Gloss driver 10/11 calls')
    for value,site in ((0x122,(8,0x38a)),(0x12a,(8,0x3b0))):
        uses={(seg,at) for seg,relocations in census.RELOC.items() for at,kind in relocations.items()
              if kind=='A5' and int.from_bytes(census.CODE[seg][at:at+4],'big')==value}
        require(uses=={site},'complete relocated pause/resume entry references')

    # MIDI setup has one command-dispatch entry. Its only enabling write is in
    # that setup, and command 203 is absent from the exhaustive literal calls.
    require(references(3,0x1528)==[0x1ac6], 'MIDI setup entry')
    require(references(3,0xd7a)==[0x1562] and core[0xe50:0xe54].hex()=='41ed0132','MIDI callback installed only by setup')
    require(references(3,0xfd0)==[0xa70] and (3,0xfd0) not in census.JT,'selector 16 only in MIDI queue initialization')
    require(core[0x15a4:0x15aa].hex()=='3b7c0064f8c4','MIDI mode enable')
    enables=[]
    for seg,data in census.CODE.items():
        for at in range(4,len(data)-2,2):
            if data[at:at+2]!=bytes.fromhex('f8c4'):
                continue
            require(seg==3,'unexpected MIDI-mode reference')
            if data[at-4:at-2]==bytes.fromhex('3b7c'):
                value=int.from_bytes(data[at-2:at],'big')
                require(value in (1,2,3,4,5,6,7,100),'unexpected sound mode')
                if value==100:enables.append(at-4)
            else:
                require(data[at-4:at-2]==bytes.fromhex('0c6d') or data[at-2:at] in (bytes.fromhex('426d'),bytes.fromhex('4a6d')),'unclassified sound-mode operation')
    require(enables==[0x15a4],'only MIDI mode-100 enabling write')
    for offset in (0x10a,0x122,0x12a):
        operands=[]
        for seg,data in census.CODE.items():
            for at in range(4,len(data)-4,2):
                opcode=int.from_bytes(data[at:at+2],'big')
                if data[at+2:at+4]==struct.pack('>H',offset) and (opcode in (0x4ead,0x4eed,0x486d) or opcode&0xf1ff==0x41ed):
                    operands.append((seg,at))
        require(not operands,'unexpected A5-relative entry address/call')

    commands=set(CROSS.values())|set(LOCAL.values())
    require(not commands&{15,17,200,201,202,203}, 'unused prepare/pause/MIDI commands')
    print('PASS explicit sound-entry audit: 10 cross-segment and 12 local command calls; no DATA dispatcher pointers')
    print('Commands present:',','.join(map(str,sorted(commands))))
    print('Prepared-song flag initially zero; only enabling path is absent command 15 (selectors 1/2).')
    print('Driver 14 is behind absent command 17; MIDI 9/12/16/25 behind absent command 203 / mode 100.')
    print('Driver 10/11: Gloss updater +1E2 has no entry references. Driver 23: Core setter +3918 has no entry references.')
    print('Driver 6 fade path is reachable and implemented. Unsupported library selectors remain named stops.')
    print('This is static shipped-image evidence; it does not claim that the global trap census resolves every computed transfer.')


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--resource',type=Path,default=Path(__file__).resolve().parents[1]/'tmp/runtime-data/Alone In The Dark')
    a=p.parse_args()
    try:audit(a.resource)
    except (ValueError,OSError,KeyError) as error:raise SystemExit('FAIL sound reachability: '+str(error))
