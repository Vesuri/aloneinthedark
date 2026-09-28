# SERVICEPROBE=1; positive nested trap frames verify execution in user mode.
set pagination off
set confirm off
break AitdScreen::showLoudStop
commands
 silent
 printf "service FAIL: %s / %s entered=%u completed=%u\n",g_trapManager,g_trapRoutine,g_macServiceEntered,g_macServiceCompleted
 detach
 quit 1
end
tbreak aitdServiceProbeComplete
continue
if g_macServiceEntered != 4 || g_macServiceCompleted != 4 || g_macServiceActive != 0 || g_serviceProbe[0] != 4 || g_serviceProbe[1] != 0 || g_serviceProbe[6] != 1 || g_serviceProbe[5] != 1 || g_serviceProbe[3] != 24 || g_serviceProbe[4] != 31
 printf "service FAIL: entered=%u completed=%u active=%u\n",g_macServiceEntered,g_macServiceCompleted,g_macServiceActive
 x/8wx g_serviceProbe
 detach
 quit 1
end
set $svc_i=0
while $svc_i<15
 if $svc_i != 0 && $svc_i != 8 && g_serviceProbe[8+$svc_i] != g_serviceProbe[23+$svc_i]
  printf "service FAIL: OS register %u\n",$svc_i
  detach
  quit 1
 end
 if g_serviceProbe[38+$svc_i] != g_serviceProbe[53+$svc_i]
  printf "service FAIL: Toolbox register %u\n",$svc_i
  detach
  quit 1
 end
 set $svc_i=$svc_i+1
end
if g_serviceProbe[23] != 0xffffff94 || g_serviceProbe[31] != 0x2468ace0
 echo service FAIL: OS result registers\n
 detach
 quit 1
end
echo PASS user-service: mode=user calls=4 originals=2 nested=4 callback=1 registers=15 CCR=18/1f stack=balanced\n
detach
quit 0
