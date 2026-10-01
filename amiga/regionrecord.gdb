set pagination off
set confirm off
set width 0
break AitdScreen::showLoudStop
tbreak dispatchMacTrap if trap==0xa8ec
continue
set $call=(unsigned long)s_segments[4].begin+0x33e0
if g_stageBState==3 || *(unsigned long*)($call-2)!=0x42a7a8d8
 echo FAIL region initial caller bytes\n
 detach
 quit 1
end
tbreak *$call
continue
if $pc!=$call
 echo FAIL region caller not reached\n
 detach
 quit 1
end
set $n=14
set $region=0
while $n<=17
 tbreak dispatchMacTrap
 continue
 if g_stageBState==3
  echo FAIL region stopped before entry\n
  detach
  quit 1
 end
 set $psp=(unsigned long)userStack
 set $pret=*(unsigned long*)(frame+2)+2
 set $ptrap=trap
 set $port=*(unsigned long*)s_qdThePort
 set $pop=0
 if $n>=16
  set $pop=4
 end
 printf "RREC_ENTER n=%u trap=%X sp=%X args=%08X port=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$n,$ptrap,$psp,*(unsigned long*)$psp,$port,regs[0],regs[1],regs[2],regs[3],regs[4],regs[5],regs[6],regs[7],regs[8],regs[9],regs[10],regs[11],regs[12],regs[13],regs[14]
 eval "dump binary memory ../tmp/regionrecord-native-%u-ENTER-port.bin $port $port+108",$n
 if $n==14
  set $pm=*(unsigned long*)*(unsigned long*)($port+2)
  set $pixels=*(unsigned long*)$pm
  set $bytes=(*(unsigned short*)($pm+4)&0x3fff)*(*(short*)($pm+10)-*(short*)($pm+6))
  set $frames=g_macFramesQueued
  dump binary memory ../tmp/regionrecord-native-ENTER-pixels.bin $pixels $pixels+$bytes
 end
 tbreak *$pret if $sp==$psp+$pop
 continue
 if g_stageBState==3 || $pc!=$pret || $sp!=$psp+$pop
  echo FAIL region return\n
  detach
  quit 1
 end
 if $n==14
  set $region=*(unsigned long*)$psp
 end
 set $body=*(unsigned long*)$region
 set $size=*(unsigned short*)$body
 if !$region || $size<10 || $size>4096
  echo FAIL region returned extent\n
  detach
  quit 1
 end
 printf "RREC_RETURN n=%u trap=%X sp=%X port=%X region=%X body=%X size=%X memerr=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$n,$ptrap,$sp,$port,$region,$body,$size,s_memoryError,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
 eval "dump binary memory ../tmp/regionrecord-native-%u-RETURN-port.bin $port $port+108",$n
 eval "dump binary memory ../tmp/regionrecord-native-%u-RETURN-region.bin $body $body+$size",$n
 if $n<17
  set $call=(unsigned long)s_segments[4].begin+0x33e8
  if $n==15
   set $call=(unsigned long)s_segments[4].begin+0x33ec
  end
  if $n==16
   set $call=(unsigned long)s_segments[4].begin+0x33f0
  end
  tbreak *$call
  continue
  if $pc!=$call
   echo FAIL region next instruction\n
   detach
   quit 1
  end
 end
 set $n=$n+1
end
dump binary memory ../tmp/regionrecord-native-RETURN-pixels.bin $pixels $pixels+$bytes
set $zone=(unsigned long)s_applicationZone.arena_
if *(unsigned long*)($body-12)!=2 || *(unsigned long*)($body-16)!=$region-$zone || *(unsigned long*)($body-20)!=252 || *(unsigned short*)($port+66)!=0 || *(unsigned long*)($port+96)!=0 || g_macFramesQueued!=$frames || g_introSkipState!=2 || g_macBookFramesCompleted!=0
 echo FAIL region ownership or recording isolation\n
 detach
 quit 1
end
printf "RREC_OWNER size=%u owned=1 frames=%u book=%u\n",*(unsigned long*)($body-20),$frames,g_macBookFramesCompleted
continue
if g_stageBState!=3 || g_trapWord!=0xa8e1 || g_trapSegment!=4 || g_trapOffset!=0x33f8
 echo FAIL region next stop\n
 detach
 quit 1
end
echo PASS native polygon region recording; next stop InsetRgn\n
detach
quit 0
