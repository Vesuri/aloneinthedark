# Read-only original-code observer; D4 selects item 2 without presentation.
set pagination off
set confirm off
set width 0
source .run/startup-state.gdb
break AitdScreen::showLoudStop
tbreak getFontNumber
continue
set $core=s_segments[3].begin
set $engine=s_segments[7].begin
tbreak *($core+0x502)
continue
set $pref=**(unsigned long**)($a5-0x11b54)+4
printf "CHOICE_PREF before=%08X%08X%04X\n",*(unsigned long*)$pref,*(unsigned long*)($pref+4),*(unsigned short*)($pref+8)
tbreak *($engine+0x48a4)
continue
set $dan=s_segments[13].begin
tbreak *($dan+0x30fe)
continue
if $pc!=$dan+0x30fe || *(unsigned short*)$pc!=0xa991
 echo FAIL original service site\n
 detach
 quit 1
end
set $args=$sp
printf "SERVICE_ENTER label=MODAL seq=1 sp=%X port=%X windows=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$sp,*(unsigned long*)s_qdThePort,s_windowList,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
printf "SERVICE_ARGS seq=1 data=%08X%08X%08X%08X%08X%08X\n",*(unsigned long*)($args+0),*(unsigned long*)($args+4),*(unsigned long*)($args+8),*(unsigned long*)($args+12),*(unsigned long*)($args+16),*(unsigned long*)($args+20)
set $out=*(unsigned long*)$args
set $dialog=s_windowList
set $wmgr=*(unsigned long*)s_qdThePort
printf "MODAL_BEFORE seq=1 data=%08X\n",*(unsigned long*)$out
printf "MODAL_POLICY visible=%u filterOffset=%X\n",*(unsigned char*)($dialog+110),*(unsigned long*)($args+4)-(unsigned long)$a5
tbreak *($dan+0x3100)
continue
printf "SERVICE_RETURN label=MODAL seq=1 sp=%X port=%X windows=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$sp,*(unsigned long*)s_qdThePort,s_windowList,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
if $pc!=$dan+0x3100 || $sp!=$args+8
 echo FAIL service return\n
 detach
 quit 1
end
printf "MODAL_AFTER seq=1 data=%08X\n",*(unsigned long*)$out
tbreak *($dan+0x348a)
continue
if $pc!=$dan+0x348a || *(unsigned short*)$pc!=0xa98d
 echo FAIL original service site\n
 detach
 quit 1
end
set $args=$sp
printf "SERVICE_ENTER label=ITEM seq=2 sp=%X port=%X windows=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$sp,*(unsigned long*)s_qdThePort,s_windowList,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
printf "SERVICE_ARGS seq=2 data=%08X%08X%08X%08X%08X%08X\n",*(unsigned long*)($args+0),*(unsigned long*)($args+4),*(unsigned long*)($args+8),*(unsigned long*)($args+12),*(unsigned long*)($args+16),*(unsigned long*)($args+20)
set $rect=*(unsigned long*)$args
set $hout=*(unsigned long*)($args+4)
set $tout=*(unsigned long*)($args+8)
set $items=**(unsigned long**)($dialog+156)
printf "ITEM_REQUEST number=%X dialog=%X handle=%X\n",*(unsigned short*)($args+12),*(unsigned long*)($args+14),*(unsigned long*)($items+26)
tbreak *($dan+0x348c)
continue
printf "SERVICE_RETURN label=ITEM seq=2 sp=%X port=%X windows=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$sp,*(unsigned long*)s_qdThePort,s_windowList,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
if $pc!=$dan+0x348c || $sp!=$args+18
 echo FAIL service return\n
 detach
 quit 1
end
printf "ITEM_RESULT type=%X handle=%X rect=%08X%08X\n",*(unsigned short*)$tout,*(unsigned long*)$hout,*(unsigned long*)$rect,*(unsigned long*)($rect+4)
tbreak *($dan+0x3452)
continue
if $pc!=$dan+0x3452 || *(unsigned short*)$pc!=0xa983
 echo FAIL original service site\n
 detach
 quit 1
end
set $args=$sp
printf "SERVICE_ENTER label=DISPOSE seq=3 sp=%X port=%X windows=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$sp,*(unsigned long*)s_qdThePort,s_windowList,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
printf "SERVICE_ARGS seq=3 data=%08X%08X%08X%08X%08X%08X\n",*(unsigned long*)($args+0),*(unsigned long*)($args+4),*(unsigned long*)($args+8),*(unsigned long*)($args+12),*(unsigned long*)($args+16),*(unsigned long*)($args+20)
set $slot=0
while $slot<8 && s_windows[$slot].window!=(unsigned char*)$dialog
 set $slot=$slot+1
end
if $slot>=8
 echo FAIL missing dialog owner\n
 detach
 quit 1
end
set $arena=s_applicationZone.arena_
set $freeBefore=*(unsigned long*)($arena+12)
set $h0=(unsigned long)s_windows[$slot].ownedDialogHandles[0]
set $block=64
set $flag0=0
while $block<s_applicationZone.end_
 if *(unsigned long*)($arena+$block+12)==3
  set $start=(unsigned long)$arena+$block+24
  set $count=*(unsigned long*)($arena+$block+8)
  if $h0>=$start && $h0<$start+4*$count
   set $flag0=$start+4*$count+($h0-$start)/4
  end
 end
 set $block=$block+*(unsigned long*)($arena+$block)
end
if $flag0==0 || (*(unsigned char*)$flag0&1)==0
 echo FAIL dialog handle not allocated\n
 detach
 quit 1
end
set $h1=(unsigned long)s_windows[$slot].ownedDialogHandles[1]
set $block=64
set $flag1=0
while $block<s_applicationZone.end_
 if *(unsigned long*)($arena+$block+12)==3
  set $start=(unsigned long)$arena+$block+24
  set $count=*(unsigned long*)($arena+$block+8)
  if $h1>=$start && $h1<$start+4*$count
   set $flag1=$start+4*$count+($h1-$start)/4
  end
 end
 set $block=$block+*(unsigned long*)($arena+$block)
end
if $flag1==0 || (*(unsigned char*)$flag1&1)==0
 echo FAIL dialog handle not allocated\n
 detach
 quit 1
end
set $h2=(unsigned long)s_windows[$slot].ownedDialogHandles[2]
set $block=64
set $flag2=0
while $block<s_applicationZone.end_
 if *(unsigned long*)($arena+$block+12)==3
  set $start=(unsigned long)$arena+$block+24
  set $count=*(unsigned long*)($arena+$block+8)
  if $h2>=$start && $h2<$start+4*$count
   set $flag2=$start+4*$count+($h2-$start)/4
  end
 end
 set $block=$block+*(unsigned long*)($arena+$block)
end
if $flag2==0 || (*(unsigned char*)$flag2&1)==0
 echo FAIL dialog handle not allocated\n
 detach
 quit 1
end
set $h3=(unsigned long)s_windows[$slot].ownedDialogHandles[3]
set $block=64
set $flag3=0
while $block<s_applicationZone.end_
 if *(unsigned long*)($arena+$block+12)==3
  set $start=(unsigned long)$arena+$block+24
  set $count=*(unsigned long*)($arena+$block+8)
  if $h3>=$start && $h3<$start+4*$count
   set $flag3=$start+4*$count+($h3-$start)/4
  end
 end
 set $block=$block+*(unsigned long*)($arena+$block)
end
if $flag3==0 || (*(unsigned char*)$flag3&1)==0
 echo FAIL dialog handle not allocated\n
 detach
 quit 1
end
tbreak *($dan+0x3454)
continue
printf "SERVICE_RETURN label=DISPOSE seq=3 sp=%X port=%X windows=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$sp,*(unsigned long*)s_qdThePort,s_windowList,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
if $pc!=$dan+0x3454 || $sp!=$args+4
 echo FAIL service return\n
 detach
 quit 1
end
printf "DISPOSE_OWNER used=%u dialog=%u window=%X freeDelta=%u flags=%02X%02X%02X%02X owned=%X%X%X%X\n",s_windows[$slot].used,s_windows[$slot].dialog,s_windows[$slot].window,*(unsigned long*)($arena+12)-$freeBefore,*(unsigned char*)$flag0,*(unsigned char*)$flag1,*(unsigned char*)$flag2,*(unsigned char*)$flag3,s_windows[$slot].ownedDialogHandles[0],s_windows[$slot].ownedDialogHandles[1],s_windows[$slot].ownedDialogHandles[2],s_windows[$slot].ownedDialogHandles[3]
tbreak *($dan+0x313c)
continue
if $pc!=$dan+0x313c || *(unsigned short*)$pc!=0xab1d
 echo FAIL original service site\n
 detach
 quit 1
end
set $args=$sp
printf "SERVICE_ENTER label=WORLD seq=4 sp=%X port=%X windows=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$sp,*(unsigned long*)s_qdThePort,s_windowList,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
printf "SERVICE_ARGS seq=4 data=%08X%08X%08X%08X%08X%08X\n",*(unsigned long*)($args+0),*(unsigned long*)($args+4),*(unsigned long*)($args+8),*(unsigned long*)($args+12),*(unsigned long*)($args+16),*(unsigned long*)($args+20)
tbreak *($dan+0x313e)
continue
printf "SERVICE_RETURN label=WORLD seq=4 sp=%X port=%X windows=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$sp,*(unsigned long*)s_qdThePort,s_windowList,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
if $pc!=$dan+0x313e || $sp!=$args+8
 echo FAIL service return\n
 detach
 quit 1
end
tbreak *($core+0x514)
continue
printf "CHOICE_RESULT d0=%X pref=%X\n",$d0,*(unsigned char*)($pref+7)
tbreak *($core+0x53a)
continue
printf "CHOICE_PREF after=%08X%08X%04X\n",*(unsigned long*)$pref,*(unsigned long*)($pref+4),*(unsigned short*)($pref+8)
tbreak dispatchMacTrap if trap==0xaa46 && *(unsigned long*)(frame+2)==(unsigned long)s_segments[9].begin+0x109a
continue
set $misc=s_segments[9].begin
printf "WINDOW_SITE pc=%X base=%X offset=%X id=%X builtin=%u service=%u\n",*(unsigned long*)(frame+2),$misc,*(unsigned long*)(frame+2)-(unsigned long)$misc,*(unsigned short*)(userStack+8),builtin,inUserService
if *(unsigned long*)(frame+2)!=(unsigned long)$misc+0x109a
 echo FAIL original WIND request site\n
 detach
 quit 1
end
printf "CHOICE_WINDOW id=%X opcode=%X\n",*(unsigned short*)(userStack+8),*(unsigned short*)($misc+0x109a)
printf "WINDOW_REQUEST storage=%X behind=%X result=%X pref=%X a5=%X operand=%X\n",*(unsigned long*)(userStack+4),*(unsigned long*)userStack,*(unsigned long*)(userStack+10),*(unsigned char*)($pref+7),regs[13],*(unsigned long*)($misc+0x1072)
printf "WINDOW_BYTES data=%04X%04X%04X%04X%04X%04X%04X%04X%04X%04X%04X%04X%04X%04X%04X%04X%04X%04X%04X%04X%04X%04X\n",*(unsigned short*)($misc+0x1070),*(unsigned short*)($misc+0x1072),*(unsigned short*)($misc+0x1074),*(unsigned short*)($misc+0x1076),*(unsigned short*)($misc+0x1078),*(unsigned short*)($misc+0x107a),*(unsigned short*)($misc+0x107c),*(unsigned short*)($misc+0x107e),*(unsigned short*)($misc+0x1080),*(unsigned short*)($misc+0x1082),*(unsigned short*)($misc+0x1084),*(unsigned short*)($misc+0x1086),*(unsigned short*)($misc+0x1088),*(unsigned short*)($misc+0x108a),*(unsigned short*)($misc+0x108c),*(unsigned short*)($misc+0x108e),*(unsigned short*)($misc+0x1090),*(unsigned short*)($misc+0x1092),*(unsigned short*)($misc+0x1094),*(unsigned short*)($misc+0x1096),*(unsigned short*)($misc+0x1098),*(unsigned short*)($misc+0x109a)
continue
printf "CHOICE_NEXT state=%u trap=%X selector=%X segment=%u offset=%X manager=%s routine=%s windows=%u services=%u/%u reads=%u bytes=%u\n",g_stageBState,g_trapWord,g_trapSelector,g_trapSegment,g_trapOffset,g_trapManager,g_trapRoutine,g_systemWindows,g_macServiceEntered,g_macServiceCompleted,g_resourceRuntimeReads,g_resourceRuntimeBytes
if g_stageBState!=3 || g_trapWord!=0xa0f8 || g_trapSegment!=3 || g_trapOffset!=0x137e || *(unsigned long*)(g_trapRoutine+0)!=0x53454c45 || *(unsigned long*)(g_trapRoutine+4)!=0x43544f52 || g_trapRoutine[8]!=0 || g_trapSelector!=13 || g_macServiceActive!=1 || g_systemWindows!=$startup_windows || g_macServiceEntered!=$startup_entered+g_effectStatusCalls || g_macServiceCompleted!=$startup_completed+g_effectStatusCalls || g_resourceRuntimeReads!=70 || g_resourceRuntimeBytes!=349400
 echo FAIL fixed-choice progression\n
 detach
 quit 1
end
echo PASS native fixed-choice services next=COPYBITS\n
detach
quit 0
