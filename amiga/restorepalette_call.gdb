set $bind_args=(unsigned long)userStack
set $bind_ret=*(unsigned long*)(frame+2)+2
set $bind_window=*(unsigned long*)($bind_args+6)
set $bind_palette=*(unsigned long*)($bind_args+2)
set $bind_old=(unsigned long)s_activePalette
set $bind_slot=0
while $bind_slot<8 && s_windows[$bind_slot].window!=(unsigned char*)$bind_window
 set $bind_slot=$bind_slot+1
end
if $bind_slot==8
 echo FAIL binding window\n
 detach
 quit 1
end
printf "RESTOREPAL_NATIVE_BYTES %04X%04X%04X%04X%04X%04X%04X%04X a5=%X\n",*(unsigned short*)($bind_ret-16),*(unsigned short*)($bind_ret-14),*(unsigned short*)($bind_ret-12),*(unsigned short*)($bind_ret-10),*(unsigned short*)($bind_ret-8),*(unsigned short*)($bind_ret-6),*(unsigned short*)($bind_ret-4),*(unsigned short*)($bind_ret-2),regs[13]
set $bind_reg0=regs[0]
set $bind_reg1=regs[1]
set $bind_reg2=regs[2]
set $bind_reg3=regs[3]
set $bind_reg4=regs[4]
set $bind_reg5=regs[5]
set $bind_reg6=regs[6]
set $bind_reg7=regs[7]
set $bind_reg8=regs[8]
set $bind_reg9=regs[9]
set $bind_reg10=regs[10]
set $bind_reg11=regs[11]
set $bind_reg12=regs[12]
set $bind_reg13=regs[13]
set $bind_reg14=regs[14]
printf "RESTOREPAL_NATIVE_STATE phase=enter window=%X palette=%X default=%X binding=%X active=%X updates=%u screenDirty=%u pixelDirty=%u rects=%u\n",$bind_window,$bind_palette,g_defaultPalette,s_windows[$bind_slot].palette,s_activePalette,s_windows[$bind_slot].paletteUpdates,s_screenDirty,s_pixelsDirty,s_dirtyRectCount
set $bind_addr=(unsigned long)($bind_window)
dump binary memory ../tmp/restorepal-native-enter-window.bin $bind_addr $bind_addr+156
set $bind_addr=(unsigned long)(*(unsigned long*)(*(unsigned long*)($bind_window+2)))
dump binary memory ../tmp/restorepal-native-enter-windowpm.bin $bind_addr $bind_addr+50
set $bind_addr=(unsigned long)(s_mainDevice)
dump binary memory ../tmp/restorepal-native-enter-gd.bin $bind_addr $bind_addr+62
set $bind_addr=(unsigned long)(s_windowManagerPixMap)
dump binary memory ../tmp/restorepal-native-enter-pm.bin $bind_addr $bind_addr+50
set $bind_addr=(unsigned long)(s_windowManagerColors)
dump binary memory ../tmp/restorepal-native-enter-clut.bin $bind_addr $bind_addr+2056
set $bind_addr=(unsigned long)(s_colorScreen)
dump binary memory ../tmp/restorepal-native-enter-pixels.bin $bind_addr $bind_addr+307200
set $bind_addr=(unsigned long)(*(unsigned long*)$bind_palette)
dump binary memory ../tmp/restorepal-native-enter-palette.bin $bind_addr $bind_addr+4112
set $bind_addr=(unsigned long)(*(unsigned long*)(*(unsigned long*)(*(unsigned long*)$bind_palette+12)))
dump binary memory ../tmp/restorepal-native-enter-private.bin $bind_addr $bind_addr+4
set $bind_addr=(unsigned long)(*(unsigned long*)$bind_old)
dump binary memory ../tmp/restorepal-native-enter-old.bin $bind_addr $bind_addr+4112
set $bind_addr=(unsigned long)(*(unsigned long*)(*(unsigned long*)(*(unsigned long*)$bind_old+12)))
dump binary memory ../tmp/restorepal-native-enter-old-private.bin $bind_addr $bind_addr+4
tbreak *$bind_ret
continue
if $pc!=$bind_ret || $sp!=$bind_args+10
 echo FAIL binding return\n
 detach
 quit 1
end
if $d3!=$bind_reg3
 echo FAIL binding preserved register\n
 detach
 quit 1
end
if $d4!=$bind_reg4
 echo FAIL binding preserved register\n
 detach
 quit 1
end
if $d5!=$bind_reg5
 echo FAIL binding preserved register\n
 detach
 quit 1
end
if $d6!=$bind_reg6
 echo FAIL binding preserved register\n
 detach
 quit 1
end
if $d7!=$bind_reg7
 echo FAIL binding preserved register\n
 detach
 quit 1
end
if $a2!=$bind_reg10
 echo FAIL binding preserved register\n
 detach
 quit 1
end
if $a3!=$bind_reg11
 echo FAIL binding preserved register\n
 detach
 quit 1
end
if $a4!=$bind_reg12
 echo FAIL binding preserved register\n
 detach
 quit 1
end
if $a5!=$bind_reg13
 echo FAIL binding preserved register\n
 detach
 quit 1
end
if $a6!=$bind_reg14
 echo FAIL binding preserved register\n
 detach
 quit 1
end
printf "RESTOREPAL_NATIVE_STATE phase=return window=%X palette=%X default=%X binding=%X active=%X updates=%u screenDirty=%u pixelDirty=%u rects=%u\n",$bind_window,$bind_palette,g_defaultPalette,s_windows[$bind_slot].palette,s_activePalette,s_windows[$bind_slot].paletteUpdates,s_screenDirty,s_pixelsDirty,s_dirtyRectCount
set $bind_addr=(unsigned long)($bind_window)
dump binary memory ../tmp/restorepal-native-return-window.bin $bind_addr $bind_addr+156
set $bind_addr=(unsigned long)(*(unsigned long*)(*(unsigned long*)($bind_window+2)))
dump binary memory ../tmp/restorepal-native-return-windowpm.bin $bind_addr $bind_addr+50
set $bind_addr=(unsigned long)(s_mainDevice)
dump binary memory ../tmp/restorepal-native-return-gd.bin $bind_addr $bind_addr+62
set $bind_addr=(unsigned long)(s_windowManagerPixMap)
dump binary memory ../tmp/restorepal-native-return-pm.bin $bind_addr $bind_addr+50
set $bind_addr=(unsigned long)(s_windowManagerColors)
dump binary memory ../tmp/restorepal-native-return-clut.bin $bind_addr $bind_addr+2056
set $bind_addr=(unsigned long)(s_colorScreen)
dump binary memory ../tmp/restorepal-native-return-pixels.bin $bind_addr $bind_addr+307200
set $bind_addr=(unsigned long)(*(unsigned long*)$bind_palette)
dump binary memory ../tmp/restorepal-native-return-palette.bin $bind_addr $bind_addr+4112
set $bind_addr=(unsigned long)(*(unsigned long*)(*(unsigned long*)(*(unsigned long*)$bind_palette+12)))
dump binary memory ../tmp/restorepal-native-return-private.bin $bind_addr $bind_addr+4
set $bind_addr=(unsigned long)(*(unsigned long*)$bind_old)
dump binary memory ../tmp/restorepal-native-return-old.bin $bind_addr $bind_addr+4112
set $bind_addr=(unsigned long)(*(unsigned long*)(*(unsigned long*)(*(unsigned long*)$bind_old+12)))
dump binary memory ../tmp/restorepal-native-return-old-private.bin $bind_addr $bind_addr+4
echo PASS native palette restoration ABI\n
tbreak aitdMacMouseVBI if g_macFramesPresented==7
continue
set $screen=s_loudStopScreen
printf "RESTOREPAL_AGA front=%X queued=%u presented=%u pending=%u line=%u late=%u\n",$screen->m_chip,g_macFramesQueued,g_macFramesPresented,$screen->m_framePending,g_beamPresentLine,g_beamPresentsLate
dump binary memory ../tmp/restorepal-aga-planes.bin (char*)$screen->m_chip (char*)$screen->m_chip+64000
dump binary memory ../tmp/restorepal-aga-copper.bin (char*)$screen->m_copper (char*)$screen->m_copper+2248
