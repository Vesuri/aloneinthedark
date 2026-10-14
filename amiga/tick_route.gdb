# TICKROUTE=1, production startup: two original book-page holds, no skips/input.
set pagination off
set confirm off
break AitdScreen::showLoudStop
commands
 silent
 echo FAIL tick route loud stop\n
 detach
 quit 1
end
tbreak aitdTickProbeComplete
continue
if g_tickCount!=2
 echo FAIL tick route count\n
 detach
 quit 1
end
set $n=0
while $n<g_tickCount
 printf "TICK_ROUTE n=%u delay=%u start=%u end=%u d7=%u field=%u\n",$n,g_tickRows[$n][0],g_tickRows[$n][1],g_tickRows[$n][2],g_tickRows[$n][3],g_tickRows[$n][4]
 set $n=$n+1
end
echo PASS native tick route\n
detach
quit 0
