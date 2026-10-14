# MONSTERAUDIT=1 M5AUDIT=1, prepared default monster preferences.
# Stop only after normal death/ExitToShell, OS handback and resource closure.
set pagination off
set confirm off
break AitdScreen::showLoudStop
commands
 silent
 echo FAIL monster gameplay loud stop\n
 detach
 quit 1
end
tbreak aitdM5Stop
continue
printf "MONSTER_MEMORY phase=%u chip=%u fast=%u failures=%u errors=%u resource=%u overlay=%u\n",g_monsterPhase,g_m5Audit.liveChip,g_m5Audit.liveFast,g_m5Audit.failures,g_m5Audit.accountingErrors,g_resourceSourceOpen,g_overlaySourceOpen
if g_monsterPhase!=5 || g_m5Audit.liveChip || g_m5Audit.liveFast || g_m5Audit.failures || g_m5Audit.accountingErrors || g_resourceSourceOpen || g_overlaySourceOpen || g_resourceSourceCloseErrors || g_overlaySourceCloseErrors
 echo FAIL monster gameplay memory cleanup\n
 detach
 quit 1
end
echo PASS monster fight death cleanup with zero allocation failures\n
detach
quit 0
