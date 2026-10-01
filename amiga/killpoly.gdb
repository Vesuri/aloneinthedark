set pagination off
set confirm off
set width 0
break AitdScreen::showLoudStop
tbreak dispatchMacTrap if trap==0xa8ec
continue
set $call=(unsigned long)s_segments[4].begin+0x3410
if g_stageBState==3 || *(unsigned long*)($call-2)!=0x2f0ca8cd
 echo FAIL KillPoly caller bytes\n
 detach
 quit 1
end
tbreak *$call
continue
if $pc!=$call
 echo FAIL KillPoly caller not reached\n
 detach
 quit 1
end
tbreak dispatchMacTrap
continue
if g_stageBState==3 || trap!=0xa8cd
 echo FAIL KillPoly dispatch entry\n
 detach
 quit 1
end
set $savedsp=(unsigned long)userStack
set $poly=*(unsigned long*)$savedsp
set $body=*(unsigned long*)$poly
set $size=*(unsigned short*)$body
set $span=*(unsigned long*)($body-24)
set $zone=(unsigned long)s_applicationZone.arena_
set $free=*(unsigned long*)($zone+12)
set $region=regs[10]
set $rbody=*(unsigned long*)$region
set $rsize=*(unsigned short*)$rbody
set $port=*(unsigned long*)s_qdThePort
set $pm=*(unsigned long*)*(unsigned long*)($port+2)
set $pixels=*(unsigned long*)$pm
set $bytes=(*(unsigned short*)($pm+4)&0x3fff)*(*(short*)($pm+10)-*(short*)($pm+6))
set $frames=g_macFramesQueued
set $block=$zone+64
set $flag=0
while $block<$zone+s_applicationZone.end_
 set $length=*(unsigned long*)$block
 if $length<24
  echo FAIL KillPoly heap\n
  detach
  quit 1
 end
 if *(unsigned long*)($block+12)==3
  set $count=*(unsigned long*)($block+8)
  set $masters=$block+24
  if $poly>=$masters && $poly<$masters+4*$count && ($poly-$masters)%4==0
   set $flag=$masters+4*$count+($poly-$masters)/4
  end
 end
 set $block=$block+$length
end
if !$flag || *(unsigned long*)($body-12)!=2 || *(unsigned long*)($body-16)!=$poly-$zone || *(unsigned long*)($body-20)!=54 || $size!=54 || $rsize!=244
 echo FAIL KillPoly initial ownership\n
 detach
 quit 1
end
printf "KILL_NATIVE_ENTER sp=%X poly=%X size=%X span=%X free=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$savedsp,$poly,$size,$span,$free,regs[0],regs[1],regs[2],regs[3],regs[4],regs[5],regs[6],regs[7],regs[8],regs[9],regs[10],regs[11],regs[12],regs[13],regs[14]
dump binary memory ../tmp/killpoly-native-ENTER-poly.bin $body $body+$size
dump binary memory ../tmp/killpoly-native-ENTER-region.bin $rbody $rbody+$rsize
dump binary memory ../tmp/killpoly-native-ENTER-port.bin $port $port+108
dump binary memory ../tmp/killpoly-native-ENTER-pixels.bin $pixels $pixels+$bytes
tbreak *($call+2) if $sp==$savedsp+4
continue
if g_stageBState==3 || $pc!=$call+2 || $sp!=$savedsp+4 || *(unsigned long*)$poly || *(unsigned char*)$flag || *(unsigned long*)($zone+12)!=$free+$span || g_macFramesQueued!=$frames || g_introSkipState!=2 || g_macBookFramesCompleted!=0
 echo FAIL KillPoly return, ownership or drawing isolation\n
 detach
 quit 1
end
printf "KILL_NATIVE_RETURN sp=%X poly=%X free=%X master=%X flags=%X memerr=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$sp,$poly,*(unsigned long*)($zone+12),*(unsigned long*)$poly,*(unsigned char*)$flag,s_memoryError,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
set $rbody=*(unsigned long*)$region
dump binary memory ../tmp/killpoly-native-RETURN-region.bin $rbody $rbody+$rsize
dump binary memory ../tmp/killpoly-native-RETURN-port.bin $port $port+108
dump binary memory ../tmp/killpoly-native-RETURN-pixels.bin $pixels $pixels+$bytes
printf "KILL_NATIVE_ISOLATION frames=%u book=0\n",$frames
continue
if g_stageBState!=3 || (g_trapWord==0xa8cd && g_trapSegment==4 && g_trapOffset==0x3410)
 echo FAIL KillPoly continuation\n
 detach
 quit 1
end
printf "KILL_NEXT trap=%X segment=%X offset=%X routine=%s\n",g_trapWord,g_trapSegment,g_trapOffset,g_trapRoutine
echo PASS native KillPoly and continuation\n
detach
quit 0
