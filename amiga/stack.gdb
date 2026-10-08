# Build QUITPROBE=1 STACKPROBE=1 INTROSKIP=1; run with DIAG_STACK=4096.
set pagination off
set confirm off
break aitdStackProbeFinished
commands
 silent
 printf "STACK process=%u/%u Mac=%u/%u song=%u/8192 deferred=%u/8192 done=%u\n",g_stackReport.processUsed,g_stackReport.processSize,g_stackReport.macUsed,g_stackReport.macSize,g_stackReport.songUsed,g_stackReport.deferredUsed,g_stackReport.done
 if g_stackReport.done!=1 || g_stackReport.processSize!=4096 || g_stackReport.processUsed==0 || g_stackReport.processUsed>=3584 || g_stackReport.macUsed==0 || g_stackReport.macUsed>=g_stackReport.macSize-512 || g_stackReport.songUsed>=7680 || g_stackReport.deferredUsed>=7680
  echo FAIL STACK insufficient measured headroom\n
  detach
  quit 1
 end
 continue
end
source quit.gdb
