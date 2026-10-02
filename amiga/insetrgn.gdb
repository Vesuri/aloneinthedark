set pagination off
set confirm off
set width 0
break AitdScreen::showLoudStop
tbreak dispatchMacTrap if trap==0xa8ec
continue
# ExecBase stack bounds, using the SDK's SysStkUpper/Lower offsets.
set $exec=*(unsigned long*)4
printf "INSET_SYSTEM_STACK lower=%X upper=%X\n",*(unsigned long*)($exec+58),*(unsigned long*)($exec+54)
set $call=(unsigned long)s_segments[4].begin+0x33f8
if g_stageBState==3 || *(unsigned long*)($call-6)!=0x2f0a4878 || *(unsigned long*)($call-2)!=0xffffa8e1
 echo FAIL InsetRgn caller bytes\n
 detach
 quit 1
end
tbreak *$call
continue
if $pc!=$call
 echo FAIL InsetRgn caller not reached\n
 detach
 quit 1
end
# Observe the dispatcher too: distinguish trap delivery from helper execution.
tbreak dispatchMacTrap
continue
if g_stageBState==3 || trap!=0xa8e1
 echo FAIL InsetRgn dispatch entry\n
 info registers
 bt
 detach
 quit 1
end
set $insetStart=g_macTicks
printf "INSET_DISPATCH sp=%X user=%X frame=%X trap=%X\n",$sp,userStack,frame,trap
set $savedsp=(unsigned long)userStack
set $region=*(unsigned long*)($savedsp+4)
set $body=*(unsigned long*)$region
set $size=*(unsigned short*)$body
set $port=*(unsigned long*)s_qdThePort
set $pm=*(unsigned long*)*(unsigned long*)($port+2)
set $pixels=*(unsigned long*)$pm
set $bytes=(*(unsigned short*)($pm+4)&0x3fff)*(*(short*)($pm+10)-*(short*)($pm+6))
set $frames=g_macFramesQueued
printf "INSET_NATIVE_ENTER sp=%X distances=%X region=%X size=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$savedsp,*(unsigned long*)$savedsp,$region,$size,regs[0],regs[1],regs[2],regs[3],regs[4],regs[5],regs[6],regs[7],regs[8],regs[9],regs[10],regs[11],regs[12],regs[13],regs[14]
dump binary memory ../tmp/inset-native-ENTER-region.bin $body $body+$size
dump binary memory ../tmp/inset-native-ENTER-port.bin $port $port+108
dump binary memory ../tmp/inset-native-ENTER-pixels.bin $pixels $pixels+$bytes
tbreak *($call+2) if $sp==$savedsp+8
continue
if g_stageBState==3 || $pc!=$call+2 || $sp!=$savedsp+8
 echo FAIL InsetRgn return\n
 info registers
 bt
 detach
 quit 1
end
set $body=*(unsigned long*)$region
set $size=*(unsigned short*)$body
printf "INSET_NATIVE_RETURN sp=%X region=%X size=%X memerr=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$sp,$region,$size,s_memoryError,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
dump binary memory ../tmp/inset-native-RETURN-region.bin $body $body+$size
dump binary memory ../tmp/inset-native-RETURN-port.bin $port $port+108
dump binary memory ../tmp/inset-native-RETURN-pixels.bin $pixels $pixels+$bytes
set $zone=(unsigned long)s_applicationZone.arena_
set $block=$zone+64
set $found=0
while $block<$zone+s_applicationZone.end_
 set $span=*(unsigned long*)$block
 if $span<24
  echo FAIL InsetRgn heap\n
  detach
  quit 1
 end
 if *(unsigned long*)($block+12)==3
  set $count=*(unsigned long*)($block+8)
  set $masters=$block+24
  if $region>=$masters && $region<$masters+4*$count && ($region-$masters)%4==0
   set $flags=*(unsigned char*)($masters+4*$count+($region-$masters)/4)
   set $found=1
  end
 end
 set $block=$block+$span
end
if !$found || ($flags&0xe0)!=0 || *(unsigned long*)($body-12)!=2 || *(unsigned long*)($body-16)!=$region-$zone || *(unsigned long*)($body-20)!=244 || g_macFramesQueued!=$frames || g_introSkipState!=2 || g_macBookFramesCompleted!=0
 echo FAIL InsetRgn ownership or drawing isolation\n
 detach
 quit 1
end
printf "INSET_NATIVE_OWNER size=244 flags=0 owned=1 frames=%u book=0\n",$frames
printf "INSET_COST ticks=%u\n",g_macTicks-$insetStart
echo PASS native InsetRgn measured original return\n
detach
quit 0
