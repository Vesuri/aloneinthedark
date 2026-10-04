#!/usr/bin/env python3
"""Check paired launch Apple Event delivery and integrated SANE coverage."""
import argparse
from pathlib import Path
import re
import struct
from check_driver22 import fields, one
from resource_fork import read_resource_fork

ROOT = Path(__file__).resolve().parents[1]


def require(value, message):
    if not value:
        raise ValueError(message)


def check(reference, native, reference_status, native_status):
    for label, text, status, marker in (
        ('Mac', reference, reference_status, 'PASS original launch Apple Event delivery'),
        ('Amiga', native, native_status, 'PASS MENUS keyboard quit and restoration'),
    ):
        require(status == 0 and text.count(marker) == 1, label+' completion')
        require(not re.search(r'FAIL|TIMEOUT|LUA ERROR|Error in|Program received signal', text), label+' failure')
    require(one(reference, r'^AE_DELIVERY_ARM bytes=(\w+)$') == '2f0a2f02246f000a', 'dispatcher bytes')
    entry = fields(one(reference, r'^AE_PROCESS_ENTER (.*)$'))
    returned = fields(one(reference, r'^AE_PROCESS_RETURN (.*)$'))
    event = bytes.fromhex(one(reference, r'^AE_PROCESS_ENTER .* event=(\w+) '))
    what, event_class, tick, event_id, modifiers = struct.unpack('>HIIIH', event)
    require((what, event_class, event_id, modifiers) == (23, 0x61657674, 0x6f617070, 0), 'original event identity')
    require(entry['selector'] == 0x21b and returned['sp'] == entry['sp']+4
            and returned['delta'] == 4 and returned['result'] == returned['d0'] == 0, 'original process ABI')
    for register in [f'd{i}' for i in range(3, 8)]+[f'a{i}' for i in range(2, 7)]:
        require(entry[register] == returned[register], 'original preserved '+register)
    handler = fields(one(reference, r'^AE_HANDLER_ENTER (.*)$'))
    handler_return = fields(one(reference, r'^AE_HANDLER_RETURN (.*)$'))
    args = bytes.fromhex(one(reference, r'^AE_HANDLER_ENTER .* args=(\w+) '))
    require(args[:4] == bytes(4) and args[12:] == bytes(2)
            and handler['a5'] == entry['a5'] and handler_return['sp'] == handler['sp']+16
            and handler_return['result'] == 0, 'original Pascal handler ABI')
    require(one(reference, r'^AE_DESCRIPTOR reply (\w+)$') == '6E756C6C00000000', 'null reply')
    descriptor = bytes.fromhex(one(reference, r'^AE_DESCRIPTOR event (\w+)$'))
    require(descriptor[:4] == b'aevt' and any(descriptor[4:]), 'owned event descriptor')
    code = next(r.body for r in read_resource_fork(ROOT/'tmp/runtime-data/Alone In The Dark')
                if r.kind == b'CODE' and r.rid == 7)
    require(code[0x4ea:0x4f8].hex() == '4e560000426e00144e5e4e74000c', 'original handler bytes')
    native_entry = fields(one(native, r'^AE_NATIVE_ENTER (.*)$'))
    require((native_entry['what'], native_entry['class'], native_entry['id'])
            == (what, event_class, event_id), 'native event identity')
    require(len(re.findall(r'^AE_NATIVE_HANDLER ', native, re.M)) == 1
            and 'AE_NATIVE_HANDLER user=1 active=0 depth=1 refCon=0 eventType=aevt replyType=null ' in native,
            'safe user-mode callback')
    require(native.count('PASS native launch Apple Event delivered=1 result=0 preserved=10 cleanup=4 user=1') == 1,
            'native callback/process ABI and single delivery')
    sane = one(native, r'^PASS integrated Apple delivery and five SANE operations calls=(\d+) mask=1F$')
    require(int(sane) >= 10, 'integrated SANE positive control')
    require(native.count('[Inferior 1 (Remote target) detached]') == 1, 'normal observer exit')
    print('PASS Apple delivery: original launch identity, Pascal ABI, ten preserved registers, user-mode callback, cleanup and all five integrated SANE operations')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('reference', type=Path)
    parser.add_argument('native', type=Path)
    parser.add_argument('--reference-status', type=int, required=True)
    parser.add_argument('--native-status', type=int, required=True)
    args = parser.parse_args()
    try:
        check(args.reference.read_text(), args.native.read_text(), args.reference_status, args.native_status)
    except (ValueError, OSError, KeyError, struct.error) as error:
        raise SystemExit('FAIL Apple delivery: '+str(error))
