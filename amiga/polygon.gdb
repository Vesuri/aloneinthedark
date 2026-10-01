set pagination off
set confirm off
set width 0
break AitdScreen::showLoudStop
# Resolve the disk-loaded segment once, then observe original instruction
# addresses. A dispatch-wide condition otherwise round-trips on every trap.
tbreak dispatchMacTrap if trap==0xa8ec
continue
set $call=(unsigned long)s_segments[4].begin+0x3396
if g_stageBState==3 || *(unsigned long*)($call-2)!=0x42a7a8cb
 echo FAIL polygon initial caller bytes\n
 detach
 quit 1
end
tbreak *$call
continue
if $pc!=$call
 echo FAIL polygon caller not reached\n
 detach
 quit 1
end
tbreak dispatchMacTrap
continue
set $poly=0
set $n=1
while $n<=13
 if g_stageBState==3
  echo FAIL polygon stopped before expected entry\n
  detach
  quit 1
 end
 set $psp=(unsigned long)userStack
 set $pret=*(unsigned long*)(frame+2)+2
 set $ptrap=trap
 set $port=*(unsigned long*)s_qdThePort
 set $offset=0x3396
 set $word=0xa8cb
 set $prefix=0x42a7
 set $pop=0
 if $n==2
  set $offset=0x33b8
  set $word=0xa893
  set $prefix=0x3f00
  set $pop=4
 end
 if $n>2 && $n<13
  set $offset=0x33ce
  set $word=0xa891
  set $prefix=0x3f00
  set $pop=4
 end
 if $n==13
  set $offset=0x33dc
  set $word=0xa8cc
  set $prefix=0x6ee4
 end
 if $pret!=(unsigned long)s_segments[4].begin+$offset+2 || *(unsigned short*)($pret-2)!=$word || *(unsigned short*)($pret-4)!=$prefix
  echo FAIL polygon original caller bytes\n
  detach
  quit 1
 end
 printf "POLY_ENTER n=%u trap=%X sp=%X args=%08X port=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$n,$ptrap,$psp,*(unsigned long*)$psp,$port,regs[0],regs[1],regs[2],regs[3],regs[4],regs[5],regs[6],regs[7],regs[8],regs[9],regs[10],regs[11],regs[12],regs[13],regs[14]
 eval "dump binary memory ../tmp/polygon-native-%u-ENTER-port.bin $port $port+108",$n
 if $n==1
  set $pm=*(unsigned long*)*(unsigned long*)($port+2)
  set $pixels=*(unsigned long*)$pm
  set $bytes=(*(unsigned short*)($pm+4)&0x3fff)*(*(short*)($pm+10)-*(short*)($pm+6))
  set $frames=g_macFramesQueued
  dump binary memory ../tmp/polygon-native-ENTER-pixels.bin $pixels $pixels+$bytes
  dump binary memory ../tmp/polygon-native-ENTER-pm.bin $pm $pm+50
 end
 tbreak *$pret if $sp==$psp+$pop
 continue
 if g_stageBState==3 || $pc!=$pret || $sp!=$psp+$pop
  echo FAIL polygon original return\n
  detach
  quit 1
 end
 if $n==1
  set $poly=*(unsigned long*)$psp
 end
 set $body=*(unsigned long*)$poly
 set $size=*(unsigned short*)$body
 if !$poly || $size<10 || $size>32766
  echo FAIL polygon returned extent\n
  detach
  quit 1
 end
 printf "POLY_RETURN n=%u trap=%X sp=%X port=%X poly=%X body=%X size=%X memerr=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$n,$ptrap,$sp,$port,$poly,$body,$size,s_memoryError,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
 eval "dump binary memory ../tmp/polygon-native-%u-RETURN-port.bin $port $port+108",$n
 eval "dump binary memory ../tmp/polygon-native-%u-RETURN-poly.bin $body $body+$size",$n
 if $n<13
  set $call=(unsigned long)s_segments[4].begin+0x33ce
  if $n==1
   set $call=(unsigned long)s_segments[4].begin+0x33b8
  end
  if $n==12
   set $call=(unsigned long)s_segments[4].begin+0x33dc
  end
  tbreak *$call
  continue
  if $pc!=$call
   echo FAIL polygon next original instruction\n
   detach
   quit 1
  end
  tbreak dispatchMacTrap
  continue
 end
 set $n=$n+1
end
dump binary memory ../tmp/polygon-native-RETURN-pixels.bin $pixels $pixels+$bytes
dump binary memory ../tmp/polygon-native-RETURN-pm.bin $pm $pm+50
set $zone=(unsigned long)s_applicationZone.arena_
set $block=$zone+64
set $found=0
while $block<$zone+s_applicationZone.end_
 set $span=*(unsigned long*)$block
 if $span<24
  echo FAIL polygon malformed heap\n
  detach
  quit 1
 end
 if *(unsigned long*)($block+12)==3
  set $count=*(unsigned long*)($block+8)
  set $masters=$block+24
  if $poly>=$masters && $poly<$masters+4*$count && ($poly-$masters)%4==0
   set $flags=*(unsigned char*)($masters+4*$count+($poly-$masters)/4)
   set $found=1
  end
 end
 set $block=$block+$span
end
if !$found || *(unsigned long*)($body-12)!=2 || *(unsigned long*)($body-16)!=$poly-$zone || *(unsigned long*)($body-20)!=54 || ($flags&0xe0)!=0 || g_macFramesQueued!=$frames || g_introSkipState!=2 || g_macBookFramesCompleted!=0
 echo FAIL polygon ownership or drawing isolation\n
 detach
 quit 1
end
printf "POLY_OWNER size=%u flags=%u owned=1 frames=%u book=%u\n",*(unsigned long*)($body-20),$flags&0xe0,$frames,g_macBookFramesCompleted
continue
if g_stageBState!=3 || g_trapWord!=0xa8da || g_trapSegment!=4 || g_trapOffset!=0x33e8
 echo FAIL polygon next stop\n
 detach
 quit 1
end
echo PASS native polygon recording; next stop OpenRgn\n
detach
quit 0
