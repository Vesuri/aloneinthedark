set pagination off
set confirm off
set width 0
source .run/startup-state.gdb
break AitdScreen::showLoudStop
tbreak dispatchMacTrap if trap==0xa816
continue
set $engine=s_segments[7].begin
set $args=(unsigned long)userStack
set $initial_regs=regs
if *(unsigned long*)(frame+2)!=(unsigned long)$engine+0x1038
 echo FAIL Apple Events first call\n
 detach
 quit 1
end
echo ARM native apple-events original bytes\n
set $r_d0=$initial_regs[0]
set $r_d1=$initial_regs[1]
set $r_d2=$initial_regs[2]
set $r_d3=$initial_regs[3]
set $r_d4=$initial_regs[4]
set $r_d5=$initial_regs[5]
set $r_d6=$initial_regs[6]
set $r_d7=$initial_regs[7]
set $r_a0=$initial_regs[8]
set $r_a1=$initial_regs[9]
set $r_a2=$initial_regs[10]
set $r_a3=$initial_regs[11]
set $r_a4=$initial_regs[12]
set $r_a5=$initial_regs[13]
set $r_a6=$initial_regs[14]
if *(unsigned long*)($engine+0x1034)!=0x303c091f || *(unsigned short*)($engine+0x1038)!=0xa816
 echo FAIL Apple Events original bytes\n
 detach
 quit 1
end
printf "AE_ENTER seq=1 site=1038 sp=%X selector=%X engine=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$args,$r_d0&65535,$engine,$r_d0,$r_d1,$r_d2,$r_d3,$r_d4,$r_d5,$r_d6,$r_d7,$r_a0,$r_a1,$r_a2,$r_a3,$r_a4,$r_a5,$r_a6
printf "AE_ARGS seq=1 data=%08X%08X%08X%08X%08X\n",*(unsigned long*)($args+0),*(unsigned long*)($args+4),*(unsigned long*)($args+8),*(unsigned long*)($args+12),*(unsigned long*)($args+16)
printf "AE_BYTES seq=1 selector=91F trap=A816\n"
tbreak *($engine+0x103a)
continue
if $pc!=$engine+0x103a
 echo FAIL Apple Events return not reached\n
 detach
 quit 1
end
printf "AE_RETURN seq=1 sp=%X result=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$sp,*(unsigned short*)$sp,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
tbreak *($engine+0x1056)
continue
set $args=$sp
if $pc!=$engine+0x1056
 echo FAIL Apple Events call not reached\n
 detach
 quit 1
end
set $r_d0=(unsigned long)$d0
set $r_d1=(unsigned long)$d1
set $r_d2=(unsigned long)$d2
set $r_d3=(unsigned long)$d3
set $r_d4=(unsigned long)$d4
set $r_d5=(unsigned long)$d5
set $r_d6=(unsigned long)$d6
set $r_d7=(unsigned long)$d7
set $r_a0=(unsigned long)$a0
set $r_a1=(unsigned long)$a1
set $r_a2=(unsigned long)$a2
set $r_a3=(unsigned long)$a3
set $r_a4=(unsigned long)$a4
set $r_a5=(unsigned long)$a5
set $r_a6=(unsigned long)$a6
if *(unsigned long*)($engine+0x1052)!=0x303c091f || *(unsigned short*)($engine+0x1056)!=0xa816
 echo FAIL Apple Events original bytes\n
 detach
 quit 1
end
printf "AE_ENTER seq=2 site=1056 sp=%X selector=%X engine=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$args,$r_d0&65535,$engine,$r_d0,$r_d1,$r_d2,$r_d3,$r_d4,$r_d5,$r_d6,$r_d7,$r_a0,$r_a1,$r_a2,$r_a3,$r_a4,$r_a5,$r_a6
printf "AE_ARGS seq=2 data=%08X%08X%08X%08X%08X\n",*(unsigned long*)($args+0),*(unsigned long*)($args+4),*(unsigned long*)($args+8),*(unsigned long*)($args+12),*(unsigned long*)($args+16)
printf "AE_BYTES seq=2 selector=91F trap=A816\n"
tbreak *($engine+0x1058)
continue
if $pc!=$engine+0x1058
 echo FAIL Apple Events return not reached\n
 detach
 quit 1
end
printf "AE_RETURN seq=2 sp=%X result=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$sp,*(unsigned short*)$sp,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
tbreak *($engine+0x1074)
continue
set $args=$sp
if $pc!=$engine+0x1074
 echo FAIL Apple Events call not reached\n
 detach
 quit 1
end
set $r_d0=(unsigned long)$d0
set $r_d1=(unsigned long)$d1
set $r_d2=(unsigned long)$d2
set $r_d3=(unsigned long)$d3
set $r_d4=(unsigned long)$d4
set $r_d5=(unsigned long)$d5
set $r_d6=(unsigned long)$d6
set $r_d7=(unsigned long)$d7
set $r_a0=(unsigned long)$a0
set $r_a1=(unsigned long)$a1
set $r_a2=(unsigned long)$a2
set $r_a3=(unsigned long)$a3
set $r_a4=(unsigned long)$a4
set $r_a5=(unsigned long)$a5
set $r_a6=(unsigned long)$a6
if *(unsigned long*)($engine+0x1070)!=0x303c091f || *(unsigned short*)($engine+0x1074)!=0xa816
 echo FAIL Apple Events original bytes\n
 detach
 quit 1
end
printf "AE_ENTER seq=3 site=1074 sp=%X selector=%X engine=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$args,$r_d0&65535,$engine,$r_d0,$r_d1,$r_d2,$r_d3,$r_d4,$r_d5,$r_d6,$r_d7,$r_a0,$r_a1,$r_a2,$r_a3,$r_a4,$r_a5,$r_a6
printf "AE_ARGS seq=3 data=%08X%08X%08X%08X%08X\n",*(unsigned long*)($args+0),*(unsigned long*)($args+4),*(unsigned long*)($args+8),*(unsigned long*)($args+12),*(unsigned long*)($args+16)
printf "AE_BYTES seq=3 selector=91F trap=A816\n"
tbreak *($engine+0x1076)
continue
if $pc!=$engine+0x1076
 echo FAIL Apple Events return not reached\n
 detach
 quit 1
end
printf "AE_RETURN seq=3 sp=%X result=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$sp,*(unsigned short*)$sp,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
tbreak *($engine+0x1092)
continue
set $args=$sp
if $pc!=$engine+0x1092
 echo FAIL Apple Events call not reached\n
 detach
 quit 1
end
set $r_d0=(unsigned long)$d0
set $r_d1=(unsigned long)$d1
set $r_d2=(unsigned long)$d2
set $r_d3=(unsigned long)$d3
set $r_d4=(unsigned long)$d4
set $r_d5=(unsigned long)$d5
set $r_d6=(unsigned long)$d6
set $r_d7=(unsigned long)$d7
set $r_a0=(unsigned long)$a0
set $r_a1=(unsigned long)$a1
set $r_a2=(unsigned long)$a2
set $r_a3=(unsigned long)$a3
set $r_a4=(unsigned long)$a4
set $r_a5=(unsigned long)$a5
set $r_a6=(unsigned long)$a6
if *(unsigned long*)($engine+0x108e)!=0x303c091f || *(unsigned short*)($engine+0x1092)!=0xa816
 echo FAIL Apple Events original bytes\n
 detach
 quit 1
end
printf "AE_ENTER seq=4 site=1092 sp=%X selector=%X engine=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$args,$r_d0&65535,$engine,$r_d0,$r_d1,$r_d2,$r_d3,$r_d4,$r_d5,$r_d6,$r_d7,$r_a0,$r_a1,$r_a2,$r_a3,$r_a4,$r_a5,$r_a6
printf "AE_ARGS seq=4 data=%08X%08X%08X%08X%08X\n",*(unsigned long*)($args+0),*(unsigned long*)($args+4),*(unsigned long*)($args+8),*(unsigned long*)($args+12),*(unsigned long*)($args+16)
printf "AE_BYTES seq=4 selector=91F trap=A816\n"
tbreak *($engine+0x1094)
continue
if $pc!=$engine+0x1094
 echo FAIL Apple Events return not reached\n
 detach
 quit 1
end
printf "AE_RETURN seq=4 sp=%X result=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$sp,*(unsigned short*)$sp,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
printf "AE_TABLE count=%u\n",g_appleEventHandlers.count
set $i=0
while $i<g_appleEventHandlers.count
 printf "AE_ENTRY index=%u class=%X id=%X handler=%X refcon=%X\n",$i,g_appleEventHandlers.entries[$i].eventClass,g_appleEventHandlers.entries[$i].eventID,g_appleEventHandlers.entries[$i].handler,g_appleEventHandlers.entries[$i].refCon
 set $i=$i+1
end
echo PASS native Apple Event registrations calls=4\n
continue
printf "AE_NEXT state=%u trap=%X selector=%X segment=%u offset=%X manager=%s routine=%s windows=%u services=%u/%u\n",g_stageBState,g_trapWord,g_trapSelector,g_trapSegment,g_trapOffset,g_trapManager,g_trapRoutine,g_systemWindows,g_macServiceEntered,g_macServiceCompleted
if g_stageBState!=3 || g_trapWord!=0xaa91 || g_trapSelector!=-1 || g_trapSegment!=5 || g_trapOffset!=0x201c || *(unsigned long*)(g_trapRoutine+0)!=0x4e455750 || *(unsigned long*)(g_trapRoutine+4)!=0x414c4554 || *(unsigned short*)(g_trapRoutine+8)!=0x5445 || *(unsigned char*)(g_trapRoutine+10)!=0 || g_macServiceActive!=0 || g_systemWindows!=$startup_windows || g_macServiceEntered!=$startup_entered || g_macServiceCompleted!=$startup_completed || g_resourceRuntimeReads!=65 || g_resourceRuntimeBytes!=297034 || g_overlayRuntimeReads!=31 || g_overlayRuntimeBytes!=80650 || g_appleEventHandlers.count!=4
 echo FAIL Apple Event next stop/counters\n
 detach
 quit 1
end
if *(unsigned short*)($engine+0x1172)!=0xaa95
 echo FAIL next SetPalette original bytes\n
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
echo PASS native Apple Event startup next=NEWPALETTE original-MDRV=absent\n
detach
quit 0
