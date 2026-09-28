# HEAPPROBE=1: real OS/Toolbox traps on the private Mac stack.
set pagination off
set confirm off
break AitdScreen::showLoudStop
commands
 silent
 printf "heap FAIL: unexpected %s / %s at stage %u\n",g_trapManager,g_trapRoutine,g_heapProbeStage
 detach
 quit 1
end
tbreak aitdHeapProbeComplete
continue
if g_heapProbeDone != 1 || g_heapProbeStage != 3 || g_macLineAInstalled != 0 || g_heapError != 0
 printf "heap FAIL: stage=%u done=%u error=%d\n",g_heapProbeStage,g_heapProbeDone,g_heapError
 detach
 quit 1
end
printf "PASS heap-native: stages=%u app-free=%u system-free=%u\n",g_heapProbeStage,g_heapFree,g_heapSystemFree
detach
quit 0
