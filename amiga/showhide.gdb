set pagination off
set confirm off
set width 0
break AitdScreen::showLoudStop
tbreak dispatchMacTrap if trap==0xa908 && *(unsigned long*)(frame+2)==(unsigned long)s_segments[9].begin+0xfc6
continue
set $misc=s_segments[9].begin
set $args=(unsigned long)userStack
set $palette=(unsigned long)g_defaultPalette
set $body=*(unsigned long*)$palette
set $private=*(unsigned long*)($body+12)
set $privatebody=*(unsigned long*)$private
set $window=*(unsigned long*)($args+2)
set $slot=0
while $slot<8 && s_windows[$slot].window!=(unsigned char*)$window
 set $slot=$slot+1
end
if $slot==8
 echo FAIL window not found\n
 detach
 quit 1
end
printf "SH_ENTER sp=%X args=%04X%08X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$args,*(unsigned short*)$args,*(unsigned long*)($args+2),regs[0],regs[1],regs[2],regs[3],regs[4],regs[5],regs[6],regs[7],regs[8],regs[9],regs[10],regs[11],regs[12],regs[13],regs[14]
printf "SH_BYTES data=%04X%04X%04X%04X%04X%04X%04X%04X%04X%04X\n",*(unsigned short*)($misc+0xfb4),*(unsigned short*)($misc+0xfb6),*(unsigned short*)($misc+0xfb8),*(unsigned short*)($misc+0xfba),*(unsigned short*)($misc+0xfbc),*(unsigned short*)($misc+0xfbe),*(unsigned short*)($misc+0xfc0),*(unsigned short*)($misc+0xfc2),*(unsigned short*)($misc+0xfc4),*(unsigned short*)($misc+0xfc6)
printf "SH_NATIVE_STATE phase=before palette=%X body=%X private=%X privateBody=%X binding=%X updates=%u default=%X active=%X seed=%X queued=%u dirty=%u count=%u\n",$palette,$body,$private,$privatebody,s_windows[$slot].palette,s_windows[$slot].paletteUpdates,g_defaultPalette,s_activePalette,s_colorSeed,g_macFramesQueued,s_pixelsDirty,s_dirtyRectCount
dump binary memory ../tmp/showhide-native-showhide-before-palette.bin (char*)$body (char*)$body+4112
dump binary memory ../tmp/showhide-native-showhide-before-private.bin (char*)$privatebody (char*)$privatebody+4
dump binary memory ../tmp/showhide-native-showhide-before-window.bin (char*)$window (char*)$window+156
dump binary memory ../tmp/showhide-native-showhide-before-gd.bin (char*)s_mainDevice (char*)s_mainDevice+62
dump binary memory ../tmp/showhide-native-showhide-before-pm.bin (char*)s_windowManagerPixMap (char*)s_windowManagerPixMap+50
dump binary memory ../tmp/showhide-native-showhide-before-clut.bin (char*)s_windowManagerColors (char*)s_windowManagerColors+2056
dump binary memory ../tmp/showhide-native-showhide-before-physical.bin (char*)s_colorScreen (char*)s_colorScreen+307200
dump binary memory ../tmp/showhide-native-showhide-before-copper.bin (char*)s_loudStopScreen->m_copperAllocation (char*)s_loudStopScreen->m_copperAllocation+4496
dump binary memory ../tmp/showhide-native-showhide-before-pending.bin (char*)s_loudStopScreen->m_nextPalette (char*)s_loudStopScreen->m_nextPalette+1024
printf "SH_WINDOW id=%d kind=%d visible=%u front=%X rect=%d/%d/%d/%d\n",s_windows[$slot].resourceID,*(short*)($window+108),*(unsigned char*)($window+110),s_windowList,*(short*)($window+16),*(short*)($window+18),*(short*)($window+20),*(short*)($window+22)
set $windowpm=*(unsigned long*)*(unsigned long*)($window+2)
dump binary memory ../tmp/showhide-native-showhide-before-windowpm.bin (char*)$windowpm (char*)$windowpm+50
dump binary memory ../tmp/showhide-native-showhide-before-gray.bin (char*)s_grayRgn (char*)s_grayRgn+*(unsigned short*)s_grayRgn
dump binary memory ../tmp/showhide-native-showhide-before-front.bin (char*)s_windowList (char*)s_windowList+156
set $region=*(unsigned long*)*(unsigned long*)($window+24)
dump binary memory ../tmp/showhide-native-showhide-before-visibility.bin (char*)$region (char*)$region+*(unsigned short*)$region
set $region=*(unsigned long*)*(unsigned long*)($window+28)
dump binary memory ../tmp/showhide-native-showhide-before-clip.bin (char*)$region (char*)$region+*(unsigned short*)$region
set $region=*(unsigned long*)*(unsigned long*)($window+114)
dump binary memory ../tmp/showhide-native-showhide-before-structure.bin (char*)$region (char*)$region+*(unsigned short*)$region
set $region=*(unsigned long*)*(unsigned long*)($window+118)
dump binary memory ../tmp/showhide-native-showhide-before-content.bin (char*)$region (char*)$region+*(unsigned short*)$region
set $region=*(unsigned long*)*(unsigned long*)($window+122)
dump binary memory ../tmp/showhide-native-showhide-before-update.bin (char*)$region (char*)$region+*(unsigned short*)$region
tbreak *($misc+0xfc8)
continue
if $pc!=$misc+0xfc8
 echo FAIL ShowHide return\n
 detach
 quit 1
end
printf "SH_RETURN sp=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$sp,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
printf "SH_NATIVE_STATE phase=after palette=%X body=%X private=%X privateBody=%X binding=%X updates=%u default=%X active=%X seed=%X queued=%u dirty=%u count=%u\n",$palette,$body,$private,$privatebody,s_windows[$slot].palette,s_windows[$slot].paletteUpdates,g_defaultPalette,s_activePalette,s_colorSeed,g_macFramesQueued,s_pixelsDirty,s_dirtyRectCount
dump binary memory ../tmp/showhide-native-showhide-after-palette.bin (char*)$body (char*)$body+4112
dump binary memory ../tmp/showhide-native-showhide-after-private.bin (char*)$privatebody (char*)$privatebody+4
dump binary memory ../tmp/showhide-native-showhide-after-window.bin (char*)$window (char*)$window+156
dump binary memory ../tmp/showhide-native-showhide-after-gd.bin (char*)s_mainDevice (char*)s_mainDevice+62
dump binary memory ../tmp/showhide-native-showhide-after-pm.bin (char*)s_windowManagerPixMap (char*)s_windowManagerPixMap+50
dump binary memory ../tmp/showhide-native-showhide-after-clut.bin (char*)s_windowManagerColors (char*)s_windowManagerColors+2056
dump binary memory ../tmp/showhide-native-showhide-after-physical.bin (char*)s_colorScreen (char*)s_colorScreen+307200
dump binary memory ../tmp/showhide-native-showhide-after-copper.bin (char*)s_loudStopScreen->m_copperAllocation (char*)s_loudStopScreen->m_copperAllocation+4496
dump binary memory ../tmp/showhide-native-showhide-after-pending.bin (char*)s_loudStopScreen->m_nextPalette (char*)s_loudStopScreen->m_nextPalette+1024
printf "SH_WINDOW id=%d kind=%d visible=%u front=%X rect=%d/%d/%d/%d\n",s_windows[$slot].resourceID,*(short*)($window+108),*(unsigned char*)($window+110),s_windowList,*(short*)($window+16),*(short*)($window+18),*(short*)($window+20),*(short*)($window+22)
set $windowpm=*(unsigned long*)*(unsigned long*)($window+2)
dump binary memory ../tmp/showhide-native-showhide-after-windowpm.bin (char*)$windowpm (char*)$windowpm+50
dump binary memory ../tmp/showhide-native-showhide-after-gray.bin (char*)s_grayRgn (char*)s_grayRgn+*(unsigned short*)s_grayRgn
dump binary memory ../tmp/showhide-native-showhide-after-front.bin (char*)s_windowList (char*)s_windowList+156
set $region=*(unsigned long*)*(unsigned long*)($window+24)
dump binary memory ../tmp/showhide-native-showhide-after-visibility.bin (char*)$region (char*)$region+*(unsigned short*)$region
set $region=*(unsigned long*)*(unsigned long*)($window+28)
dump binary memory ../tmp/showhide-native-showhide-after-clip.bin (char*)$region (char*)$region+*(unsigned short*)$region
set $region=*(unsigned long*)*(unsigned long*)($window+114)
dump binary memory ../tmp/showhide-native-showhide-after-structure.bin (char*)$region (char*)$region+*(unsigned short*)$region
set $region=*(unsigned long*)*(unsigned long*)($window+118)
dump binary memory ../tmp/showhide-native-showhide-after-content.bin (char*)$region (char*)$region+*(unsigned short*)$region
set $region=*(unsigned long*)*(unsigned long*)($window+122)
dump binary memory ../tmp/showhide-native-showhide-after-update.bin (char*)$region (char*)$region+*(unsigned short*)$region
echo PASS native ShowHide state capture\n
continue
printf "SH_NEXT state=%u trap=%X segment=%u offset=%X manager=%s routine=%s windows=%u services=%u/%u\n",g_stageBState,g_trapWord,g_trapSegment,g_trapOffset,g_trapManager,g_trapRoutine,g_systemWindows,g_macServiceEntered,g_macServiceCompleted
if g_stageBState!=3 || g_macServiceActive!=0 || g_trapWord!=0xa934 || g_trapSelector!=-1 || g_trapSegment!=7 || g_trapOffset!=0x2b06
 echo FAIL ShowHide progression\n
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
echo PASS native ShowHide next-stop original-MDRV=absent\n
detach
quit 0
