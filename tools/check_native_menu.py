#!/usr/bin/env python3
"""Compare native startup menu calls with original Mac semantic records."""
import argparse
from pathlib import Path
from check_menu_reference import check,original,records,NATIVE_COMPLETE

def paired(native,reference,menus):
    expected=[r for r in reference if not (r['enter']['menu']==128 and r['enter']['item']==3)]
    if len(native)!=len(expected):raise ValueError('paired call count')
    for a,b in zip(native,expected):
        for key in ('trap','offset','menu','item','next'):
            if a['enter'][key]!=b['enter'][key]:raise ValueError('paired call identity')
        for key in ('menu_before','menu_after'):
            aa,ai=records(a[key]);bb,bi=records(b[key])
            if a['enter']['menu']==128:
                if len(bi)!=3 or bi[-1]!=(b'\0\0Control Panels',bytes(4)):raise ValueError('reference System-only item')
                bi=bi[:-1]
            if ai!=bi or aa[:2]+aa[10:15+aa[14]]!=bb[:2]+bb[10:15+bb[14]]:
                raise ValueError('paired menu title/flags/labels/attributes')
        for key in ('text_before','text_after'):
            if key in a or key in b:
                aa=a[key];bb=b[key]
                if aa[:aa[0]+1]!=bb[:bb[0]+1]:raise ValueError('paired text')

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('log',type=Path);p.add_argument('--status',type=int);p.add_argument('--reference',type=Path,required=True);p.add_argument('--reference-status',type=int,required=True);a=p.parse_args()
    try:
        menus=original(Path('tmp/runtime-data/Alone In The Dark'))
        native=check(a.log.read_text(),a.status,menus,True)
        reference=check(a.reference.read_text(),a.reference_status,menus)
        paired(native,reference,menus)
        # The real capture must fail these corruptions, not just accept itself.
        text=a.log.read_text()
        for bad,status in ((text,124),(text,None),(text.replace(NATIVE_COMPLETE,''),0),(text+NATIVE_COMPLETE,0),(text.replace('result=0002','result=0003',1),0),(text.replace('next=3A1F7601','next=00000000',1),0)):
            try:check(bad,status,menus,True)
            except (ValueError,KeyError):pass
            else:raise ValueError('acceptance checker missed a corrupted capture')
        print('PASS paired menu records: 32 native calls, exact game labels/flags/attributes/mutations; Mac-only Control Panels excluded explicitly')
    except (ValueError,OSError,KeyError,AttributeError) as error:raise SystemExit('FAIL paired menu records: '+str(error))
