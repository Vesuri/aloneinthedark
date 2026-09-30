set pagination off
set confirm off
set width 0
break AitdScreen::showLoudStop
tbreak dispatchMacTrap if trap==0xa880 && *(unsigned long*)(frame+2)==(unsigned long)s_segments[4].begin+0x4f88
continue
set $dark=s_segments[4].begin
set $args=(unsigned long)userStack
set $point=*(unsigned long*)($args+4)
printf "POINT_ENTER sp=%X point=%X args=%08X%08X value=%08X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$args,$point,*(unsigned long*)$args,*(unsigned long*)($args+4),*(unsigned long*)$point,regs[0],regs[1],regs[2],regs[3],regs[4],regs[5],regs[6],regs[7],regs[8],regs[9],regs[10],regs[11],regs[12],regs[13],regs[14]
printf "POINT_BYTES data=%04X%04X%04X%04X%04X%04X%04X%04X\n",*(unsigned short*)($dark+0x4f7a),*(unsigned short*)($dark+0x4f7c),*(unsigned short*)($dark+0x4f7e),*(unsigned short*)($dark+0x4f80),*(unsigned short*)($dark+0x4f82),*(unsigned short*)($dark+0x4f84),*(unsigned short*)($dark+0x4f86),*(unsigned short*)($dark+0x4f88)
dump binary memory ../tmp/point-native-before.bin (char*)$point-4 (char*)$point+8
tbreak *($dark+0x4f8a)
continue
if $pc!=$dark+0x4f8a
 echo FAIL SetPt return\n
 detach
 quit 1
end
printf "POINT_RETURN sp=%X value=%08X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$sp,*(unsigned long*)$point,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
dump binary memory ../tmp/point-native-after.bin (char*)$point-4 (char*)$point+8
echo PASS native SetPt\n
continue
printf "POINT_NEXT state=%u trap=%X selector=%X segment=%u offset=%X manager=%s routine=%s windows=%u services=%u/%u\n",g_stageBState,g_trapWord,g_trapSelector,g_trapSegment,g_trapOffset,g_trapManager,g_trapRoutine,g_systemWindows,g_macServiceEntered,g_macServiceCompleted
printf "POINT_COUNTS app=%u/%u overlay=%u/%u prep=%u/%u resources=%u\n",g_resourceRuntimeReads,g_resourceRuntimeBytes,g_overlayRuntimeReads,g_overlayRuntimeBytes,g_overlaySourceReads,g_overlaySourceBytes,g_resourceCount
if g_stageBState!=3 || g_trapWord!=0xa0f8 || g_trapSegment!=3 || g_trapOffset!=0xfc8 || g_trapSelector!=15 || g_macServiceActive!=1 || g_macServiceActive!=1
 echo FAIL SetPt progression\n
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
echo PASS native SetPt next-stop original-MDRV=absent\n
detach
quit 0
