# THINLINECHECKS=1. A bounded in-target check of the actual assembly raster.
set pagination off
set confirm off
break AitdScreen::showLoudStop
commands
 printf "FAIL thin lines %s / %s\n",manager,routine
 detach
 quit 1
end
tbreak aitdThinLineChecksComplete
continue
if g_thinLineChecks!=15886 || g_thinLineFast!=11138 || g_thinLineRejected!=4738
 printf "FAIL thin line coverage total=%u fast=%u rejected=%u\n",g_thinLineChecks,g_thinLineFast,g_thinLineRejected
 detach
 quit 1
end
printf "PASS native thin lines cases=%u raster=%u rejected=%u\n",g_thinLineChecks,g_thinLineFast,g_thinLineRejected
detach
quit 0
