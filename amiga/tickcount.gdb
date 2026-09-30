set pagination off
set confirm off
set width 0
break AitdScreen::showLoudStop
tbreak dispatchMacTrap if trap==0xa975 && *(unsigned long*)(frame+2)==(unsigned long)s_segments[4].begin+0x41f4
continue
set $dark=s_segments[4].begin
set $args=(unsigned long)userStack
printf "TICK_ENTER sp=%X result=%X ticks=%X bytes=%04X%04X%04X%04X%04X%04X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$args,*(unsigned long*)$args,*g_macTicksAddress,*(unsigned short*)($dark+0x41ec),*(unsigned short*)($dark+0x41ee),*(unsigned short*)($dark+0x41f0),*(unsigned short*)($dark+0x41f2),*(unsigned short*)($dark+0x41f4),*(unsigned short*)($dark+0x41f6),regs[0],regs[1],regs[2],regs[3],regs[4],regs[5],regs[6],regs[7],regs[8],regs[9],regs[10],regs[11],regs[12],regs[13],regs[14]
printf "TICK_CLOCK phase=before ticks=%X fields=%X shadow=%X\n",g_macTicks,g_vbiCount,*g_macTicksAddress
tbreak *($dark+0x41f6)
continue
if $pc!=$dark+0x41f6
 echo FAIL TickCount return\n
 detach
 quit 1
end
printf "TICK_RETURN sp=%X result=%X ticks=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$sp,*(unsigned long*)$sp,*g_macTicksAddress,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
printf "TICK_CLOCK phase=after ticks=%X fields=%X shadow=%X\n",g_macTicks,g_vbiCount,*g_macTicksAddress
echo PASS native TickCount\n
continue
printf "TICK_NEXT state=%u trap=%X selector=%X segment=%u offset=%X manager=%s routine=%s windows=%u services=%u/%u\n",g_stageBState,g_trapWord,g_trapSelector,g_trapSegment,g_trapOffset,g_trapManager,g_trapRoutine,g_systemWindows,g_macServiceEntered,g_macServiceCompleted
printf "TICK_COUNTS app=%u/%u overlay=%u/%u prep=%u/%u resources=%u\n",g_resourceRuntimeReads,g_resourceRuntimeBytes,g_overlayRuntimeReads,g_overlayRuntimeBytes,g_overlaySourceReads,g_overlaySourceBytes,g_resourceCount
if g_stageBState!=3 || g_macServiceActive!=0 || g_trapWord!=0xa8df || g_trapSelector!=0xffffffff || g_trapSegment!=4 || g_trapOffset!=0x3d46
 echo FAIL TickCount progression\n
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
echo PASS native TickCount next-stop original-MDRV=absent\n
detach
quit 0
