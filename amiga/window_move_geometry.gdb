set pagination off
set confirm off
set width 0
break AitdScreen::showLoudStop
tbreak dispatchMacTrap if trap==0xa91b && *(unsigned short*)(*(unsigned long*)(userStack+6)+108)==8 && *(unsigned long*)(frame+2)==(unsigned long)s_segments[7].begin+0x48a2
continue
set $misc=s_segments[7].begin
set $args=(unsigned long)userStack
set $window=*(unsigned long*)($args+6)
printf "WP_ENTER label=move sp=%X args=%08X%08X%08X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$args,*(unsigned long*)$args,*(unsigned long*)($args+4),*(unsigned long*)($args+8),regs[0],regs[1],regs[2],regs[3],regs[4],regs[5],regs[6],regs[7],regs[8],regs[9],regs[10],regs[11],regs[12],regs[13],regs[14]
printf "WP_SITE label=move offset=%X opcode=%X\n",*(unsigned long*)(frame+2)-(unsigned long)$misc,*(unsigned short*)($misc+0x48a2)
printf "WP_BYTES label=move data=%04X%04X%04X%04X%04X%04X%04X%04X%04X%04X\n",*(unsigned short*)($misc+0x4890),*(unsigned short*)($misc+0x4892),*(unsigned short*)($misc+0x4894),*(unsigned short*)($misc+0x4896),*(unsigned short*)($misc+0x4898),*(unsigned short*)($misc+0x489a),*(unsigned short*)($misc+0x489c),*(unsigned short*)($misc+0x489e),*(unsigned short*)($misc+0x48a0),*(unsigned short*)($misc+0x48a2)
set $palette=(unsigned long)g_defaultPalette
set $body=*(unsigned long*)$palette
set $private=*(unsigned long*)($body+12)
set $privatebody=*(unsigned long*)$private
printf "WP_STATE label=move phase=before window=%X palette=%X body=%X private=%X privateBody=%X gd=%X pm=%X clut=%X\n",$window,$palette,$body,$private,$privatebody,s_mainDevice,s_windowManagerPixMap,s_windowManagerColors
dump binary memory ../tmp/windowmove-native-move-before-palette.bin (char*)$body (char*)$body+4112
dump binary memory ../tmp/windowmove-native-move-before-private.bin (char*)$privatebody (char*)$privatebody+4
dump binary memory ../tmp/windowmove-native-move-before-window.bin (char*)$window (char*)$window+156
set $windowpm=*(unsigned long*)*(unsigned long*)($window+2)
dump binary memory ../tmp/windowmove-native-move-before-windowpm.bin (char*)$windowpm (char*)$windowpm+50
set $region=*(unsigned long*)*(unsigned long*)($window+24)
dump binary memory ../tmp/windowmove-native-move-before-visibility.bin (char*)$region (char*)$region+*(unsigned short*)$region
set $region=*(unsigned long*)*(unsigned long*)($window+28)
dump binary memory ../tmp/windowmove-native-move-before-clip.bin (char*)$region (char*)$region+*(unsigned short*)$region
set $region=*(unsigned long*)*(unsigned long*)($window+114)
dump binary memory ../tmp/windowmove-native-move-before-structure.bin (char*)$region (char*)$region+*(unsigned short*)$region
set $region=*(unsigned long*)*(unsigned long*)($window+118)
dump binary memory ../tmp/windowmove-native-move-before-content.bin (char*)$region (char*)$region+*(unsigned short*)$region
set $region=*(unsigned long*)*(unsigned long*)($window+122)
dump binary memory ../tmp/windowmove-native-move-before-update.bin (char*)$region (char*)$region+*(unsigned short*)$region
dump binary memory ../tmp/windowmove-native-move-before-gd.bin (char*)s_mainDevice (char*)s_mainDevice+62
dump binary memory ../tmp/windowmove-native-move-before-pm.bin (char*)s_windowManagerPixMap (char*)s_windowManagerPixMap+50
dump binary memory ../tmp/windowmove-native-move-before-clut.bin (char*)s_windowManagerColors (char*)s_windowManagerColors+2056
dump binary memory ../tmp/windowmove-native-move-before-logical.bin (char*)s_colorScreen (char*)s_colorScreen+307200
printf "WP_NATIVE label=move phase=before active=%X seed=%X\n",s_activePalette,s_colorSeed
tbreak *($misc+0x48a4)
continue
if $pc!=$misc+0x48a4
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
dump binary memory ../tmp/windowmove-native-move-after-palette.bin (char*)$body (char*)$body+4112
dump binary memory ../tmp/windowmove-native-move-after-private.bin (char*)$privatebody (char*)$privatebody+4
dump binary memory ../tmp/windowmove-native-move-after-window.bin (char*)$window (char*)$window+156
set $windowpm=*(unsigned long*)*(unsigned long*)($window+2)
dump binary memory ../tmp/windowmove-native-move-after-windowpm.bin (char*)$windowpm (char*)$windowpm+50
set $region=*(unsigned long*)*(unsigned long*)($window+24)
dump binary memory ../tmp/windowmove-native-move-after-visibility.bin (char*)$region (char*)$region+*(unsigned short*)$region
set $region=*(unsigned long*)*(unsigned long*)($window+28)
dump binary memory ../tmp/windowmove-native-move-after-clip.bin (char*)$region (char*)$region+*(unsigned short*)$region
set $region=*(unsigned long*)*(unsigned long*)($window+114)
dump binary memory ../tmp/windowmove-native-move-after-structure.bin (char*)$region (char*)$region+*(unsigned short*)$region
set $region=*(unsigned long*)*(unsigned long*)($window+118)
dump binary memory ../tmp/windowmove-native-move-after-content.bin (char*)$region (char*)$region+*(unsigned short*)$region
set $region=*(unsigned long*)*(unsigned long*)($window+122)
dump binary memory ../tmp/windowmove-native-move-after-update.bin (char*)$region (char*)$region+*(unsigned short*)$region
dump binary memory ../tmp/windowmove-native-move-after-gd.bin (char*)s_mainDevice (char*)s_mainDevice+62
dump binary memory ../tmp/windowmove-native-move-after-pm.bin (char*)s_windowManagerPixMap (char*)s_windowManagerPixMap+50
dump binary memory ../tmp/windowmove-native-move-after-clut.bin (char*)s_windowManagerColors (char*)s_windowManagerColors+2056
dump binary memory ../tmp/windowmove-native-move-after-logical.bin (char*)s_colorScreen (char*)s_colorScreen+307200
printf "WP_NATIVE label=move phase=after active=%X seed=%X\n",s_activePalette,s_colorSeed
echo PASS native window move geometry\n
detach
quit 0
