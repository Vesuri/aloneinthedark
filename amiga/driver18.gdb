set pagination off
set confirm off
set width 0
break AitdScreen::showLoudStop
tbreak dispatchMacTrap if trap==0xa8ec
continue
set $call=(unsigned long)s_segments[3].begin+0x1828
if g_stageBState==3 || *(unsigned long*)($call-8)!=0x48780012 || *(unsigned long*)($call-4)!=0x206df954 || *(unsigned long*)$call!=0x4e90508f
 echo FAIL driver18 caller bytes\n
 detach
 quit 1
end
tbreak *$call
continue
if $pc!=$call
 echo FAIL driver18 original caller not reached\n
 detach
 quit 1
end
set $savedsp=$sp
set $arg=*(unsigned long*)($sp+4)
set $identifier=*(unsigned short*)($arg+24)
printf "DRIVER18_NATIVE_ENTER sp=%X identifier=%X argument=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$sp,$identifier,$arg,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
set $stops=g_effectStops
set $i=0
set $count=0
while $i<2
 printf "DRIVER18_EFFECT_ENTER slot=%u id=%X active=%u channel=%d chip=%X\n",$i,g_soundDriver.effectIds[$i],g_soundDriver.effects[$i].active,g_soundDriver.effects[$i].channel,g_effects[$i].chip
 if g_soundDriver.effects[$i].active && g_soundDriver.effectIds[$i]==$identifier
  set $count=$count+1
 end
 set $i=$i+1
end
dump binary memory ../tmp/driver18-native-enter-songs.bin &g_soundDriver.songs &g_soundDriver.songs+1
tbreak *($call+2) if $sp==$savedsp
continue
if g_stageBState==3 || $pc!=$call+2 || $sp!=$savedsp || $d0!=0 || $d1!=$arg
 echo FAIL driver18 return\n
 detach
 quit 1
end
printf "DRIVER18_NATIVE_RETURN sp=%X identifier=%X argument=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$sp,$identifier,$arg,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
set $i=0
while $i<2
 printf "DRIVER18_EFFECT_RETURN slot=%u id=%X active=%u channel=%d chip=%X\n",$i,g_soundDriver.effectIds[$i],g_soundDriver.effects[$i].active,g_soundDriver.effects[$i].channel,g_effects[$i].chip
 if g_soundDriver.effectIds[$i]==$identifier && (g_soundDriver.effects[$i].active || g_soundDriver.effects[$i].channel!=-1 || g_effects[$i].chip)
  echo FAIL driver18 sample ownership\n
  detach
  quit 1
 end
 set $i=$i+1
end
dump binary memory ../tmp/driver18-native-return-songs.bin &g_soundDriver.songs &g_soundDriver.songs+1
if g_effectStops!=$stops+$count || g_introSkipState!=2 || g_macBookFramesCompleted!=0
 echo FAIL driver18 cleanup count or Enter route\n
 detach
 quit 1
end
printf "DRIVER18_NATIVE_STOPPED count=%u book=%u\n",$count,g_macBookFramesCompleted
tbreak *((unsigned long)s_segments[4].begin+0x33e0)
continue
if g_stageBState==3 || $pc!=(unsigned long)s_segments[4].begin+0x33e0
 echo FAIL driver18 pond continuation\n
 detach
 quit 1
end
echo PASS native driver18 targeted stop and pond continuation\n
detach
quit 0
