set $pw_args=(unsigned long)userStack
set $pw_ret=*(unsigned long*)(frame+2)+2
set $pw_rect=*(unsigned long*)$pw_args
set $pw_port=*(unsigned long*)s_qdThePort
set $pw_pm=*(unsigned long*)(*(unsigned long*)($pw_port+2))
set $pw_vis=*(unsigned long*)(*(unsigned long*)($pw_port+24))
set $pw_clip=*(unsigned long*)(*(unsigned long*)($pw_port+28))
set $pw_pixels=*(unsigned long*)$pw_pm
set $pw_size=(*(unsigned short*)($pw_pm+4)&0x3fff)*(*(short*)($pw_pm+10)-*(short*)($pw_pm+6))
set $pw_clut=*(unsigned long*)*(unsigned long*)($pw_pm+42)
printf "PW_LAYOUT port=%X pixels=%X bytes=%u fore=%u mode=%u rect=%04X%04X%04X%04X\n",$pw_port,$pw_pixels,$pw_size,*(unsigned long*)($pw_port+80),*(unsigned short*)($pw_port+56),*(unsigned short*)$pw_rect,*(unsigned short*)($pw_rect+2),*(unsigned short*)($pw_rect+4),*(unsigned short*)($pw_rect+6)
if $pw_ret!=(unsigned long)s_segments[5].begin+0x1e46
 echo FAIL offscreen PaintRect caller\n
 detach
 quit 1
end
printf "PW_NATIVE_BYTES %04X%04X%04X\n",*(unsigned short*)($pw_ret-6),*(unsigned short*)($pw_ret-4),*(unsigned short*)($pw_ret-2)
set $pw_reg0=regs[0]
set $pw_reg1=regs[1]
set $pw_reg2=regs[2]
set $pw_reg3=regs[3]
set $pw_reg4=regs[4]
set $pw_reg5=regs[5]
set $pw_reg6=regs[6]
set $pw_reg7=regs[7]
set $pw_reg8=regs[8]
set $pw_reg9=regs[9]
set $pw_reg10=regs[10]
set $pw_reg11=regs[11]
set $pw_reg12=regs[12]
set $pw_reg13=regs[13]
set $pw_reg14=regs[14]
dump binary memory ../tmp/paintworld-native-enter-port.bin (char*)($pw_port) (char*)($pw_port)+108
dump binary memory ../tmp/paintworld-native-enter-pm.bin (char*)($pw_pm) (char*)($pw_pm)+50
dump binary memory ../tmp/paintworld-native-enter-rect.bin (char*)($pw_rect-4) (char*)($pw_rect-4)+16
dump binary memory ../tmp/paintworld-native-enter-vis.bin (char*)($pw_vis) (char*)($pw_vis)+10
dump binary memory ../tmp/paintworld-native-enter-clip.bin (char*)($pw_clip) (char*)($pw_clip)+10
dump binary memory ../tmp/paintworld-native-enter-pixels.bin $pw_pixels $pw_pixels+$pw_size
dump binary memory ../tmp/paintworld-native-enter-clut.bin $pw_clut $pw_clut+2056
tbreak *$pw_ret
continue
if $pc!=$pw_ret || $sp!=$pw_args+4 || $d0!=0 || $d1!=(($pw_reg1&0xffff0000)|8) || $a1!=$pw_port
 echo FAIL offscreen PaintRect return\n
 detach
 quit 1
end
if $d3!=$pw_reg3
 echo FAIL offscreen PaintRect preserved register\n
 detach
 quit 1
end
if $d4!=$pw_reg4
 echo FAIL offscreen PaintRect preserved register\n
 detach
 quit 1
end
if $d5!=$pw_reg5
 echo FAIL offscreen PaintRect preserved register\n
 detach
 quit 1
end
if $d6!=$pw_reg6
 echo FAIL offscreen PaintRect preserved register\n
 detach
 quit 1
end
if $d7!=$pw_reg7
 echo FAIL offscreen PaintRect preserved register\n
 detach
 quit 1
end
if $a2!=$pw_reg10
 echo FAIL offscreen PaintRect preserved register\n
 detach
 quit 1
end
if $a3!=$pw_reg11
 echo FAIL offscreen PaintRect preserved register\n
 detach
 quit 1
end
if $a4!=$pw_reg12
 echo FAIL offscreen PaintRect preserved register\n
 detach
 quit 1
end
if $a5!=$pw_reg13
 echo FAIL offscreen PaintRect preserved register\n
 detach
 quit 1
end
if $a6!=$pw_reg14
 echo FAIL offscreen PaintRect preserved register\n
 detach
 quit 1
end
dump binary memory ../tmp/paintworld-native-return-port.bin (char*)($pw_port) (char*)($pw_port)+108
dump binary memory ../tmp/paintworld-native-return-pm.bin (char*)($pw_pm) (char*)($pw_pm)+50
dump binary memory ../tmp/paintworld-native-return-rect.bin (char*)($pw_rect-4) (char*)($pw_rect-4)+16
dump binary memory ../tmp/paintworld-native-return-vis.bin (char*)($pw_vis) (char*)($pw_vis)+10
dump binary memory ../tmp/paintworld-native-return-clip.bin (char*)($pw_clip) (char*)($pw_clip)+10
dump binary memory ../tmp/paintworld-native-return-pixels.bin $pw_pixels $pw_pixels+$pw_size
dump binary memory ../tmp/paintworld-native-return-clut.bin $pw_clut $pw_clut+2056
echo PASS native original offscreen PaintRect stack/register contract\n
