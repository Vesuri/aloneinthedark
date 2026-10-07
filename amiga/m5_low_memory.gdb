set pagination off
set confirm off
set width 0
tbreak MacLoader::preparationError
continue
printf "M5_LOW_RAM cpuFlags=%u chip=%u fast=%u failures=%u reason=%s\n",g_m5Audit.cpuFlags,g_m5Audit.totalChip,g_m5Audit.totalFast,g_m5Audit.failures,s_preparationError
if g_m5Audit.cpuFlags!=7 || g_m5Audit.totalFast!=4194304 || !g_m5Audit.failures || g_m5Audit.accountingErrors || s_applicationArena || s_systemArena
 echo FAIL low-memory identity, expected failure or arena cleanup\n
 detach
 quit 1
end
echo PASS M5 4MB rejected during startup with arena cleanup\n
detach
quit 0
