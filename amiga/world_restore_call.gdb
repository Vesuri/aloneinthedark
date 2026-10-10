set $engine=s_segments[9].begin
mac-trap-args
set $args=(unsigned long)$mac_stack
set $window=*(unsigned long*)($args+4)
set $pm=*(unsigned long*)*(unsigned long*)($window+2)
printf "WB_ENTER sp=%X device=%X window=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$args,*(unsigned long*)$args,$window,$mac_regs[0],$mac_regs[1],$mac_regs[2],$mac_regs[3],$mac_regs[4],$mac_regs[5],$mac_regs[6],$mac_regs[7],$mac_regs[8],$mac_regs[9],$mac_regs[10],$mac_regs[11],$mac_regs[12],$mac_regs[13],$mac_regs[14]
printf "WB_BYTES data=%04X%04X%04X%04X%04X%04X%04X\n",*(unsigned short*)($engine+0xdfe),*(unsigned short*)($engine+0xe00),*(unsigned short*)($engine+0xe02),*(unsigned short*)($engine+0xe04),*(unsigned short*)($engine+0xe06),*(unsigned short*)($engine+0xe08),*(unsigned short*)($engine+0xe0a)
printf "WB_STATE phase=before port=%X main=%X device=%X\n",*(unsigned long*)s_qdThePort,&s_mainDeviceMaster,&s_mainDeviceMaster
printf "WB_NATIVE phase=before queued=%u dirty=%u seed=%u\n",g_macFramesQueued,s_pixelsDirty,s_colorSeed
dump binary memory ../tmp/worldrestore-native-before-window.bin (char*)$window (char*)$window+156
dump binary memory ../tmp/worldrestore-native-before-pm.bin (char*)$pm (char*)$pm+50
dump binary memory ../tmp/worldrestore-native-before-device.bin (char*)s_mainDevice (char*)s_mainDevice+62
dump binary memory ../tmp/worldrestore-native-before-pixels.bin (char*)s_colorScreen (char*)s_colorScreen+307200
dump binary memory ../tmp/worldrestore-native-before-clut.bin (char*)s_windowManagerColors (char*)s_windowManagerColors+2056
tbreak *($engine+0xe0c)
continue
if $pc!=$engine+0xe0c
 echo FAIL SetGWorld return\n
 detach
 quit 1
end
printf "WB_RETURN sp=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$sp,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
printf "WB_STATE phase=after port=%X main=%X device=%X\n",*(unsigned long*)s_qdThePort,&s_mainDeviceMaster,&s_mainDeviceMaster
printf "WB_NATIVE phase=after queued=%u dirty=%u seed=%u\n",g_macFramesQueued,s_pixelsDirty,s_colorSeed
dump binary memory ../tmp/worldrestore-native-after-window.bin (char*)$window (char*)$window+156
dump binary memory ../tmp/worldrestore-native-after-pm.bin (char*)$pm (char*)$pm+50
dump binary memory ../tmp/worldrestore-native-after-device.bin (char*)s_mainDevice (char*)s_mainDevice+62
dump binary memory ../tmp/worldrestore-native-after-pixels.bin (char*)s_colorScreen (char*)s_colorScreen+307200
dump binary memory ../tmp/worldrestore-native-after-clut.bin (char*)s_windowManagerColors (char*)s_windowManagerColors+2056
echo PASS native world restoration\n
