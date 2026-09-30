#!/usr/bin/env python3
"""Compare the first original/native raw-effect request, ABI and PCM publication."""
import argparse,re,struct
from pathlib import Path
from check_driver22 import fields,one,ROOT
from resource_fork import read_resource_fork

def check(reference,status,native=None,native_status=None):
    if status!=0 or any(x in reference for x in ('FAIL','LUA ERROR','Error in')) or reference.count('PASS original driver17 play-effect and completion')!=1 or reference.count('Exited via the debugger')!=1:
        raise ValueError('reference completion')
    code=next(r.body for r in read_resource_fork(ROOT/'tmp/runtime-data/Alone In The Dark') if r.kind==b'CODE' and r.rid==3)
    caller=code[0x17ea:0x1800]
    if caller.hex()!='0064f8c467102f2e000848780011206df9544e90508f' or one(reference,r'^DRIVER17_BYTES (\w+)$')!=caller.hex().upper():raise ValueError('caller bytes')
    driver=(ROOT/'tmp/driver17-reference-driver.bin').read_bytes()
    original=(ROOT/'tmp/plan/MDRV_11.bin').read_bytes()
    if driver[0x3506:0x3606]!=original[0x3506:0x3606] or driver[:12].hex()!='202f0004222f000848e73ffe':raise ValueError('original play implementation')
    e,r=[fields(one(reference,r'^DRIVER17_'+phase+r' (.*)$')) for phase in ('ENTER','RETURN')]
    if e['selector']!=17 or r['sp']!=e['sp'] or r['d0'] or r['d1']!=((e['ignored']&0xffff0000)|0x7fff):raise ValueError('return ABI')
    for reg in [f'd{i}' for i in range(2,8)]+[f'a{i}' for i in range(7)]:
        if e[reg]!=r[reg]:raise ValueError('preserved '+reg)
    packet=(ROOT/'tmp/driver17-reference-packet.bin').read_bytes()
    sample,size,rate,start,end,counter,ident=struct.unpack('>6IH',packet)
    if (size,rate,start,end,ident)!=(30783,8000<<16,0,0,0x8000):raise ValueError('first actual packet')
    if one(reference,r'^DRIVER17_PACKET (\w+)$')!=packet.hex().upper():raise ValueError('packet dump')
    before=(ROOT/'tmp/driver17-reference-enter-state.bin').read_bytes()
    after=(ROOT/'tmp/driver17-reference-return-state.bin').read_bytes()
    expected=bytearray(before);struct.pack_into('>IIH',expected,0,17,e['ignored'],0)
    voice=0x22d2+6*4
    longs={0:sample,0x40:((rate>>5)//11127)<<5,0x80:0,0x240:0,0x280:sample+size,
           0x2c0:0,0x300:0,0x340:(e['entry']|0x80000000)+0x4200+0x2ca6,
           0x3c0:0,0x540:counter,0x640:0x00800080}
    for offset,value in longs.items():struct.pack_into('>I',expected,voice+offset,value)
    for offset,value in {0x200:0x7ffe,0x440:ident,0x500:0x7fff,0x580:0}.items():struct.pack_into('>H',expected,voice+offset,value)
    if after!=expected:raise ValueError('complete play state transition')
    finish=fields(one(reference,r'^DRIVER17_COMPLETE (.*)$'))
    complete=(ROOT/'tmp/driver17-reference-complete-state.bin').read_bytes()
    if finish['cursor']!=sample+size or finish['loopword'] or struct.unpack_from('>H',complete,voice+0x200)[0]!=0xffff:raise ValueError('natural completion')
    # The Mac mixer rounds its resampling step; Paula plays at the requested
    # pitch, with at most the documented one-tick duration difference here.
    if finish['elapsed']!=230:raise ValueError('reference duration')
    pcm=(ROOT/'tmp/driver17-reference-sample.bin').read_bytes()
    if len(pcm)!=size:raise ValueError('sample size')
    if native is not None:
        text=native.read_text()
        if native_status!=0 or any(x in text for x in ('FAIL','Error in','DIAG / GDB TIMEOUT','Program received signal')) or text.count('PASS native driver17 play-effect ABI and publication')!=1 or text.count('[Inferior 1 (Remote target) detached]')!=1:raise ValueError('native call completion')
        if text.count('PASS native driver17 natural completion DMA-off and sample released')!=1:raise ValueError('native completion cleanup')
        cleanup=re.findall(r'^DRIVER17_CLEANUP starts=1 stops=1 tick=\d+ elapsed=\d+ active=0 channel=-1 chip=0 allocated=0 dma=([0-9A-F]+)$',text,re.M)
        if len(cleanup)!=1 or int(cleanup[0],16)&15:raise ValueError('native DMA/sample ownership after completion')
        from check_native_driver import check as startup
        startup(text,native_status)
        p=(ROOT/'tmp/driver17-native-packet.bin').read_bytes()
        if p[4:20]!=packet[4:20] or p[24:]!=packet[24:]:raise ValueError('native request')
        if (ROOT/'tmp/driver17-native-sample.bin').read_bytes()!=pcm:raise ValueError('native sample')
        if (ROOT/'tmp/driver17-native-chip.bin').read_bytes()!=bytes(b^0x80 for b in pcm)+b'\0\0\0':raise ValueError('Paula PCM/pad/silent reload')
        if 'calls=4 starts=1 stops=0 size=30783 rate=1F400000 period=443 duration=231 id=8000 active=1 channel=0' not in text:raise ValueError('native event')
    print('PASS driver17: original bytes, full play transition, natural completion, call ABI and paired raw PCM')

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('reference',type=Path);p.add_argument('--status',required=True,type=int);p.add_argument('--native',type=Path);p.add_argument('--native-status',type=int);a=p.parse_args()
    try:check(a.reference.read_text(),a.status,a.native,a.native_status)
    except (ValueError,OSError,KeyError) as e:raise SystemExit('FAIL driver17: '+str(e))
