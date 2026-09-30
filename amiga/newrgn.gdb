set pagination off
set confirm off
set width 0
break AitdScreen::showLoudStop
tbreak dispatchMacTrap if trap==0xa8d8 && *(unsigned long*)(frame+2)==(unsigned long)s_segments[10].begin+0x1da6
continue
set $dark=s_segments[10].begin
set $args=(unsigned long)userStack
set $zone=(unsigned long)s_currentZone->arena_
printf "RGN_ENTER sp=%X result=%X zone=%X memerr=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$args,*(unsigned long*)$args,$zone,s_memoryError,regs[0],regs[1],regs[2],regs[3],regs[4],regs[5],regs[6],regs[7],regs[8],regs[9],regs[10],regs[11],regs[12],regs[13],regs[14]
printf "RGN_BYTES data=%04X%04X%04X%04X%04X%04X%04X\n",*(unsigned short*)($dark+0x1d9c),*(unsigned short*)($dark+0x1d9e),*(unsigned short*)($dark+0x1da0),*(unsigned short*)($dark+0x1da2),*(unsigned short*)($dark+0x1da4),*(unsigned short*)($dark+0x1da6),*(unsigned short*)($dark+0x1da8)
tbreak *($dark+0x1da8)
continue
if $pc!=$dark+0x1da8
 echo FAIL NewRgn return\n
 detach
 quit 1
end
set $handle=*(unsigned long*)$sp
set $body=*(unsigned long*)$handle
printf "RGN_RETURN sp=%X handle=%X body=%X zone=%X memerr=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$sp,$handle,$body,$zone,s_memoryError,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
dump binary memory ../tmp/newrgn-native.bin (char*)$body (char*)$body+10
set $found=0
set $block=$zone+64
while $block<$zone+s_currentZone->end_
 set $span=*(unsigned long*)$block
 if $span<24
  echo FAIL malformed heap block\n
  detach
  quit 1
 end
 if *(unsigned long*)($block+12)==3
  set $count=*(unsigned long*)($block+8)
  set $masters=$block+24
  if $handle>=$masters && $handle<$masters+4*$count && ($handle-$masters)%4==0
   set $flags=*(unsigned char*)($masters+4*$count+($handle-$masters)/4)
   set $found=1
  end
 end
 set $block=$block+$span
end
if !$found || *(unsigned long*)($body-12)!=2 || *(unsigned long*)($body-16)!=$handle-$zone
 echo FAIL NewRgn heap ownership\n
 detach
 quit 1
end
printf "RGN_NATIVE size=%X flags=%X owner=%X zone=%X memerr=%X\n",*(unsigned long*)($body-20),$flags&0xe0,$zone,$zone,s_memoryError
echo PASS native NewRgn\n
continue
printf "RGN_NEXT state=%u trap=%X selector=%X segment=%u offset=%X manager=%s routine=%s windows=%u services=%u/%u\n",g_stageBState,g_trapWord,g_trapSelector,g_trapSegment,g_trapOffset,g_trapManager,g_trapRoutine,g_systemWindows,g_macServiceEntered,g_macServiceCompleted
printf "RGN_COUNTS app=%u/%u overlay=%u/%u prep=%u/%u resources=%u\n",g_resourceRuntimeReads,g_resourceRuntimeBytes,g_overlayRuntimeReads,g_overlayRuntimeBytes,g_overlaySourceReads,g_overlaySourceBytes,g_resourceCount
if g_stageBState!=3 || g_trapWord!=0xaa95 || g_trapSelector!=-1 || g_trapSegment!=5 || g_trapOffset!=0x20cc || g_macServiceActive!=0
 echo FAIL NewRgn progression\n
 detach
 quit 1
end
set $i=0
while $i<g_resourceCount
 if s_resourceForks.m_items[$i].item.type==0x4d445256 && s_resourceHandles[$i]!=0
  echo FAIL original MDRV resident\n
  detach
  quit 1
 end
 set $i=$i+1
end
echo PASS native NewRgn next-stop original-MDRV=absent\n
detach
quit 0
