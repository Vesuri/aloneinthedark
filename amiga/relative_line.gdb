set pagination off
set confirm off
set width 0
break AitdScreen::showLoudStop
tbreak dispatchMacTrap if trap==0xa8ec
continue
set $call=(unsigned long)s_segments[6].begin+0x354a
if *(unsigned long*)($call-6)!=0x2f3c0001 || *(unsigned long*)($call-2)!=0x0001a892
 echo FAIL relative Line caller bytes\n
 detach
 quit 1
end
tbreak *$call
continue
if $pc!=$call
 echo FAIL relative Line caller not reached\n
 detach
 quit 1
end
tbreak dispatchMacTrap
continue
if trap!=0xa892 || g_stageBState==3
 echo FAIL relative Line dispatch\n
 detach
 quit 1
end
set $line_args=(unsigned long)userStack
set $line_ret=*(unsigned long*)(frame+2)+2
set $line_port=*(unsigned long*)s_qdThePort
set $line_pm=*(unsigned long*)*(unsigned long*)($line_port+2)
set $line_pixels=*(unsigned long*)$line_pm
set $line_size=(*(unsigned short*)($line_pm+4)&0x3fff)*(*(short*)($line_pm+10)-*(short*)($line_pm+6))
set $line_clut=*(unsigned long*)*(unsigned long*)($line_pm+42)
set $line_vis=*(unsigned long*)*(unsigned long*)($line_port+24)
set $line_clip=*(unsigned long*)*(unsigned long*)($line_port+28)
set $line_target=*(unsigned long*)$line_args
printf "LINE_NATIVE_ENTER sp=%X target=%08X port=%X pm=%X pixels=%X bytes=%u\n",$line_args,$line_target,$line_port,$line_pm,$line_pixels,$line_size
if $line_ret!=(unsigned long)s_segments[6].begin+0x354c || *(unsigned long*)($line_ret-8)!=0x2f3c0001 || *(unsigned long*)($line_ret-4)!=0x0001a892
 echo FAIL native relative Line original caller bytes\n
 detach
 quit 1
end
set $line_target=(((unsigned short)(*(unsigned short*)($line_port+48)+*(unsigned short*)$line_args))<<16)|(unsigned short)(*(unsigned short*)($line_port+50)+*(unsigned short*)($line_args+2))
set $line_reg1=regs[1]
set $line_reg2=regs[2]
set $line_reg3=regs[3]
set $line_reg4=regs[4]
set $line_reg5=regs[5]
set $line_reg6=regs[6]
set $line_reg7=regs[7]
set $line_reg8=regs[8]
set $line_reg9=regs[9]
set $line_reg10=regs[10]
set $line_reg11=regs[11]
set $line_reg12=regs[12]
set $line_reg13=regs[13]
set $line_reg14=regs[14]
dump binary memory ../tmp/relative-line-native-enter-port.bin (char*)$line_port (char*)$line_port+108
dump binary memory ../tmp/relative-line-native-enter-pm.bin (char*)$line_pm (char*)$line_pm+50
dump binary memory ../tmp/relative-line-native-enter-pixels.bin (char*)$line_pixels (char*)$line_pixels+$line_size
dump binary memory ../tmp/relative-line-native-enter-clut.bin (char*)$line_clut (char*)$line_clut+2056
dump binary memory ../tmp/relative-line-native-enter-vis.bin (char*)$line_vis (char*)$line_vis+10
dump binary memory ../tmp/relative-line-native-enter-clip.bin (char*)$line_clip (char*)$line_clip+10
tbreak *$line_ret
continue
if $pc!=$line_ret || $sp!=$line_args+4 || $d0!=0 || *(unsigned long*)($line_port+48)!=$line_target
 echo FAIL native relative Line return\n
 detach
 quit 1
end
if $d1!=$line_reg1
 echo FAIL native relative Line preserved d1\n
 detach
 quit 1
end
if $d2!=$line_reg2
 echo FAIL native relative Line preserved d2\n
 detach
 quit 1
end
if $d3!=$line_reg3
 echo FAIL native relative Line preserved d3\n
 detach
 quit 1
end
if $d4!=$line_reg4
 echo FAIL native relative Line preserved d4\n
 detach
 quit 1
end
if $d5!=$line_reg5
 echo FAIL native relative Line preserved d5\n
 detach
 quit 1
end
if $d6!=$line_reg6
 echo FAIL native relative Line preserved d6\n
 detach
 quit 1
end
if $d7!=$line_reg7
 echo FAIL native relative Line preserved d7\n
 detach
 quit 1
end
if $a1!=$line_reg9
 echo FAIL native relative Line preserved a1\n
 detach
 quit 1
end
if $a2!=$line_reg10
 echo FAIL native relative Line preserved a2\n
 detach
 quit 1
end
if $a3!=$line_reg11
 echo FAIL native relative Line preserved a3\n
 detach
 quit 1
end
if $a4!=$line_reg12
 echo FAIL native relative Line preserved a4\n
 detach
 quit 1
end
if $a5!=$line_reg13
 echo FAIL native relative Line preserved a5\n
 detach
 quit 1
end
if $a6!=$line_reg14
 echo FAIL native relative Line preserved a6\n
 detach
 quit 1
end
dump binary memory ../tmp/relative-line-native-return-port.bin (char*)$line_port (char*)$line_port+108
dump binary memory ../tmp/relative-line-native-return-pm.bin (char*)$line_pm (char*)$line_pm+50
dump binary memory ../tmp/relative-line-native-return-pixels.bin (char*)$line_pixels (char*)$line_pixels+$line_size
dump binary memory ../tmp/relative-line-native-return-clut.bin (char*)$line_clut (char*)$line_clut+2056
dump binary memory ../tmp/relative-line-native-return-vis.bin (char*)$line_vis (char*)$line_vis+10
dump binary memory ../tmp/relative-line-native-return-clip.bin (char*)$line_clip (char*)$line_clip+10
echo PASS native original relative Line caller stack registers and pen position\n
# Advance through the original register restore and frame unlink.
tbreak *($line_ret+6)
continue
if $pc!=$line_ret+6 || g_stageBState==3 || g_introSkipState!=2 || g_macBookFramesCompleted!=0
 echo FAIL relative Line continuation or intro skip\n
 detach
 quit 1
end
echo PASS native relative Line continuation book=0\n
detach
quit 0
