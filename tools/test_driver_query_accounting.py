#!/usr/bin/env python3
"""Reject omitted/miscounted status queries, including callbacks during probes."""
from check_driver20 import check_native_sequence
sequence='DRIVER20_NATIVE_SEQUENCE calls=200 active=199 complete=1 driverCalls=207 statusCalls=203 starts=1 stops=1'
account='DRIVER20_ACCOUNTING observed=200 scoped=3 total=203'
good=sequence+'\n'+account
check_native_sequence(good)
check_native_sequence(good.replace('207','204').replace('203','200').replace('scoped=3','scoped=0'))
for bad in [good.replace('scoped=3','scoped=2'),good.replace('total=203','total=204'),
            good.replace('observed=200','observed=201'),good.replace('driverCalls=207','driverCalls=206'),
            good.replace('active=199','active=200'),good.replace('complete=1','complete=0'),
            good.replace('stops=1','stops=0'),sequence,good+'\n'+account]:
    try:check_native_sequence(bad)
    except ValueError:pass
    else:raise AssertionError('accepted missing or inconsistent status evidence: '+bad)
print('PASS driver query accounting: direct/scoped queries accepted; missing, duplicated, incomplete and inconsistent evidence rejected')
