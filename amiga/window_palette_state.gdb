set pagination off
set confirm off
set width 0
break AitdScreen::showLoudStop
tbreak dispatchMacTrap if trap==0xa91b && *(unsigned long*)(frame+2)==(unsigned long)s_segments[9].begin+0xfac
continue
set $misc=s_segments[9].begin
set $args=(unsigned long)userStack
set $window=*(unsigned long*)($args+6)
printf "WP_ENTER label=move sp=%X args=%08X%08X%08X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$args,*(unsigned long*)$args,*(unsigned long*)($args+4),*(unsigned long*)($args+8),regs[0],regs[1],regs[2],regs[3],regs[4],regs[5],regs[6],regs[7],regs[8],regs[9],regs[10],regs[11],regs[12],regs[13],regs[14]
printf "WP_SITE label=move offset=%X opcode=%X\n",*(unsigned long*)(frame+2)-(unsigned long)$misc,*(unsigned short*)($misc+0xfac)
printf "WP_BYTES label=move data=%04X%04X%04X%04X%04X%04X%04X%04X%04X%04X%04X%04X%04X%04X%04X%04X\n",*(unsigned short*)($misc+0xf94),*(unsigned short*)($misc+0xf96),*(unsigned short*)($misc+0xf98),*(unsigned short*)($misc+0xf9a),*(unsigned short*)($misc+0xf9c),*(unsigned short*)($misc+0xf9e),*(unsigned short*)($misc+0xfa0),*(unsigned short*)($misc+0xfa2),*(unsigned short*)($misc+0xfa4),*(unsigned short*)($misc+0xfa6),*(unsigned short*)($misc+0xfa8),*(unsigned short*)($misc+0xfaa),*(unsigned short*)($misc+0xfac),*(unsigned short*)($misc+0xfae),*(unsigned short*)($misc+0xfb0),*(unsigned short*)($misc+0xfb2)
set $palette=(unsigned long)g_defaultPalette
set $body=*(unsigned long*)$palette
set $private=*(unsigned long*)($body+12)
set $privatebody=*(unsigned long*)$private
printf "WP_STATE label=move phase=before window=%X palette=%X body=%X private=%X privateBody=%X gd=%X pm=%X clut=%X\n",$window,$palette,$body,$private,$privatebody,s_mainDevice,s_windowManagerPixMap,s_windowManagerColors
dump binary memory ../tmp/windowstate-native-move-before-palette.bin (char*)$body (char*)$body+4112
dump binary memory ../tmp/windowstate-native-move-before-private.bin (char*)$privatebody (char*)$privatebody+4
dump binary memory ../tmp/windowstate-native-move-before-window.bin (char*)$window (char*)$window+156
set $windowpm=*(unsigned long*)*(unsigned long*)($window+2)
dump binary memory ../tmp/windowstate-native-move-before-windowpm.bin (char*)$windowpm (char*)$windowpm+50
set $region=*(unsigned long*)*(unsigned long*)($window+24)
dump binary memory ../tmp/windowstate-native-move-before-visibility.bin (char*)$region (char*)$region+*(unsigned short*)$region
set $region=*(unsigned long*)*(unsigned long*)($window+28)
dump binary memory ../tmp/windowstate-native-move-before-clip.bin (char*)$region (char*)$region+*(unsigned short*)$region
set $region=*(unsigned long*)*(unsigned long*)($window+114)
dump binary memory ../tmp/windowstate-native-move-before-structure.bin (char*)$region (char*)$region+*(unsigned short*)$region
set $region=*(unsigned long*)*(unsigned long*)($window+118)
dump binary memory ../tmp/windowstate-native-move-before-content.bin (char*)$region (char*)$region+*(unsigned short*)$region
set $region=*(unsigned long*)*(unsigned long*)($window+122)
dump binary memory ../tmp/windowstate-native-move-before-update.bin (char*)$region (char*)$region+*(unsigned short*)$region
dump binary memory ../tmp/windowstate-native-move-before-gd.bin (char*)s_mainDevice (char*)s_mainDevice+62
dump binary memory ../tmp/windowstate-native-move-before-pm.bin (char*)s_windowManagerPixMap (char*)s_windowManagerPixMap+50
dump binary memory ../tmp/windowstate-native-move-before-clut.bin (char*)s_windowManagerColors (char*)s_windowManagerColors+2056
dump binary memory ../tmp/windowstate-native-move-before-logical.bin (char*)s_colorScreen (char*)s_colorScreen+307200
printf "WP_NATIVE label=move phase=before active=%X seed=%X\n",s_activePalette,s_colorSeed
tbreak *($misc+0xfae)
continue
if $pc!=$misc+0xfae
 echo FAIL window palette return\n
 detach
 quit 1
end
printf "WP_RETURN label=move sp=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$sp,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
set $palette=(unsigned long)g_defaultPalette
set $body=*(unsigned long*)$palette
set $private=*(unsigned long*)($body+12)
set $privatebody=*(unsigned long*)$private
printf "WP_STATE label=move phase=after window=%X palette=%X body=%X private=%X privateBody=%X gd=%X pm=%X clut=%X\n",$window,$palette,$body,$private,$privatebody,s_mainDevice,s_windowManagerPixMap,s_windowManagerColors
dump binary memory ../tmp/windowstate-native-move-after-palette.bin (char*)$body (char*)$body+4112
dump binary memory ../tmp/windowstate-native-move-after-private.bin (char*)$privatebody (char*)$privatebody+4
dump binary memory ../tmp/windowstate-native-move-after-window.bin (char*)$window (char*)$window+156
set $windowpm=*(unsigned long*)*(unsigned long*)($window+2)
dump binary memory ../tmp/windowstate-native-move-after-windowpm.bin (char*)$windowpm (char*)$windowpm+50
set $region=*(unsigned long*)*(unsigned long*)($window+24)
dump binary memory ../tmp/windowstate-native-move-after-visibility.bin (char*)$region (char*)$region+*(unsigned short*)$region
set $region=*(unsigned long*)*(unsigned long*)($window+28)
dump binary memory ../tmp/windowstate-native-move-after-clip.bin (char*)$region (char*)$region+*(unsigned short*)$region
set $region=*(unsigned long*)*(unsigned long*)($window+114)
dump binary memory ../tmp/windowstate-native-move-after-structure.bin (char*)$region (char*)$region+*(unsigned short*)$region
set $region=*(unsigned long*)*(unsigned long*)($window+118)
dump binary memory ../tmp/windowstate-native-move-after-content.bin (char*)$region (char*)$region+*(unsigned short*)$region
set $region=*(unsigned long*)*(unsigned long*)($window+122)
dump binary memory ../tmp/windowstate-native-move-after-update.bin (char*)$region (char*)$region+*(unsigned short*)$region
dump binary memory ../tmp/windowstate-native-move-after-gd.bin (char*)s_mainDevice (char*)s_mainDevice+62
dump binary memory ../tmp/windowstate-native-move-after-pm.bin (char*)s_windowManagerPixMap (char*)s_windowManagerPixMap+50
dump binary memory ../tmp/windowstate-native-move-after-clut.bin (char*)s_windowManagerColors (char*)s_windowManagerColors+2056
dump binary memory ../tmp/windowstate-native-move-after-logical.bin (char*)s_colorScreen (char*)s_colorScreen+307200
printf "WP_NATIVE label=move phase=after active=%X seed=%X\n",s_activePalette,s_colorSeed
tbreak dispatchMacTrap if trap==0xa915 && *(unsigned long*)(frame+2)==(unsigned long)s_segments[9].begin+0x10e6
continue
set $misc=s_segments[9].begin
set $args=(unsigned long)userStack
set $window=*(unsigned long*)($args+0)
printf "WP_ENTER label=show sp=%X args=%08X%08X%08X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$args,*(unsigned long*)$args,*(unsigned long*)($args+4),*(unsigned long*)($args+8),regs[0],regs[1],regs[2],regs[3],regs[4],regs[5],regs[6],regs[7],regs[8],regs[9],regs[10],regs[11],regs[12],regs[13],regs[14]
printf "WP_SITE label=show offset=%X opcode=%X\n",*(unsigned long*)(frame+2)-(unsigned long)$misc,*(unsigned short*)($misc+0x10e6)
printf "WP_BYTES label=show data=%04X%04X%04X\n",*(unsigned short*)($misc+0x10e2),*(unsigned short*)($misc+0x10e4),*(unsigned short*)($misc+0x10e6)
set $palette=(unsigned long)g_defaultPalette
set $body=*(unsigned long*)$palette
set $private=*(unsigned long*)($body+12)
set $privatebody=*(unsigned long*)$private
printf "WP_STATE label=show phase=before window=%X palette=%X body=%X private=%X privateBody=%X gd=%X pm=%X clut=%X\n",$window,$palette,$body,$private,$privatebody,s_mainDevice,s_windowManagerPixMap,s_windowManagerColors
dump binary memory ../tmp/windowstate-native-show-before-palette.bin (char*)$body (char*)$body+4112
dump binary memory ../tmp/windowstate-native-show-before-private.bin (char*)$privatebody (char*)$privatebody+4
dump binary memory ../tmp/windowstate-native-show-before-window.bin (char*)$window (char*)$window+156
set $windowpm=*(unsigned long*)*(unsigned long*)($window+2)
dump binary memory ../tmp/windowstate-native-show-before-windowpm.bin (char*)$windowpm (char*)$windowpm+50
set $region=*(unsigned long*)*(unsigned long*)($window+24)
dump binary memory ../tmp/windowstate-native-show-before-visibility.bin (char*)$region (char*)$region+*(unsigned short*)$region
set $region=*(unsigned long*)*(unsigned long*)($window+28)
dump binary memory ../tmp/windowstate-native-show-before-clip.bin (char*)$region (char*)$region+*(unsigned short*)$region
set $region=*(unsigned long*)*(unsigned long*)($window+114)
dump binary memory ../tmp/windowstate-native-show-before-structure.bin (char*)$region (char*)$region+*(unsigned short*)$region
set $region=*(unsigned long*)*(unsigned long*)($window+118)
dump binary memory ../tmp/windowstate-native-show-before-content.bin (char*)$region (char*)$region+*(unsigned short*)$region
set $region=*(unsigned long*)*(unsigned long*)($window+122)
dump binary memory ../tmp/windowstate-native-show-before-update.bin (char*)$region (char*)$region+*(unsigned short*)$region
dump binary memory ../tmp/windowstate-native-show-before-gd.bin (char*)s_mainDevice (char*)s_mainDevice+62
dump binary memory ../tmp/windowstate-native-show-before-pm.bin (char*)s_windowManagerPixMap (char*)s_windowManagerPixMap+50
dump binary memory ../tmp/windowstate-native-show-before-clut.bin (char*)s_windowManagerColors (char*)s_windowManagerColors+2056
dump binary memory ../tmp/windowstate-native-show-before-logical.bin (char*)s_colorScreen (char*)s_colorScreen+307200
printf "WP_NATIVE label=show phase=before active=%X seed=%X\n",s_activePalette,s_colorSeed
tbreak *($misc+0x10e8)
continue
if $pc!=$misc+0x10e8
 echo FAIL window palette return\n
 detach
 quit 1
end
printf "WP_RETURN label=show sp=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$sp,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
set $palette=(unsigned long)g_defaultPalette
set $body=*(unsigned long*)$palette
set $private=*(unsigned long*)($body+12)
set $privatebody=*(unsigned long*)$private
printf "WP_STATE label=show phase=after window=%X palette=%X body=%X private=%X privateBody=%X gd=%X pm=%X clut=%X\n",$window,$palette,$body,$private,$privatebody,s_mainDevice,s_windowManagerPixMap,s_windowManagerColors
dump binary memory ../tmp/windowstate-native-show-after-palette.bin (char*)$body (char*)$body+4112
dump binary memory ../tmp/windowstate-native-show-after-private.bin (char*)$privatebody (char*)$privatebody+4
dump binary memory ../tmp/windowstate-native-show-after-window.bin (char*)$window (char*)$window+156
set $windowpm=*(unsigned long*)*(unsigned long*)($window+2)
dump binary memory ../tmp/windowstate-native-show-after-windowpm.bin (char*)$windowpm (char*)$windowpm+50
set $region=*(unsigned long*)*(unsigned long*)($window+24)
dump binary memory ../tmp/windowstate-native-show-after-visibility.bin (char*)$region (char*)$region+*(unsigned short*)$region
set $region=*(unsigned long*)*(unsigned long*)($window+28)
dump binary memory ../tmp/windowstate-native-show-after-clip.bin (char*)$region (char*)$region+*(unsigned short*)$region
set $region=*(unsigned long*)*(unsigned long*)($window+114)
dump binary memory ../tmp/windowstate-native-show-after-structure.bin (char*)$region (char*)$region+*(unsigned short*)$region
set $region=*(unsigned long*)*(unsigned long*)($window+118)
dump binary memory ../tmp/windowstate-native-show-after-content.bin (char*)$region (char*)$region+*(unsigned short*)$region
set $region=*(unsigned long*)*(unsigned long*)($window+122)
dump binary memory ../tmp/windowstate-native-show-after-update.bin (char*)$region (char*)$region+*(unsigned short*)$region
dump binary memory ../tmp/windowstate-native-show-after-gd.bin (char*)s_mainDevice (char*)s_mainDevice+62
dump binary memory ../tmp/windowstate-native-show-after-pm.bin (char*)s_windowManagerPixMap (char*)s_windowManagerPixMap+50
dump binary memory ../tmp/windowstate-native-show-after-clut.bin (char*)s_windowManagerColors (char*)s_windowManagerColors+2056
dump binary memory ../tmp/windowstate-native-show-after-logical.bin (char*)s_colorScreen (char*)s_colorScreen+307200
printf "WP_NATIVE label=show phase=after active=%X seed=%X\n",s_activePalette,s_colorSeed
printf "WP_DIRTY pending=%u count=%u queued=%u rect=%d/%d/%d/%d\n",s_pixelsDirty,s_dirtyRectCount,g_macFramesQueued,s_dirtyRects[0].left,s_dirtyRects[0].top,s_dirtyRects[0].right,s_dirtyRects[0].bottom
if !((s_pixelsDirty && s_dirtyRectCount==1 && g_macFramesQueued==0) || (!s_pixelsDirty && s_dirtyRectCount==0 && g_macFramesQueued==1)) || s_dirtyRects[0].left!=160 || s_dirtyRects[0].top!=150 || s_dirtyRects[0].right!=480 || s_dirtyRects[0].bottom!=350
 echo FAIL content dirty rectangle\n
 detach
 quit 1
end
echo PASS native window palette state calls=2\n
continue
if s_pixelsDirty || s_dirtyRectCount!=0 || g_macFramesQueued!=1
 echo FAIL clear not queued\n
 detach
 quit 1
end
printf "WP_NEXT state=%u trap=%X segment=%u offset=%X manager=%s routine=%s windows=%u services=%u/%u\n",g_stageBState,g_trapWord,g_trapSegment,g_trapOffset,g_trapManager,g_trapRoutine,g_systemWindows,g_macServiceEntered,g_macServiceCompleted
if g_stageBState!=3 || g_trapWord!=0xaa19 || g_trapSegment!=12 || g_trapOffset!=0x623c || g_macServiceActive!=0
 echo FAIL window palette presentation stop\n
 detach
 quit 1
end
if *(unsigned long*)(g_trapRoutine+0)!=0x47455450 || *(unsigned long*)(g_trapRoutine+4)!=0x49584241 || *(unsigned long*)(g_trapRoutine+8)!=0x53454144 || *(unsigned short*)(g_trapRoutine+12)!=0x4452 || g_trapRoutine[14]!=0
 echo FAIL expected SETGWORLD\n
 detach
 quit 1
end
set $i=0
set $colors=0
while $i<g_resourceCount
 if s_resourceForks.m_items[$i].item.type==0x4d445256 && s_resourceHandles[$i]!=0
  echo FAIL original MDRV resident\n
  detach
  quit 1
 end
 if s_resourceForks.m_items[$i].item.type==0x77637462 && s_resourceHandles[$i]!=0
  set $body=*(unsigned long*)s_resourceHandles[$i]
  if s_resourceForks.m_items[$i].item.id==128
   dump binary memory ../tmp/windowstate-native-wctb128.bin (char*)$body (char*)$body+48
   set $colors=$colors+1
  end
  if s_resourceForks.m_items[$i].item.id==131
   dump binary memory ../tmp/windowstate-native-wctb131.bin (char*)$body (char*)$body+48
   set $colors=$colors+1
  end
 end
 set $i=$i+1
end
if $colors!=2
 echo FAIL missing window colour resources\n
 detach
 quit 1
end
printf "WP_COUNTS app=%u/%u overlay=%u/%u prep=%u/%u resources=%u\n",g_resourceRuntimeReads,g_resourceRuntimeBytes,g_overlayRuntimeReads,g_overlayRuntimeBytes,g_overlaySourceReads,g_overlaySourceBytes,g_resourceCount
echo PASS native window colours=2 original-MDRV=absent\n
detach
quit 0
