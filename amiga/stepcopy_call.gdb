set $pc_dirty=s_pixelsDirty
set $pc_rects=s_dirtyRectCount
set $pc_queued=g_macFramesQueued
set $pc_presented=g_macFramesPresented
mac-trap-args
set $cp_args=(unsigned long)$mac_stack
set $cp_ret=*(unsigned long*)($mac_frame+2)+2
set $cp_src=*(unsigned long*)($cp_args+18)
if (*(unsigned short*)($cp_src+4)&0xc000)==0xc000
 set $cp_src=*(unsigned long*)*(unsigned long*)$cp_src
end
set $cp_port=*(unsigned long*)s_qdThePort
set $cp_dst=*(unsigned long*)($cp_args+14)
if (*(unsigned short*)($cp_dst+4)&0xc000)==0xc000
 set $cp_dst=*(unsigned long*)*(unsigned long*)$cp_dst
end
set $cp_from=*(unsigned long*)($cp_args+10)
set $cp_to=*(unsigned long*)($cp_args+6)
set $cp_vis=*(unsigned long*)*(unsigned long*)($cp_port+24)
set $cp_clip=*(unsigned long*)*(unsigned long*)($cp_port+28)
set $cp_spx=*(unsigned long*)$cp_src
set $cp_dpx=*(unsigned long*)$cp_dst
set $cp_ss=(*(unsigned short*)($cp_src+4)&0x3fff)*(*(short*)($cp_src+10)-*(short*)($cp_src+6))
set $cp_ds=(*(unsigned short*)($cp_dst+4)&0x3fff)*(*(short*)($cp_dst+10)-*(short*)($cp_dst+6))
set $cp_sct=*(unsigned long*)*(unsigned long*)($cp_src+42)
set $cp_dct=*(unsigned long*)*(unsigned long*)($cp_dst+42)
printf "STEPCOPY_BYTES %04X%04X%04X%04X%04X%04X%04X\n",*(unsigned short*)($cp_ret-14),*(unsigned short*)($cp_ret-12),*(unsigned short*)($cp_ret-10),*(unsigned short*)($cp_ret-8),*(unsigned short*)($cp_ret-6),*(unsigned short*)($cp_ret-4),*(unsigned short*)($cp_ret-2)
printf "STEPCOPY_ARGS mask=%X mode=%X destination=%X expected=%X\n",*(unsigned long*)$cp_args,*(unsigned short*)($cp_args+4),*(unsigned long*)($cp_args+14),*(unsigned long*)*(unsigned long*)($cp_port+2)
mac-trap-args
printf "STEPCOPY_ENTER sp=%X source=%04X%04X%04X%04X target=%04X%04X%04X%04X d0=%08X d1=%08X d2=%08X d3=%08X d4=%08X d5=%08X d6=%08X d7=%08X a0=%08X a1=%08X a2=%08X a3=%08X a4=%08X a5=%08X a6=%08X\n",$cp_args,*(unsigned short*)($cp_from+0),*(unsigned short*)($cp_from+2),*(unsigned short*)($cp_from+4),*(unsigned short*)($cp_from+6),*(unsigned short*)($cp_to+0),*(unsigned short*)($cp_to+2),*(unsigned short*)($cp_to+4),*(unsigned short*)($cp_to+6),$mac_regs[0],$mac_regs[1],$mac_regs[2],$mac_regs[3],$mac_regs[4],$mac_regs[5],$mac_regs[6],$mac_regs[7],$mac_regs[8],$mac_regs[9],$mac_regs[10],$mac_regs[11],$mac_regs[12],$mac_regs[13],$mac_regs[14]
dump binary memory ../tmp/stepcopy-native-enter-src-pm.bin $cp_src $cp_src+50
dump binary memory ../tmp/stepcopy-native-enter-dst-pm.bin $cp_dst $cp_dst+50
dump binary memory ../tmp/stepcopy-native-enter-src-pixels.bin $cp_spx $cp_spx+$cp_ss
dump binary memory ../tmp/stepcopy-native-enter-dst-pixels.bin $cp_dpx $cp_dpx+$cp_ds
dump binary memory ../tmp/stepcopy-native-enter-src-clut.bin $cp_sct $cp_sct+2056
dump binary memory ../tmp/stepcopy-native-enter-dst-clut.bin $cp_dct $cp_dct+2056
dump binary memory ../tmp/stepcopy-native-enter-port.bin $cp_port $cp_port+108
dump binary memory ../tmp/stepcopy-native-enter-vis.bin $cp_vis $cp_vis+10
dump binary memory ../tmp/stepcopy-native-enter-clip.bin $cp_clip $cp_clip+10
dump binary memory ../tmp/stepcopy-native-enter-inverse.bin (char*)s_mainDeviceITable (char*)s_mainDeviceITable+4620
tbreak *$cp_ret
continue
if $pc!=$cp_ret
 echo FAIL CopyBits return\n
 detach
 quit 1
end
printf "STEPCOPY_RETURN sp=%X source=%04X%04X%04X%04X target=%04X%04X%04X%04X d0=%08X d1=%08X d2=%08X d3=%08X d4=%08X d5=%08X d6=%08X d7=%08X a0=%08X a1=%08X a2=%08X a3=%08X a4=%08X a5=%08X a6=%08X\n",$sp,*(unsigned short*)($cp_from+0),*(unsigned short*)($cp_from+2),*(unsigned short*)($cp_from+4),*(unsigned short*)($cp_from+6),*(unsigned short*)($cp_to+0),*(unsigned short*)($cp_to+2),*(unsigned short*)($cp_to+4),*(unsigned short*)($cp_to+6),$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
dump binary memory ../tmp/stepcopy-native-return-src-pm.bin $cp_src $cp_src+50
dump binary memory ../tmp/stepcopy-native-return-dst-pm.bin $cp_dst $cp_dst+50
dump binary memory ../tmp/stepcopy-native-return-src-pixels.bin $cp_spx $cp_spx+$cp_ss
dump binary memory ../tmp/stepcopy-native-return-dst-pixels.bin $cp_dpx $cp_dpx+$cp_ds
dump binary memory ../tmp/stepcopy-native-return-src-clut.bin $cp_sct $cp_sct+2056
dump binary memory ../tmp/stepcopy-native-return-dst-clut.bin $cp_dct $cp_dct+2056
dump binary memory ../tmp/stepcopy-native-return-port.bin $cp_port $cp_port+108
dump binary memory ../tmp/stepcopy-native-return-vis.bin $cp_vis $cp_vis+10
dump binary memory ../tmp/stepcopy-native-return-clip.bin $cp_clip $cp_clip+10
echo PASS native step CopyBits\n
dump binary memory ../tmp/stepcopy-native-return-inverse.bin (char*)s_mainDeviceITable (char*)s_mainDeviceITable+4620
printf "STEPCOPY_PUBLICATION queued=%u/%u presented=%u/%u\n",$pc_queued,g_macFramesQueued,$pc_presented,g_macFramesPresented
printf "STEPCOPY_DIRTY dirty=%u/%u rectangles=%u/%u\n",$pc_dirty,s_pixelsDirty,$pc_rects,s_dirtyRectCount
