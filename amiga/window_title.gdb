set pagination off
set confirm off
set width 0
break AitdScreen::showLoudStop
tbreak dispatchMacTrap if trap==0xa91a
continue
set $misc=s_segments[9].begin
set $args=(unsigned long)userStack
if *(unsigned long*)(frame+2)!=(unsigned long)$misc+0x1296
 echo FAIL title entry\n
 detach
 quit 1
end
echo ARM native title original bytes\n
set $window=*(unsigned long*)($args+4)
set $string=*(unsigned long*)$args
printf "TITLE_ENTER sp=%X string=%X window=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$args,$string,$window,regs[0],regs[1],regs[2],regs[3],regs[4],regs[5],regs[6],regs[7],regs[8],regs[9],regs[10],regs[11],regs[12],regs[13],regs[14]
printf "TITLE_BYTES data=%04X%04X%04X%04X%04X%04X\n",*(unsigned short*)($misc+0x128c),*(unsigned short*)($misc+0x128e),*(unsigned short*)($misc+0x1290),*(unsigned short*)($misc+0x1292),*(unsigned short*)($misc+0x1294),*(unsigned short*)($misc+0x1296)
dump binary memory ../tmp/title-native-input.bin (char*)$string (char*)$string+*(unsigned char*)$string+1
set $handle=*(unsigned long*)($window+134)
set $body=*(unsigned long*)$handle
printf "TITLE_STATE phase=before window=%X titleHandle=%X titleBody=%X length=%X visible=%X width=%X\n",$window,$handle,$body,*(unsigned char*)$body,*(unsigned char*)($window+110),*(unsigned short*)($window+138)
printf "TITLE_PORT phase=before current=%X wmgr=%X\n",*(unsigned long*)s_qdThePort,s_windowManagerPort
dump binary memory ../tmp/title-native-before-window.bin (char*)$window (char*)$window+156
dump binary memory ../tmp/title-native-before-title.bin (char*)$body (char*)$body+*(unsigned char*)$body+1
dump binary memory ../tmp/title-native-before-wmgr.bin (char*)s_windowManagerPort (char*)s_windowManagerPort+108
dump binary memory ../tmp/title-native-before-screen.bin (char*)s_colorScreen (char*)s_colorScreen+307200
set $region=**(unsigned long**)($window+24)
dump binary memory ../tmp/title-native-before-vis.bin (char*)$region (char*)$region+10
set $region=**(unsigned long**)($window+28)
dump binary memory ../tmp/title-native-before-clip.bin (char*)$region (char*)$region+10
set $region=**(unsigned long**)($window+114)
dump binary memory ../tmp/title-native-before-structure.bin (char*)$region (char*)$region+10
set $region=**(unsigned long**)($window+118)
dump binary memory ../tmp/title-native-before-content.bin (char*)$region (char*)$region+10
set $region=**(unsigned long**)($window+122)
dump binary memory ../tmp/title-native-before-update.bin (char*)$region (char*)$region+10
printf "TITLE_NATIVE_SIZE phase=before size=%X\n",*(unsigned long*)($body-20)
tbreak *($misc+0x1298)
continue
if $pc!=$misc+0x1298
 echo FAIL title return\n
 detach
 quit 1
end
printf "TITLE_RETURN sp=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$sp,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
set $handle=*(unsigned long*)($window+134)
set $body=*(unsigned long*)$handle
printf "TITLE_STATE phase=after window=%X titleHandle=%X titleBody=%X length=%X visible=%X width=%X\n",$window,$handle,$body,*(unsigned char*)$body,*(unsigned char*)($window+110),*(unsigned short*)($window+138)
printf "TITLE_PORT phase=after current=%X wmgr=%X\n",*(unsigned long*)s_qdThePort,s_windowManagerPort
dump binary memory ../tmp/title-native-after-window.bin (char*)$window (char*)$window+156
dump binary memory ../tmp/title-native-after-title.bin (char*)$body (char*)$body+*(unsigned char*)$body+1
dump binary memory ../tmp/title-native-after-wmgr.bin (char*)s_windowManagerPort (char*)s_windowManagerPort+108
dump binary memory ../tmp/title-native-after-screen.bin (char*)s_colorScreen (char*)s_colorScreen+307200
set $region=**(unsigned long**)($window+24)
dump binary memory ../tmp/title-native-after-vis.bin (char*)$region (char*)$region+10
set $region=**(unsigned long**)($window+28)
dump binary memory ../tmp/title-native-after-clip.bin (char*)$region (char*)$region+10
set $region=**(unsigned long**)($window+114)
dump binary memory ../tmp/title-native-after-structure.bin (char*)$region (char*)$region+10
set $region=**(unsigned long**)($window+118)
dump binary memory ../tmp/title-native-after-content.bin (char*)$region (char*)$region+10
set $region=**(unsigned long**)($window+122)
dump binary memory ../tmp/title-native-after-update.bin (char*)$region (char*)$region+10
printf "TITLE_NATIVE_SIZE phase=after size=%X\n",*(unsigned long*)($body-20)
dump binary memory ../tmp/title-native-input-after.bin (char*)$string (char*)$string+*(unsigned char*)$string+1
echo PASS native title capture\n
continue
printf "TITLE_NEXT state=%u trap=%X selector=%X segment=%u offset=%X manager=%s routine=%s windows=%u services=%u/%u\n",g_stageBState,g_trapWord,g_trapSelector,g_trapSegment,g_trapOffset,g_trapManager,g_trapRoutine,g_systemWindows,g_macServiceEntered,g_macServiceCompleted
if g_stageBState!=3 || g_trapWord!=0xab1d || g_trapSegment!=10 || g_trapOffset!=0x8e || *(unsigned long*)(g_trapRoutine+0)!=0x53455447 || *(unsigned long*)(g_trapRoutine+4)!=0x574f524c || g_trapRoutine[8]!=0x44 || g_trapRoutine[9]!=0 || g_macServiceActive!=0
 echo FAIL title next stop\n
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
printf "TITLE_COUNTS app=%u/%u overlay=%u/%u prep=%u/%u resources=%u\n",g_resourceRuntimeReads,g_resourceRuntimeBytes,g_overlayRuntimeReads,g_overlayRuntimeBytes,g_overlaySourceReads,g_overlaySourceBytes,g_resourceCount
echo PASS native title next=SETGWORLD original-MDRV=absent\n
detach
quit 0
