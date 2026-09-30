set pagination off
set confirm off
set width 0
break AitdScreen::showLoudStop
tbreak dispatchMacTrap if trap==0xab1d && *(unsigned long*)(frame+2)==(unsigned long)s_segments[7].begin+0x1286
continue
set $engine=s_segments[7].begin
set $args=(unsigned long)userStack
set $window=*(unsigned long*)($args+4)
set $pm=*(unsigned long*)*(unsigned long*)($window+2)
printf "WB_ENTER sp=%X device=%X window=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$args,*(unsigned long*)$args,$window,regs[0],regs[1],regs[2],regs[3],regs[4],regs[5],regs[6],regs[7],regs[8],regs[9],regs[10],regs[11],regs[12],regs[13],regs[14]
printf "WB_BYTES data=%04X%04X%04X%04X%04X%04X%04X%04X%04X\n",*(unsigned short*)($engine+0x1276),*(unsigned short*)($engine+0x1278),*(unsigned short*)($engine+0x127a),*(unsigned short*)($engine+0x127c),*(unsigned short*)($engine+0x127e),*(unsigned short*)($engine+0x1280),*(unsigned short*)($engine+0x1282),*(unsigned short*)($engine+0x1284),*(unsigned short*)($engine+0x1286)
printf "WB_STATE phase=before port=%X main=%X device=%X\n",*(unsigned long*)s_qdThePort,&s_mainDeviceMaster,&s_mainDeviceMaster
printf "WB_NATIVE phase=before queued=%u dirty=%u seed=%u\n",g_macFramesQueued,s_pixelsDirty,s_colorSeed
dump binary memory ../tmp/worldbind-native-before-window.bin (char*)$window (char*)$window+156
dump binary memory ../tmp/worldbind-native-before-pm.bin (char*)$pm (char*)$pm+50
dump binary memory ../tmp/worldbind-native-before-device.bin (char*)s_mainDevice (char*)s_mainDevice+62
dump binary memory ../tmp/worldbind-native-before-pixels.bin (char*)s_colorScreen (char*)s_colorScreen+307200
dump binary memory ../tmp/worldbind-native-before-clut.bin (char*)s_windowManagerColors (char*)s_windowManagerColors+2056
tbreak *($engine+0x1288)
continue
if $pc!=$engine+0x1288
 echo FAIL SetGWorld return\n
 detach
 quit 1
end
printf "WB_RETURN sp=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$sp,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
printf "WB_STATE phase=after port=%X main=%X device=%X\n",*(unsigned long*)s_qdThePort,&s_mainDeviceMaster,&s_mainDeviceMaster
printf "WB_NATIVE phase=after queued=%u dirty=%u seed=%u\n",g_macFramesQueued,s_pixelsDirty,s_colorSeed
dump binary memory ../tmp/worldbind-native-after-window.bin (char*)$window (char*)$window+156
dump binary memory ../tmp/worldbind-native-after-pm.bin (char*)$pm (char*)$pm+50
dump binary memory ../tmp/worldbind-native-after-device.bin (char*)s_mainDevice (char*)s_mainDevice+62
dump binary memory ../tmp/worldbind-native-after-pixels.bin (char*)s_colorScreen (char*)s_colorScreen+307200
dump binary memory ../tmp/worldbind-native-after-clut.bin (char*)s_windowManagerColors (char*)s_windowManagerColors+2056
echo PASS native world binding\n
continue
printf "WB_NEXT state=%u trap=%X selector=%X segment=%u offset=%X manager=%s routine=%s windows=%u services=%u/%u\n",g_stageBState,g_trapWord,g_trapSelector,g_trapSegment,g_trapOffset,g_trapManager,g_trapRoutine,g_systemWindows,g_macServiceEntered,g_macServiceCompleted
if g_stageBState!=3 || g_macServiceActive!=0 || g_trapWord!=0xa8df || g_trapSelector!=0xffffffff || g_trapSegment!=4 || g_trapOffset!=0x3d46
 echo FAIL SetGWorld progression\n
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
printf "WB_COUNTS app=%u/%u overlay=%u/%u prep=%u/%u resources=%u\n",g_resourceRuntimeReads,g_resourceRuntimeBytes,g_overlayRuntimeReads,g_overlayRuntimeBytes,g_overlaySourceReads,g_overlaySourceBytes,g_resourceCount
echo PASS native world binding next-stop original-MDRV=absent\n
detach
quit 0
