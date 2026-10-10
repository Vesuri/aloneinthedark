mac-trap-args
set $line_args=(unsigned long)$mac_stack
set $line_ret=*(unsigned long*)($mac_frame+2)+2
set $line_port=*(unsigned long*)s_qdThePort
set $line_pm=*(unsigned long*)*(unsigned long*)($line_port+2)
set $line_pixels=*(unsigned long*)$line_pm
set $line_size=(*(unsigned short*)($line_pm+4)&0x3fff)*(*(short*)($line_pm+10)-*(short*)($line_pm+6))
set $line_clut=*(unsigned long*)*(unsigned long*)($line_pm+42)
set $line_vis=*(unsigned long*)*(unsigned long*)($line_port+24)
set $line_clip=*(unsigned long*)*(unsigned long*)($line_port+28)
set $line_target=*(unsigned long*)$line_args
printf "WINDOWLINE_NATIVE_ENTER sp=%X target=%08X port=%X pm=%X pixels=%X bytes=%u\n",$line_args,$line_target,$line_port,$line_pm,$line_pixels,$line_size
if $line_ret!=(unsigned long)s_segments[13].begin+0xb5c || *(unsigned long*)($line_ret-10)!=0x3eae000c || *(unsigned long*)($line_ret-6)!=0x3f2e000e || *(unsigned short*)($line_ret-2)!=0xa891
 echo FAIL native LineTo original caller bytes\n
 detach
 quit 1
end
mac-trap-args
set $line_reg1=$mac_regs[1]
set $line_reg2=$mac_regs[2]
set $line_reg3=$mac_regs[3]
set $line_reg4=$mac_regs[4]
set $line_reg5=$mac_regs[5]
set $line_reg6=$mac_regs[6]
set $line_reg7=$mac_regs[7]
set $line_reg8=$mac_regs[8]
set $line_reg9=$mac_regs[9]
set $line_reg10=$mac_regs[10]
set $line_reg11=$mac_regs[11]
set $line_reg12=$mac_regs[12]
set $line_reg13=$mac_regs[13]
set $line_reg14=$mac_regs[14]
dump binary memory ../tmp/windowline-native-enter-port.bin (char*)$line_port (char*)$line_port+108
dump binary memory ../tmp/windowline-native-enter-pm.bin (char*)$line_pm (char*)$line_pm+50
dump binary memory ../tmp/windowline-native-enter-pixels.bin (char*)$line_pixels (char*)$line_pixels+$line_size
dump binary memory ../tmp/windowline-native-enter-clut.bin (char*)$line_clut (char*)$line_clut+2056
dump binary memory ../tmp/windowline-native-enter-vis.bin (char*)$line_vis (char*)$line_vis+10
dump binary memory ../tmp/windowline-native-enter-clip.bin (char*)$line_clip (char*)$line_clip+10
set $wl_before=g_macFramesQueued
tbreak markDirtyBounds
continue
if top!=150 || left!=420 || bottom!=350 || right!=421
 echo FAIL window LineTo dirty bounds\n
 detach
 quit 1
end
printf "WINDOWLINE_DIRTY top=%d left=%d bottom=%d right=%d\n",top,left,bottom,right
tbreak *$line_ret
continue
if $pc!=$line_ret || $sp!=$line_args+4 || $d0!=0 || *(unsigned long*)($line_port+48)!=$line_target
 echo FAIL native LineTo return\n
 detach
 quit 1
end
if $d1!=$line_reg1
 echo FAIL native LineTo preserved d1\n
 detach
 quit 1
end
if $d2!=$line_reg2
 echo FAIL native LineTo preserved d2\n
 detach
 quit 1
end
if $d3!=$line_reg3
 echo FAIL native LineTo preserved d3\n
 detach
 quit 1
end
if $d4!=$line_reg4
 echo FAIL native LineTo preserved d4\n
 detach
 quit 1
end
if $d5!=$line_reg5
 echo FAIL native LineTo preserved d5\n
 detach
 quit 1
end
if $d6!=$line_reg6
 echo FAIL native LineTo preserved d6\n
 detach
 quit 1
end
if $d7!=$line_reg7
 echo FAIL native LineTo preserved d7\n
 detach
 quit 1
end
if $a1!=$line_reg9
 echo FAIL native LineTo preserved a1\n
 detach
 quit 1
end
if $a2!=$line_reg10
 echo FAIL native LineTo preserved a2\n
 detach
 quit 1
end
if $a3!=$line_reg11
 echo FAIL native LineTo preserved a3\n
 detach
 quit 1
end
if $a4!=$line_reg12
 echo FAIL native LineTo preserved a4\n
 detach
 quit 1
end
if $a5!=$line_reg13
 echo FAIL native LineTo preserved a5\n
 detach
 quit 1
end
if $a6!=$line_reg14
 echo FAIL native LineTo preserved a6\n
 detach
 quit 1
end
dump binary memory ../tmp/windowline-native-return-port.bin (char*)$line_port (char*)$line_port+108
dump binary memory ../tmp/windowline-native-return-pm.bin (char*)$line_pm (char*)$line_pm+50
dump binary memory ../tmp/windowline-native-return-pixels.bin (char*)$line_pixels (char*)$line_pixels+$line_size
dump binary memory ../tmp/windowline-native-return-clut.bin (char*)$line_clut (char*)$line_clut+2056
dump binary memory ../tmp/windowline-native-return-vis.bin (char*)$line_vis (char*)$line_vis+10
dump binary memory ../tmp/windowline-native-return-clip.bin (char*)$line_clip (char*)$line_clip+10
echo PASS native original window LineTo caller stack registers and pen position\n
set $wl_complete=0
while $wl_complete==0
 tbreak AitdScreen::presentMacFrame
 continue
 if g_stageBState==3
  echo FAIL window line publication blocked by next trap\n
  detach
  quit 1
 end
 finish
 if g_macFramesQueued>$wl_before
  set $wl_complete=1
 end
end
set $screen=s_loudStopScreen
set $wl_queued=g_macFramesQueued
set $wl_target=$screen->m_framePending ? $screen->m_back : $screen->m_chip
set $wl_copper=$screen->m_framePending ? $screen->m_nextCopper : $screen->m_copper
dump binary memory ../tmp/aga-windowline-logical.bin s_colorScreen (char*)s_colorScreen+307200
dump binary memory ../tmp/aga-windowline-clut.bin s_windowManagerColors (char*)s_windowManagerColors+2056
dump binary memory ../tmp/aga-windowline-queued-planes.bin $wl_target $wl_target+64000
dump binary memory ../tmp/aga-windowline-queued-copper.bin (char*)$wl_copper (char*)$wl_copper+2248
if g_macFramesPresented<$wl_queued
 tbreak aitdMacMouseVBI if g_macFramesPresented==$wl_queued
 continue
end
if $screen->m_framePending || g_macFramesPresented!=$wl_queued || $screen->m_chip!=$wl_target || $screen->m_copper!=$wl_copper || $screen->m_cropLeft!=160 || $screen->m_cropTop!=150
 echo FAIL window line VBI publication\n
 detach
 quit 1
end
printf "WINDOWLINE_AGA front=%X copper=%X queued=%u presented=%u crop=%u/%u pending=%u line=%u late=%u\n",$screen->m_chip,$screen->m_copper,g_macFramesQueued,g_macFramesPresented,$screen->m_cropLeft,$screen->m_cropTop,$screen->m_framePending,g_beamPresentLine,g_beamPresentsLate
dump binary memory ../tmp/aga-windowline-active-planes.bin $wl_target $wl_target+64000
dump binary memory ../tmp/aga-windowline-active-copper.bin (char*)$wl_copper (char*)$wl_copper+2248
echo PASS native window LineTo AGA publication\n
