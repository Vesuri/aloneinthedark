set pagination off
set confirm off
set width 0
break AitdScreen::showLoudStop
tbreak dispatchMacTrap if trap==0xa91d && *(unsigned long*)(frame+2)==(unsigned long)s_segments[9].begin+0xf8c
continue
set $misc=s_segments[9].begin
set $args=(unsigned long)userStack
set $palette=(unsigned long)g_defaultPalette
set $body=*(unsigned long*)$palette
set $private=*(unsigned long*)($body+12)
set $privatebody=*(unsigned long*)$private
set $window=*(unsigned long*)($args+6)
set $slot=0
while $slot<8 && s_windows[$slot].window!=(unsigned char*)$window
 set $slot=$slot+1
end
if $slot==8
 echo FAIL window not found\n
 detach
 quit 1
end
printf "RESIZE_ENTER label=size sp=%X args=%04X%04X%04X%08X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$args,*(unsigned short*)$args,*(unsigned short*)($args+2),*(unsigned short*)($args+4),*(unsigned long*)($args+6),regs[0],regs[1],regs[2],regs[3],regs[4],regs[5],regs[6],regs[7],regs[8],regs[9],regs[10],regs[11],regs[12],regs[13],regs[14]
printf "RESIZE_BYTES label=size data=%04X%04X%04X%04X%04X%04X%04X%04X%04X%04X%04X\n",*(unsigned short*)($misc+0xf78),*(unsigned short*)($misc+0xf7a),*(unsigned short*)($misc+0xf7c),*(unsigned short*)($misc+0xf7e),*(unsigned short*)($misc+0xf80),*(unsigned short*)($misc+0xf82),*(unsigned short*)($misc+0xf84),*(unsigned short*)($misc+0xf86),*(unsigned short*)($misc+0xf88),*(unsigned short*)($misc+0xf8a),*(unsigned short*)($misc+0xf8c)
printf "RESIZE_NATIVE_STATE phase=before palette=%X body=%X private=%X privateBody=%X binding=%X updates=%u default=%X active=%X seed=%X queued=%u dirty=%u count=%u\n",$palette,$body,$private,$privatebody,s_windows[$slot].palette,s_windows[$slot].paletteUpdates,g_defaultPalette,s_activePalette,s_colorSeed,g_macFramesQueued,s_pixelsDirty,s_dirtyRectCount
dump binary memory ../tmp/resize-native-size-before-palette.bin (char*)$body (char*)$body+4112
dump binary memory ../tmp/resize-native-size-before-private.bin (char*)$privatebody (char*)$privatebody+4
dump binary memory ../tmp/resize-native-size-before-window.bin (char*)$window (char*)$window+156
dump binary memory ../tmp/resize-native-size-before-gd.bin (char*)s_mainDevice (char*)s_mainDevice+62
dump binary memory ../tmp/resize-native-size-before-pm.bin (char*)s_windowManagerPixMap (char*)s_windowManagerPixMap+50
dump binary memory ../tmp/resize-native-size-before-clut.bin (char*)s_windowManagerColors (char*)s_windowManagerColors+2056
dump binary memory ../tmp/resize-native-size-before-physical.bin (char*)s_colorScreen (char*)s_colorScreen+307200
dump binary memory ../tmp/resize-native-size-before-copper.bin (char*)s_loudStopScreen->m_copperAllocation (char*)s_loudStopScreen->m_copperAllocation+4496
dump binary memory ../tmp/resize-native-size-before-pending.bin (char*)s_loudStopScreen->m_nextPalette (char*)s_loudStopScreen->m_nextPalette+1024
printf "RESIZE_WINDOW id=%d kind=%d visible=%u front=%X rect=%d/%d/%d/%d\n",s_windows[$slot].resourceID,*(short*)($window+108),*(unsigned char*)($window+110),s_windowList,*(short*)($window+16),*(short*)($window+18),*(short*)($window+20),*(short*)($window+22)
set $windowpm=*(unsigned long*)*(unsigned long*)($window+2)
dump binary memory ../tmp/resize-native-size-before-windowpm.bin (char*)$windowpm (char*)$windowpm+50
dump binary memory ../tmp/resize-native-size-before-gray.bin (char*)s_grayRgn (char*)s_grayRgn+*(unsigned short*)s_grayRgn
dump binary memory ../tmp/resize-native-size-before-front.bin (char*)s_windowList (char*)s_windowList+156
set $region=*(unsigned long*)*(unsigned long*)($window+24)
dump binary memory ../tmp/resize-native-size-before-visibility.bin (char*)$region (char*)$region+*(unsigned short*)$region
set $region=*(unsigned long*)*(unsigned long*)($window+28)
dump binary memory ../tmp/resize-native-size-before-clip.bin (char*)$region (char*)$region+*(unsigned short*)$region
set $region=*(unsigned long*)*(unsigned long*)($window+114)
dump binary memory ../tmp/resize-native-size-before-structure.bin (char*)$region (char*)$region+*(unsigned short*)$region
set $region=*(unsigned long*)*(unsigned long*)($window+118)
dump binary memory ../tmp/resize-native-size-before-content.bin (char*)$region (char*)$region+*(unsigned short*)$region
set $region=*(unsigned long*)*(unsigned long*)($window+122)
dump binary memory ../tmp/resize-native-size-before-update.bin (char*)$region (char*)$region+*(unsigned short*)$region
tbreak *($misc+0xf8e)
continue
if $pc!=$misc+0xf8e
 echo FAIL window reassert return\n
 detach
 quit 1
end
printf "RESIZE_RETURN label=size sp=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$sp,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
printf "RESIZE_NATIVE_STATE phase=after palette=%X body=%X private=%X privateBody=%X binding=%X updates=%u default=%X active=%X seed=%X queued=%u dirty=%u count=%u\n",$palette,$body,$private,$privatebody,s_windows[$slot].palette,s_windows[$slot].paletteUpdates,g_defaultPalette,s_activePalette,s_colorSeed,g_macFramesQueued,s_pixelsDirty,s_dirtyRectCount
dump binary memory ../tmp/resize-native-size-after-palette.bin (char*)$body (char*)$body+4112
dump binary memory ../tmp/resize-native-size-after-private.bin (char*)$privatebody (char*)$privatebody+4
dump binary memory ../tmp/resize-native-size-after-window.bin (char*)$window (char*)$window+156
dump binary memory ../tmp/resize-native-size-after-gd.bin (char*)s_mainDevice (char*)s_mainDevice+62
dump binary memory ../tmp/resize-native-size-after-pm.bin (char*)s_windowManagerPixMap (char*)s_windowManagerPixMap+50
dump binary memory ../tmp/resize-native-size-after-clut.bin (char*)s_windowManagerColors (char*)s_windowManagerColors+2056
dump binary memory ../tmp/resize-native-size-after-physical.bin (char*)s_colorScreen (char*)s_colorScreen+307200
dump binary memory ../tmp/resize-native-size-after-copper.bin (char*)s_loudStopScreen->m_copperAllocation (char*)s_loudStopScreen->m_copperAllocation+4496
dump binary memory ../tmp/resize-native-size-after-pending.bin (char*)s_loudStopScreen->m_nextPalette (char*)s_loudStopScreen->m_nextPalette+1024
printf "RESIZE_WINDOW id=%d kind=%d visible=%u front=%X rect=%d/%d/%d/%d\n",s_windows[$slot].resourceID,*(short*)($window+108),*(unsigned char*)($window+110),s_windowList,*(short*)($window+16),*(short*)($window+18),*(short*)($window+20),*(short*)($window+22)
set $windowpm=*(unsigned long*)*(unsigned long*)($window+2)
dump binary memory ../tmp/resize-native-size-after-windowpm.bin (char*)$windowpm (char*)$windowpm+50
dump binary memory ../tmp/resize-native-size-after-gray.bin (char*)s_grayRgn (char*)s_grayRgn+*(unsigned short*)s_grayRgn
dump binary memory ../tmp/resize-native-size-after-front.bin (char*)s_windowList (char*)s_windowList+156
set $region=*(unsigned long*)*(unsigned long*)($window+24)
dump binary memory ../tmp/resize-native-size-after-visibility.bin (char*)$region (char*)$region+*(unsigned short*)$region
set $region=*(unsigned long*)*(unsigned long*)($window+28)
dump binary memory ../tmp/resize-native-size-after-clip.bin (char*)$region (char*)$region+*(unsigned short*)$region
set $region=*(unsigned long*)*(unsigned long*)($window+114)
dump binary memory ../tmp/resize-native-size-after-structure.bin (char*)$region (char*)$region+*(unsigned short*)$region
set $region=*(unsigned long*)*(unsigned long*)($window+118)
dump binary memory ../tmp/resize-native-size-after-content.bin (char*)$region (char*)$region+*(unsigned short*)$region
set $region=*(unsigned long*)*(unsigned long*)($window+122)
dump binary memory ../tmp/resize-native-size-after-update.bin (char*)$region (char*)$region+*(unsigned short*)$region
tbreak dispatchMacTrap if trap==0xa91b && *(unsigned long*)(frame+2)==(unsigned long)s_segments[7].begin+0x48a2
continue
set $misc=s_segments[7].begin
set $args=(unsigned long)userStack
set $palette=(unsigned long)g_defaultPalette
set $body=*(unsigned long*)$palette
set $private=*(unsigned long*)($body+12)
set $privatebody=*(unsigned long*)$private
set $window=*(unsigned long*)($args+6)
set $slot=0
while $slot<8 && s_windows[$slot].window!=(unsigned char*)$window
 set $slot=$slot+1
end
if $slot==8
 echo FAIL window not found\n
 detach
 quit 1
end
printf "RESIZE_ENTER label=move sp=%X args=%04X%04X%04X%08X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$args,*(unsigned short*)$args,*(unsigned short*)($args+2),*(unsigned short*)($args+4),*(unsigned long*)($args+6),regs[0],regs[1],regs[2],regs[3],regs[4],regs[5],regs[6],regs[7],regs[8],regs[9],regs[10],regs[11],regs[12],regs[13],regs[14]
printf "RESIZE_BYTES label=move data=%04X%04X%04X%04X%04X%04X%04X%04X%04X%04X\n",*(unsigned short*)($misc+0x4890),*(unsigned short*)($misc+0x4892),*(unsigned short*)($misc+0x4894),*(unsigned short*)($misc+0x4896),*(unsigned short*)($misc+0x4898),*(unsigned short*)($misc+0x489a),*(unsigned short*)($misc+0x489c),*(unsigned short*)($misc+0x489e),*(unsigned short*)($misc+0x48a0),*(unsigned short*)($misc+0x48a2)
printf "RESIZE_NATIVE_STATE phase=before palette=%X body=%X private=%X privateBody=%X binding=%X updates=%u default=%X active=%X seed=%X queued=%u dirty=%u count=%u\n",$palette,$body,$private,$privatebody,s_windows[$slot].palette,s_windows[$slot].paletteUpdates,g_defaultPalette,s_activePalette,s_colorSeed,g_macFramesQueued,s_pixelsDirty,s_dirtyRectCount
dump binary memory ../tmp/resize-native-move-before-palette.bin (char*)$body (char*)$body+4112
dump binary memory ../tmp/resize-native-move-before-private.bin (char*)$privatebody (char*)$privatebody+4
dump binary memory ../tmp/resize-native-move-before-window.bin (char*)$window (char*)$window+156
dump binary memory ../tmp/resize-native-move-before-gd.bin (char*)s_mainDevice (char*)s_mainDevice+62
dump binary memory ../tmp/resize-native-move-before-pm.bin (char*)s_windowManagerPixMap (char*)s_windowManagerPixMap+50
dump binary memory ../tmp/resize-native-move-before-clut.bin (char*)s_windowManagerColors (char*)s_windowManagerColors+2056
dump binary memory ../tmp/resize-native-move-before-physical.bin (char*)s_colorScreen (char*)s_colorScreen+307200
dump binary memory ../tmp/resize-native-move-before-copper.bin (char*)s_loudStopScreen->m_copperAllocation (char*)s_loudStopScreen->m_copperAllocation+4496
dump binary memory ../tmp/resize-native-move-before-pending.bin (char*)s_loudStopScreen->m_nextPalette (char*)s_loudStopScreen->m_nextPalette+1024
printf "RESIZE_WINDOW id=%d kind=%d visible=%u front=%X rect=%d/%d/%d/%d\n",s_windows[$slot].resourceID,*(short*)($window+108),*(unsigned char*)($window+110),s_windowList,*(short*)($window+16),*(short*)($window+18),*(short*)($window+20),*(short*)($window+22)
set $windowpm=*(unsigned long*)*(unsigned long*)($window+2)
dump binary memory ../tmp/resize-native-move-before-windowpm.bin (char*)$windowpm (char*)$windowpm+50
dump binary memory ../tmp/resize-native-move-before-gray.bin (char*)s_grayRgn (char*)s_grayRgn+*(unsigned short*)s_grayRgn
dump binary memory ../tmp/resize-native-move-before-front.bin (char*)s_windowList (char*)s_windowList+156
set $region=*(unsigned long*)*(unsigned long*)($window+24)
dump binary memory ../tmp/resize-native-move-before-visibility.bin (char*)$region (char*)$region+*(unsigned short*)$region
set $region=*(unsigned long*)*(unsigned long*)($window+28)
dump binary memory ../tmp/resize-native-move-before-clip.bin (char*)$region (char*)$region+*(unsigned short*)$region
set $region=*(unsigned long*)*(unsigned long*)($window+114)
dump binary memory ../tmp/resize-native-move-before-structure.bin (char*)$region (char*)$region+*(unsigned short*)$region
set $region=*(unsigned long*)*(unsigned long*)($window+118)
dump binary memory ../tmp/resize-native-move-before-content.bin (char*)$region (char*)$region+*(unsigned short*)$region
set $region=*(unsigned long*)*(unsigned long*)($window+122)
dump binary memory ../tmp/resize-native-move-before-update.bin (char*)$region (char*)$region+*(unsigned short*)$region
tbreak *($misc+0x48a4)
continue
if $pc!=$misc+0x48a4
 echo FAIL window reassert return\n
 detach
 quit 1
end
printf "RESIZE_RETURN label=move sp=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$sp,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
printf "RESIZE_NATIVE_STATE phase=after palette=%X body=%X private=%X privateBody=%X binding=%X updates=%u default=%X active=%X seed=%X queued=%u dirty=%u count=%u\n",$palette,$body,$private,$privatebody,s_windows[$slot].palette,s_windows[$slot].paletteUpdates,g_defaultPalette,s_activePalette,s_colorSeed,g_macFramesQueued,s_pixelsDirty,s_dirtyRectCount
dump binary memory ../tmp/resize-native-move-after-palette.bin (char*)$body (char*)$body+4112
dump binary memory ../tmp/resize-native-move-after-private.bin (char*)$privatebody (char*)$privatebody+4
dump binary memory ../tmp/resize-native-move-after-window.bin (char*)$window (char*)$window+156
dump binary memory ../tmp/resize-native-move-after-gd.bin (char*)s_mainDevice (char*)s_mainDevice+62
dump binary memory ../tmp/resize-native-move-after-pm.bin (char*)s_windowManagerPixMap (char*)s_windowManagerPixMap+50
dump binary memory ../tmp/resize-native-move-after-clut.bin (char*)s_windowManagerColors (char*)s_windowManagerColors+2056
dump binary memory ../tmp/resize-native-move-after-physical.bin (char*)s_colorScreen (char*)s_colorScreen+307200
dump binary memory ../tmp/resize-native-move-after-copper.bin (char*)s_loudStopScreen->m_copperAllocation (char*)s_loudStopScreen->m_copperAllocation+4496
dump binary memory ../tmp/resize-native-move-after-pending.bin (char*)s_loudStopScreen->m_nextPalette (char*)s_loudStopScreen->m_nextPalette+1024
printf "RESIZE_WINDOW id=%d kind=%d visible=%u front=%X rect=%d/%d/%d/%d\n",s_windows[$slot].resourceID,*(short*)($window+108),*(unsigned char*)($window+110),s_windowList,*(short*)($window+16),*(short*)($window+18),*(short*)($window+20),*(short*)($window+22)
set $windowpm=*(unsigned long*)*(unsigned long*)($window+2)
dump binary memory ../tmp/resize-native-move-after-windowpm.bin (char*)$windowpm (char*)$windowpm+50
dump binary memory ../tmp/resize-native-move-after-gray.bin (char*)s_grayRgn (char*)s_grayRgn+*(unsigned short*)s_grayRgn
dump binary memory ../tmp/resize-native-move-after-front.bin (char*)s_windowList (char*)s_windowList+156
set $region=*(unsigned long*)*(unsigned long*)($window+24)
dump binary memory ../tmp/resize-native-move-after-visibility.bin (char*)$region (char*)$region+*(unsigned short*)$region
set $region=*(unsigned long*)*(unsigned long*)($window+28)
dump binary memory ../tmp/resize-native-move-after-clip.bin (char*)$region (char*)$region+*(unsigned short*)$region
set $region=*(unsigned long*)*(unsigned long*)($window+114)
dump binary memory ../tmp/resize-native-move-after-structure.bin (char*)$region (char*)$region+*(unsigned short*)$region
set $region=*(unsigned long*)*(unsigned long*)($window+118)
dump binary memory ../tmp/resize-native-move-after-content.bin (char*)$region (char*)$region+*(unsigned short*)$region
set $region=*(unsigned long*)*(unsigned long*)($window+122)
dump binary memory ../tmp/resize-native-move-after-update.bin (char*)$region (char*)$region+*(unsigned short*)$region
echo PASS native window reassert state capture\n

continue
printf "RESIZE_NEXT state=%u trap=%X selector=%X segment=%u offset=%X manager=%s routine=%s windows=%u services=%u/%u\n",g_stageBState,g_trapWord,g_trapSelector,g_trapSegment,g_trapOffset,g_trapManager,g_trapRoutine,g_systemWindows,g_macServiceEntered,g_macServiceCompleted
if g_stageBState!=3 || g_trapWord!=0xa8ec || g_trapSegment!=13 || g_trapOffset!=0x7fa || g_macServiceActive!=0
 echo FAIL window reassert progression\n
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
echo PASS native window reassert next-stop original-MDRV=absent\n
detach
quit 0
