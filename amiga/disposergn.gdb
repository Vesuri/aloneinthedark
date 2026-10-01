set pagination off
set confirm off
set width 0
break AitdScreen::showLoudStop
tbreak dispatchMacTrap if trap==0xa8ec
continue
set $call=(unsigned long)s_segments[4].begin+0x3058
if g_stageBState==3 || *(unsigned long*)($call-2)!=0x2f14a8d9
 echo FAIL DisposeRgn caller bytes\n
 detach
 quit 1
end
tbreak *$call
continue
if $pc!=$call
 echo FAIL DisposeRgn caller not reached\n
 detach
 quit 1
end
tbreak dispatchMacTrap
continue
if g_stageBState==3 || trap!=0xa8d9
 echo FAIL DisposeRgn dispatch entry\n
 detach
 quit 1
end
# Generic safe-point work publishes the preceding masked CopyBits first.
# Capture the disposal service only after that shared trap-entry work.
tbreak MacLoader.cpp:7679
continue
# The compiler attributes this boundary to inline read32; select its caller.
up
if g_stageBState==3 || trap!=0xa8d9
 echo FAIL DisposeRgn service boundary\n
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
set $region=*(unsigned long*)(*(unsigned long*)s_qdThePort+28)
set $rbody=*(unsigned long*)$region
set $rsize=*(unsigned short*)$rbody
set $port=*(unsigned long*)s_qdThePort
set $pm=*(unsigned long*)*(unsigned long*)($port+2)
set $pixels=*(unsigned long*)$pm
set $bytes=(*(unsigned short*)($pm+4)&0x3fff)*(*(short*)($pm+10)-*(short*)($pm+6))
set $frames=g_macFramesQueued
set $block=$zone+64
set $flag=0
set $successor=0
set $seen=0
while $block<$zone+s_applicationZone.end_
 set $length=*(unsigned long*)$block
 if $length<24
  echo FAIL DisposeRgn heap\n
  detach
  quit 1
 end
 if *(unsigned long*)($block+12)==1 || *(unsigned long*)($block+12)==2
  printf "DRGN_ALLOC_ENTER block=%X span=%X logical=%X owner=%X kind=%X\n",$block,*(unsigned long*)$block,*(unsigned long*)($block+4),*(unsigned long*)($block+8),*(unsigned long*)($block+12)
 end
 if *(unsigned long*)($block+12)==3
  set $count=*(unsigned long*)($block+8)
  set $masters=$block+24
  set $i=0
  while $i<$count
   set $h=$masters+4*$i
   if $h==$poly
    set $seen=1
   end
   if !$seen && !(*(unsigned char*)($masters+4*$count+$i)&1)
    set $successor=$h
   end
   set $i=$i+1
  end
  if $poly>=$masters && $poly<$masters+4*$count && ($poly-$masters)%4==0
   set $flag=$masters+4*$count+($poly-$masters)/4
  end
 end
 set $block=$block+$length
end
if !$flag || *(unsigned long*)($body-12)!=2 || *(unsigned long*)($body-16)!=$poly-$zone || *(unsigned long*)($body-20)!=128 || $size!=128
 echo FAIL DisposeRgn initial ownership\n
 detach
 quit 1
end
printf "DRGN_NATIVE_ENTER sp=%X poly=%X size=%X span=%X free=%X successor=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$savedsp,$poly,$size,$span,$free,$successor,regs[0],regs[1],regs[2],regs[3],regs[4],regs[5],regs[6],regs[7],regs[8],regs[9],regs[10],regs[11],regs[12],regs[13],regs[14]
dump binary memory ../tmp/disposergn-native-ENTER-region.bin $body $body+$size
dump binary memory ../tmp/disposergn-native-ENTER-clip.bin $rbody $rbody+$rsize
dump binary memory ../tmp/disposergn-native-ENTER-port.bin $port $port+108
dump binary memory ../tmp/disposergn-native-ENTER-pm.bin $pm $pm+50
set $ct=*(unsigned long*)*(unsigned long*)($pm+42)
dump binary memory ../tmp/disposergn-native-ENTER-clut.bin $ct $ct+8+8*(*(unsigned short*)($ct+6)+1)
set $vis=*(unsigned long*)*(unsigned long*)($port+24)
dump binary memory ../tmp/disposergn-native-ENTER-vis.bin $vis $vis+*(unsigned short*)$vis
dump binary memory ../tmp/disposergn-native-ENTER-pixels.bin $pixels $pixels+$bytes
tbreak *($call+2) if $sp==$savedsp+4
continue
printf "DRGN_BOUNDARY stage=%u pc=%X expected=%X sp=%X expectedsp=%X master=%X flags=%X free=%X expectedfree=%X frames=%u oldframes=%u skip=%u book=%u\n",g_stageBState,$pc,$call+2,$sp,$savedsp+4,*(unsigned long*)$poly,*(unsigned char*)$flag,*(unsigned long*)($zone+12),$free+$span,g_macFramesQueued,$frames,g_introSkipState,g_macBookFramesCompleted
if g_stageBState==3 || $pc!=$call+2 || $sp!=$savedsp+4 || *(unsigned long*)$poly!=$successor || *(unsigned char*)$flag || *(unsigned long*)($zone+12)!=$free+$span || g_macFramesQueued!=$frames || g_introSkipState!=2 || g_macBookFramesCompleted!=0
 echo FAIL DisposeRgn return, ownership or drawing isolation\n
 detach
 quit 1
end
printf "DRGN_NATIVE_RETURN sp=%X poly=%X free=%X master=%X flags=%X memerr=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$sp,$poly,*(unsigned long*)($zone+12),*(unsigned long*)$poly,*(unsigned char*)$flag,s_memoryError,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
set $rbody=*(unsigned long*)$region
dump binary memory ../tmp/disposergn-native-RETURN-clip.bin $rbody $rbody+$rsize
dump binary memory ../tmp/disposergn-native-RETURN-port.bin $port $port+108
dump binary memory ../tmp/disposergn-native-RETURN-pm.bin $pm $pm+50
set $ct=*(unsigned long*)*(unsigned long*)($pm+42)
dump binary memory ../tmp/disposergn-native-RETURN-clut.bin $ct $ct+8+8*(*(unsigned short*)($ct+6)+1)
set $vis=*(unsigned long*)*(unsigned long*)($port+24)
dump binary memory ../tmp/disposergn-native-RETURN-vis.bin $vis $vis+*(unsigned short*)$vis
dump binary memory ../tmp/disposergn-native-RETURN-pixels.bin $pixels $pixels+$bytes
set $block=$zone+64
while $block<$zone+s_applicationZone.end_
 if *(unsigned long*)($block+12)==1 || *(unsigned long*)($block+12)==2
  printf "DRGN_ALLOC_RETURN block=%X span=%X logical=%X owner=%X kind=%X\n",$block,*(unsigned long*)$block,*(unsigned long*)($block+4),*(unsigned long*)($block+8),*(unsigned long*)($block+12)
 end
 set $block=$block+*(unsigned long*)$block
end
printf "DRGN_NATIVE_ISOLATION frames=%u book=0\n",$frames
tbreak *($call+6)
continue
if g_stageBState==3 || $pc!=$call+6 || *(unsigned long*)$a4!=0
 echo FAIL DisposeRgn continuation\n
 detach
 quit 1
end
printf "DRGN_NEXT offset=%X cleared=%X\n",$pc-(unsigned long)s_segments[4].begin,*(unsigned long*)$a4
echo PASS native DisposeRgn and continuation\n
detach
quit 0
