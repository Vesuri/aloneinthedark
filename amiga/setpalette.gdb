set pagination off
set confirm off
set width 0
break AitdScreen::showLoudStop
tbreak dispatchMacTrap if trap==0xaa95
continue
set $engine=s_segments[7].begin
set $args=(unsigned long)userStack
if *(unsigned long*)(frame+2)!=(unsigned long)$engine+0x1172
 echo FAIL SetPalette entry\n
 detach
 quit 1
end
echo ARM native SetPalette original bytes\n
set $palette=*(unsigned long*)($args+2)
set $body=*(unsigned long*)$palette
set $private=*(unsigned long*)($body+12)
set $privatebody=*(unsigned long*)$private
printf "SET_ENTER sp=%X args=%04X/%08X/%08X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$args,*(unsigned short*)$args,*(unsigned long*)($args+2),*(unsigned long*)($args+6),regs[0],regs[1],regs[2],regs[3],regs[4],regs[5],regs[6],regs[7],regs[8],regs[9],regs[10],regs[11],regs[12],regs[13],regs[14]
printf "SET_BYTES data=%04X%04X%04X%04X%04X%04X%04X\n",*(unsigned short*)($engine+0x1166),*(unsigned short*)($engine+0x1168),*(unsigned short*)($engine+0x116a),*(unsigned short*)($engine+0x116c),*(unsigned short*)($engine+0x116e),*(unsigned short*)($engine+0x1170),*(unsigned short*)($engine+0x1172)
printf "SET_NATIVE_STATE phase=before palette=%X body=%X private=%X privateBody=%X binding=%X\n",$palette,*(unsigned long*)$palette,$private,*(unsigned long*)$private,g_defaultPalette
dump binary memory ../tmp/setpalette-native-before-palette.bin (char*)$body (char*)$body+4112
dump binary memory ../tmp/setpalette-native-before-private.bin (char*)$privatebody (char*)$privatebody+4
dump binary memory ../tmp/setpalette-native-before-gd.bin (char*)s_mainDevice (char*)s_mainDevice+62
dump binary memory ../tmp/setpalette-native-before-pm.bin (char*)s_windowManagerPixMap (char*)s_windowManagerPixMap+50
dump binary memory ../tmp/setpalette-native-before-clut.bin (char*)s_windowManagerColors (char*)s_windowManagerColors+2056
dump binary memory ../tmp/setpalette-native-before-physical.bin (char*)s_colorScreen (char*)s_colorScreen+307200
dump binary memory ../tmp/setpalette-native-before-copper.bin (char*)s_loudStopScreen->m_copper (char*)s_loudStopScreen->m_copper+2248
dump binary memory ../tmp/setpalette-native-before-pending.bin (char*)s_loudStopScreen->m_nextPalette (char*)s_loudStopScreen->m_nextPalette+1024
tbreak *($engine+0x1174)
continue
if $pc!=$engine+0x1174
 echo FAIL SetPalette return\n
 detach
 quit 1
end
printf "SET_RETURN sp=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$sp,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
printf "SET_NATIVE_STATE phase=after palette=%X body=%X private=%X privateBody=%X binding=%X\n",$palette,*(unsigned long*)$palette,$private,*(unsigned long*)$private,g_defaultPalette
dump binary memory ../tmp/setpalette-native-after-palette.bin (char*)$body (char*)$body+4112
dump binary memory ../tmp/setpalette-native-after-private.bin (char*)$privatebody (char*)$privatebody+4
dump binary memory ../tmp/setpalette-native-after-gd.bin (char*)s_mainDevice (char*)s_mainDevice+62
dump binary memory ../tmp/setpalette-native-after-pm.bin (char*)s_windowManagerPixMap (char*)s_windowManagerPixMap+50
dump binary memory ../tmp/setpalette-native-after-clut.bin (char*)s_windowManagerColors (char*)s_windowManagerColors+2056
dump binary memory ../tmp/setpalette-native-after-physical.bin (char*)s_colorScreen (char*)s_colorScreen+307200
dump binary memory ../tmp/setpalette-native-after-copper.bin (char*)s_loudStopScreen->m_copper (char*)s_loudStopScreen->m_copper+2248
dump binary memory ../tmp/setpalette-native-after-pending.bin (char*)s_loudStopScreen->m_nextPalette (char*)s_loudStopScreen->m_nextPalette+1024
printf "SET_NATIVE_SIZE palette=%X private=%X\n",*(unsigned long*)($body-20),*(unsigned long*)($privatebody-20)
printf "SET_COUNTS app=%u/%u overlay=%u/%u prep=%u/%u resources=%u\n",g_resourceRuntimeReads,g_resourceRuntimeBytes,g_overlayRuntimeReads,g_overlayRuntimeBytes,g_overlaySourceReads,g_overlaySourceBytes,g_resourceCount
echo PASS native SetPalette capture\n
continue
printf "SET_NEXT state=%u trap=%X selector=%X segment=%u offset=%X manager=%s routine=%s windows=%u services=%u/%u\n",g_stageBState,g_trapWord,g_trapSelector,g_trapSegment,g_trapOffset,g_trapManager,g_trapRoutine,g_systemWindows,g_macServiceEntered,g_macServiceCompleted
if g_stageBState!=3 || g_trapWord!=0xa934 || g_trapSegment!=7 || g_trapOffset!=0x2b06 || *(unsigned long*)(g_trapRoutine+0)!=0x434c4541 || *(unsigned long*)(g_trapRoutine+4)!=0x524d454e || *(unsigned long*)(g_trapRoutine+8)!=0x55424152 || g_trapRoutine[12]!=0 || g_macServiceActive!=0
 echo FAIL SetPalette next stop\n
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
printf "SET_FINAL_COUNTS app=%u/%u overlay=%u/%u prep=%u/%u resources=%u\n",g_resourceRuntimeReads,g_resourceRuntimeBytes,g_overlayRuntimeReads,g_overlayRuntimeBytes,g_overlaySourceReads,g_overlaySourceBytes,g_resourceCount
echo PASS native SetPalette original-MDRV=absent\n
detach
quit 0
