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
printf "LINE_NATIVE_ENTER sp=%X target=%08X port=%X pm=%X pixels=%X bytes=%u\n",$line_args,$line_target,$line_port,$line_pm,$line_pixels,$line_size
if $line_ret!=(unsigned long)s_segments[6].begin+0x3380 || *(unsigned long*)($line_ret-10)!=0x3f2effc6 || *(unsigned long*)($line_ret-6)!=0x3f2effc4 || *(unsigned short*)($line_ret-2)!=0xa891
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
dump binary memory ../tmp/lineto-native-enter-port.bin (char*)$line_port (char*)$line_port+108
dump binary memory ../tmp/lineto-native-enter-pm.bin (char*)$line_pm (char*)$line_pm+50
dump binary memory ../tmp/lineto-native-enter-pixels.bin (char*)$line_pixels (char*)$line_pixels+$line_size
dump binary memory ../tmp/lineto-native-enter-clut.bin (char*)$line_clut (char*)$line_clut+2056
dump binary memory ../tmp/lineto-native-enter-vis.bin (char*)$line_vis (char*)$line_vis+10
dump binary memory ../tmp/lineto-native-enter-clip.bin (char*)$line_clip (char*)$line_clip+10
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
dump binary memory ../tmp/lineto-native-return-port.bin (char*)$line_port (char*)$line_port+108
dump binary memory ../tmp/lineto-native-return-pm.bin (char*)$line_pm (char*)$line_pm+50
dump binary memory ../tmp/lineto-native-return-pixels.bin (char*)$line_pixels (char*)$line_pixels+$line_size
dump binary memory ../tmp/lineto-native-return-clut.bin (char*)$line_clut (char*)$line_clut+2056
dump binary memory ../tmp/lineto-native-return-vis.bin (char*)$line_vis (char*)$line_vis+10
dump binary memory ../tmp/lineto-native-return-clip.bin (char*)$line_clip (char*)$line_clip+10
echo PASS native original LineTo caller stack registers and pen position\n
