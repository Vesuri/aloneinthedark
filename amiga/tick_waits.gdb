set pagination off
set confirm off
break AitdScreen::showLoudStop
commands
 silent
 echo FAIL tick waits loud stop\n
 detach
 quit 1
end
tbreak aitdTickProbeComplete
continue
p g_tickCount
set $n=0
while $n<g_tickCount
 printf "TICK_WAIT n=%u delay=%u start=%u end=%u first_field=%u last_field=%u\n",$n,g_tickRows[$n][0],g_tickRows[$n][1],g_tickRows[$n][2],g_tickRows[$n][3],g_tickRows[$n][4]
 set $n=$n+1
end
printf "TICK_CONTROLS bits=%u\n",g_tickControls
if g_tickCount!=42 || g_tickControls!=7
 quit 1
end
echo PASS tick waits\n
detach
quit 0
