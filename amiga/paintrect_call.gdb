mac-trap-args
set $pr_args=(unsigned long)$mac_stack
set $pr_ret=*(unsigned long*)($mac_frame+2)+2
set $pr_rect=*(unsigned long*)$pr_args
set $pr_port=*(unsigned long*)s_qdThePort
set $pr_pm=*(unsigned long*)(*(unsigned long*)($pr_port+2))
set $pr_vis=*(unsigned long*)(*(unsigned long*)($pr_port+24))
set $pr_clip=*(unsigned long*)(*(unsigned long*)($pr_port+28))
if $pr_ret!=(unsigned long)s_segments[13].begin+0xd54
 echo FAIL PaintRect caller\n
 detach
 quit 1
end
printf "PR_NATIVE_BYTES %04X%04X%04X\n",*(unsigned short*)($pr_ret-6),*(unsigned short*)($pr_ret-4),*(unsigned short*)($pr_ret-2)
mac-trap-args
set $pr_reg0=$mac_regs[0]
set $pr_reg1=$mac_regs[1]
set $pr_reg2=$mac_regs[2]
set $pr_reg3=$mac_regs[3]
set $pr_reg4=$mac_regs[4]
set $pr_reg5=$mac_regs[5]
set $pr_reg6=$mac_regs[6]
set $pr_reg7=$mac_regs[7]
set $pr_reg8=$mac_regs[8]
set $pr_reg9=$mac_regs[9]
set $pr_reg10=$mac_regs[10]
set $pr_reg11=$mac_regs[11]
set $pr_reg12=$mac_regs[12]
set $pr_reg13=$mac_regs[13]
set $pr_reg14=$mac_regs[14]
dump binary memory ../tmp/paintrect-native-enter-port.bin (char*)($pr_port) (char*)($pr_port)+108
dump binary memory ../tmp/paintrect-native-enter-pm.bin (char*)($pr_pm) (char*)($pr_pm)+50
dump binary memory ../tmp/paintrect-native-enter-rect.bin (char*)($pr_rect-4) (char*)($pr_rect-4)+16
dump binary memory ../tmp/paintrect-native-enter-vis.bin (char*)($pr_vis) (char*)($pr_vis)+10
dump binary memory ../tmp/paintrect-native-enter-clip.bin (char*)($pr_clip) (char*)($pr_clip)+10
dump binary memory ../tmp/paintrect-native-enter-pixels.bin (char*)(s_colorScreen) (char*)(s_colorScreen)+307200
dump binary memory ../tmp/paintrect-native-enter-clut.bin (char*)(s_windowManagerColors) (char*)(s_windowManagerColors)+2056
tbreak *$pr_ret
continue
if $pc!=$pr_ret || $sp!=$pr_args+4 || $d0!=0 || $d1!=(($pr_reg1&0xffff0000)|8) || $a1!=$pr_port
 echo FAIL PaintRect return\n
 detach
 quit 1
end
if $d3!=$pr_reg3
 echo FAIL PaintRect preserved register\n
 detach
 quit 1
end
if $d4!=$pr_reg4
 echo FAIL PaintRect preserved register\n
 detach
 quit 1
end
if $d5!=$pr_reg5
 echo FAIL PaintRect preserved register\n
 detach
 quit 1
end
if $d6!=$pr_reg6
 echo FAIL PaintRect preserved register\n
 detach
 quit 1
end
if $d7!=$pr_reg7
 echo FAIL PaintRect preserved register\n
 detach
 quit 1
end
if $a2!=$pr_reg10
 echo FAIL PaintRect preserved register\n
 detach
 quit 1
end
if $a3!=$pr_reg11
 echo FAIL PaintRect preserved register\n
 detach
 quit 1
end
if $a4!=$pr_reg12
 echo FAIL PaintRect preserved register\n
 detach
 quit 1
end
if $a5!=$pr_reg13
 echo FAIL PaintRect preserved register\n
 detach
 quit 1
end
if $a6!=$pr_reg14
 echo FAIL PaintRect preserved register\n
 detach
 quit 1
end
dump binary memory ../tmp/paintrect-native-return-port.bin (char*)($pr_port) (char*)($pr_port)+108
dump binary memory ../tmp/paintrect-native-return-pm.bin (char*)($pr_pm) (char*)($pr_pm)+50
dump binary memory ../tmp/paintrect-native-return-rect.bin (char*)($pr_rect-4) (char*)($pr_rect-4)+16
dump binary memory ../tmp/paintrect-native-return-vis.bin (char*)($pr_vis) (char*)($pr_vis)+10
dump binary memory ../tmp/paintrect-native-return-clip.bin (char*)($pr_clip) (char*)($pr_clip)+10
dump binary memory ../tmp/paintrect-native-return-pixels.bin (char*)(s_colorScreen) (char*)(s_colorScreen)+307200
dump binary memory ../tmp/paintrect-native-return-clut.bin (char*)(s_windowManagerColors) (char*)(s_windowManagerColors)+2056
echo PASS native original PaintRect stack/register contract\n
