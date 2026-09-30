set pagination off
set confirm off
set width 0
break AitdScreen::showLoudStop
tbreak dispatchMacTrap if trap==0xaa94 && *(unsigned long*)(frame+2)==(unsigned long)s_segments[9].begin+0x1100
continue
set $misc=s_segments[9].begin
set $args=(unsigned long)userStack
set $palette=(unsigned long)g_defaultPalette
set $body=*(unsigned long*)$palette
set $private=*(unsigned long*)($body+12)
set $privatebody=*(unsigned long*)$private
set $window=*(unsigned long*)$args
set $slot=0
while $slot<8 && s_windows[$slot].window!=(unsigned char*)$window
 set $slot=$slot+1
end
if $slot==8
 echo FAIL window not found\n
 detach
 quit 1
end
printf "ACT_ENTER sp=%X args=%08X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$args,*(unsigned long*)$args,regs[0],regs[1],regs[2],regs[3],regs[4],regs[5],regs[6],regs[7],regs[8],regs[9],regs[10],regs[11],regs[12],regs[13],regs[14]
printf "ACT_BYTES data=%04X%04X%04X\n",*(unsigned short*)($misc+0x10fc),*(unsigned short*)($misc+0x10fe),*(unsigned short*)($misc+0x1100)
printf "ACT_NATIVE_STATE phase=before palette=%X body=%X private=%X privateBody=%X binding=%X updates=%u default=%X active=%X seed=%X queued=%u dirty=%u count=%u\n",$palette,$body,$private,$privatebody,s_windows[$slot].palette,s_windows[$slot].paletteUpdates,g_defaultPalette,s_activePalette,s_colorSeed,g_macFramesQueued,s_pixelsDirty,s_dirtyRectCount
dump binary memory ../tmp/activation-native-activate-before-palette.bin (char*)$body (char*)$body+4112
dump binary memory ../tmp/activation-native-activate-before-private.bin (char*)$privatebody (char*)$privatebody+4
dump binary memory ../tmp/activation-native-activate-before-window.bin (char*)$window (char*)$window+156
dump binary memory ../tmp/activation-native-activate-before-gd.bin (char*)s_mainDevice (char*)s_mainDevice+62
dump binary memory ../tmp/activation-native-activate-before-pm.bin (char*)s_windowManagerPixMap (char*)s_windowManagerPixMap+50
dump binary memory ../tmp/activation-native-activate-before-clut.bin (char*)s_windowManagerColors (char*)s_windowManagerColors+2056
dump binary memory ../tmp/activation-native-activate-before-physical.bin (char*)s_colorScreen (char*)s_colorScreen+307200
dump binary memory ../tmp/activation-native-activate-before-copper.bin (char*)s_loudStopScreen->m_copperAllocation (char*)s_loudStopScreen->m_copperAllocation+4496
dump binary memory ../tmp/activation-native-activate-before-pending.bin (char*)s_loudStopScreen->m_nextPalette (char*)s_loudStopScreen->m_nextPalette+1024
tbreak *($misc+0x1102)
continue
if $pc!=$misc+0x1102
 echo FAIL window activation return\n
 detach
 quit 1
end
printf "ACT_RETURN sp=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$sp,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
printf "ACT_NATIVE_STATE phase=after palette=%X body=%X private=%X privateBody=%X binding=%X updates=%u default=%X active=%X seed=%X queued=%u dirty=%u count=%u\n",$palette,$body,$private,$privatebody,s_windows[$slot].palette,s_windows[$slot].paletteUpdates,g_defaultPalette,s_activePalette,s_colorSeed,g_macFramesQueued,s_pixelsDirty,s_dirtyRectCount
dump binary memory ../tmp/activation-native-activate-after-palette.bin (char*)$body (char*)$body+4112
dump binary memory ../tmp/activation-native-activate-after-private.bin (char*)$privatebody (char*)$privatebody+4
dump binary memory ../tmp/activation-native-activate-after-window.bin (char*)$window (char*)$window+156
dump binary memory ../tmp/activation-native-activate-after-gd.bin (char*)s_mainDevice (char*)s_mainDevice+62
dump binary memory ../tmp/activation-native-activate-after-pm.bin (char*)s_windowManagerPixMap (char*)s_windowManagerPixMap+50
dump binary memory ../tmp/activation-native-activate-after-clut.bin (char*)s_windowManagerColors (char*)s_windowManagerColors+2056
dump binary memory ../tmp/activation-native-activate-after-physical.bin (char*)s_colorScreen (char*)s_colorScreen+307200
dump binary memory ../tmp/activation-native-activate-after-copper.bin (char*)s_loudStopScreen->m_copperAllocation (char*)s_loudStopScreen->m_copperAllocation+4496
dump binary memory ../tmp/activation-native-activate-after-pending.bin (char*)s_loudStopScreen->m_nextPalette (char*)s_loudStopScreen->m_nextPalette+1024
echo PASS native window activation capture\n
continue
printf "ACT_NEXT state=%u trap=%X segment=%u offset=%X manager=%s routine=%s windows=%u services=%u/%u\n",g_stageBState,g_trapWord,g_trapSegment,g_trapOffset,g_trapManager,g_trapRoutine,g_systemWindows,g_macServiceEntered,g_macServiceCompleted
if g_stageBState!=3 || g_trapWord!=0xaa95 || g_trapSegment!=5 || g_trapOffset!=0x20cc || g_macServiceActive!=0
 echo FAIL next window activation boundary\n
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
echo PASS native window activation next-stop original-MDRV=absent\n
detach
quit 0
