#!/usr/bin/env python3
"""Accept integrated native driver initialization through the second Times lookup."""
import argparse
import re
from pathlib import Path
import unittest

CALLS=['PASS native driver call: selector=21 D0=0 D1=0 preserved=13 stack=unchanged rate=22 voices=6/2/2',
       'PASS native driver call: selector=24 D0=0 D1=1 preserved=13 stack=unchanged rate=11 voices=6/2/2']
SECOND = r'PASS font second: Dan1\+003A result=20 stack=\$[0-9a-fA-F]{8} native-driver-calls=2'
ENDPOINT = 'MLIST_NEXT phase=copy-return state=1 windows=239 services=3825/3825 reads=108 bytes=810474'
GUARD = 'PASS menu-list checkpoint original-MDRV=absent'
DETACHED = '[Inferior 1 (Remote target) detached]'
COMPLETE = 'PASS native driver startup: Jnth=11 calls=2 second-Times=20 next=COPYBITS original-MDRV=absent'

def check(text, status):
    if status != 0 or any(bad in text for bad in ('FAIL', 'Error in sourced command file', 'Program received signal', 'timeout')):
        raise ValueError('runner/observer completion')
    second = re.findall(SECOND, text)
    if len(second) != 1:
        raise ValueError('missing/duplicate second Times lookup')
    endpoints=re.findall(r'^MLIST_NEXT phase=copy-return state=1 windows=(239) services=(\d+)/(\d+) reads=108 bytes=810474$',text,re.M)
    if len(endpoints)!=1 or int(endpoints[0][1])!=int(endpoints[0][2]) or int(endpoints[0][2])<1390:
        raise ValueError('next stop / completed service ledger')
    endpoint=re.sub(r'services=\d+/\d+', 'services='+'/'.join(endpoints[0][1:]), ENDPOINT.replace('windows=239','windows='+endpoints[0][0]))
    markers = CALLS + second + [endpoint, GUARD, DETACHED]
    for marker in markers:
        if text.count(marker) != 1:
            raise ValueError('missing/duplicate positive control')
    positions = [text.index(marker) for marker in markers]
    if positions != sorted(positions):
        raise ValueError('call/completion order')

def check_captures(text):
    """Validate captured state as well as observer completion markers."""
    from check_rgb_colors import check as rgb
    from check_native_font import check as font, FILES, build
    from check_aga_capture import check_frame
    rgb(text, 0, 'native')
    rgb(text, 0, 'native', window=True)
    font(text, 0)
    for path, expected in zip(FILES, build()):
        if path.read_bytes() != expected:
            raise ValueError('installed compatibility font body')
    required = [
        'STARTUP_PREFS existing=1 windows=218 services=1390/1390',
        'PASS startup MACPLAY omitted with palette retained',
        'PASS restored palette before first visible frame',
        'PASS native TextWidth calls=220',
        'PASS native original window LineTo caller stack registers and pen position',
        'PASS native window LineTo AGA publication',
        'PASS native driver20 playing-to-finished sequence ABI and cleanup',
        'BOOK_LIFECYCLE active=0 begun=840 completed=840',
        'PASS combined startup observer',
    ]
    if any(text.count(marker) != 1 for marker in required):
        raise ValueError('missing/duplicate combined coverage')
    if re.findall(r'^AGA_CURSOR enabled=(\d+) control=([0-9A-F]+)$',text,re.M) != [('0','0011')]:
        raise ValueError('disabled startup pointer')
    folder=Path(__file__).resolve().parents[1]/'tmp'
    from check_video_transfer import native as video_transfer
    transfer=video_transfer() # Exhaustively checked against the original Mac digest.
    for prefix, marker, logical in [('aga-startup','AGA_ACTIVE','aga-startup-logical'),
                                     ('aga-windowline','WINDOWLINE_AGA','aga-windowline-logical')]:
        rows=re.findall(r'^'+marker+r' (.*)$',text,re.M)
        if len(rows)!=1:raise ValueError('unique AGA publication')
        row=dict(re.findall(r'(\w+)=([^ ]+)',rows[0]))
        if row['queued']!=row['presented'] or row['pending']!='0' or row['late']!='0' or int(row['line'])>=72:
            raise ValueError('complete VBI publication')
        check_frame(folder,prefix+'-active',(folder/(logical+'.bin')).read_bytes(),
                    (folder/(prefix+'-clut.bin')).read_bytes(),160,150,int(row['front'],16),transfer)
    entries=re.findall(r'^TW_NATIVE_ENTER (.*)$',text,re.M)
    returns=re.findall(r'^TW_NATIVE_RETURN (.*)$',text,re.M)
    if len(entries)!=220 or len(returns)!=220:raise ValueError('TextWidth coverage')
    for n,(entry,returned) in enumerate(zip(entries,returns),1):
        e=dict(re.findall(r'(\w+)=(\w+)',entry));r=dict(re.findall(r'(\w+)=(\w+)',returned))
        if int(e['n'])!=n or int(r['n'])!=n or int(r['sp'],16)!=int(e['sp'],16)+8:
            raise ValueError('TextWidth order/stack')
        before=(folder/f'textwidth-native-{n}-before-port.bin').read_bytes()
        if len(before)!=108 or before!=(folder/f'textwidth-native-{n}-after-port.bin').read_bytes():
            raise ValueError('TextWidth port preservation')

class Checks(unittest.TestCase):
    def test_required_calls(self):
        second = 'PASS font second: Dan1+003A result=20 stack=$005f6d9e native-driver-calls=2'
        markers = CALLS + [second, ENDPOINT, GUARD, DETACHED]
        good = '\n'.join(markers)
        check(good, 0)
        check(good.replace("services=3825/3825", "services=3000/3000"), 0)
        rejected = [(good, 124), (good, None), (good + '\nFAIL', 0),
                    (good.replace('D1=1', 'D1=0'), 0),
                    (good.replace('result=20', 'result=0'), 0),
                    (good.replace('windows=239', 'windows=240'), 0),
                    (good.replace('reads=108', 'reads=109'), 0),
                    (good.replace('bytes=810474', 'bytes=826832'), 0),
                    (good.replace('native-driver-calls=2', 'native-driver-calls=1'), 0),
                    (good.replace('services=3825/3825', 'services=433/432'), 0),
                    ('\n'.join(CALLS[::-1] + markers[2:]), 0),
                    ('\n'.join([second] + CALLS + markers[3:]), 0)]
        for marker in markers:
            rejected.extend([(good.replace(marker, ''), 0), (good + '\n' + marker, 0)])
        for text, status in rejected:
            with self.subTest(text=text, status=status), self.assertRaises(ValueError):
                check(text, status)
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('log',type=Path,nargs='?');p.add_argument('--status',type=int);p.add_argument('--selftest',action='store_true');p.add_argument('--captures',action='store_true');a=p.parse_args()
    if a.selftest:raise SystemExit(not unittest.TextTestRunner().run(unittest.defaultTestLoader.loadTestsFromTestCase(Checks)).wasSuccessful())
    try:
        source=Path(__file__).resolve().parents[1]/'tmp/runtime-data/Alone In The Dark'
        from check_driver_startup import check_call_source
        check_call_source(source);text=a.log.read_text();check(text,a.status)
        if a.captures:check_captures(text)
        print(COMPLETE)
    except (ValueError,OSError,AttributeError) as error:raise SystemExit('FAIL native driver: '+str(error))
