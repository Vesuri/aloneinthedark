set $dt_args=(unsigned long)userStack
set $dt_ret=*(unsigned long*)(frame+2)+2
set $dt_port=*(unsigned long*)s_qdThePort
set $dt_pm=*(unsigned long*)(*(unsigned long*)($dt_port+2))
set $dt_vis=*(unsigned long*)(*(unsigned long*)($dt_port+24))
set $dt_clip=*(unsigned long*)(*(unsigned long*)($dt_port+28))
set $dt_pixels=*(unsigned long*)$dt_pm
set $dt_size=(*(unsigned short*)($dt_pm+4)&0x3fff)*(*(short*)($dt_pm+10)-*(short*)($dt_pm+6))
set $dt_clut=*(unsigned long*)*(unsigned long*)($dt_pm+42)
if $dt_ret!=(unsigned long)s_segments[12].begin+0x348
 echo FAIL DrawText caller\n
 detach
 quit 1
end
printf "DT_NATIVE_BYTES %04X%04X%04X\n",*(unsigned short*)($dt_ret-6),*(unsigned short*)($dt_ret-4),*(unsigned short*)($dt_ret-2)
set $dt_count=*(short*)$dt_args
set $dt_first=*(short*)($dt_args+2)
set $dt_text=*(unsigned long*)($dt_args+4)+$dt_first
printf "DT_ARGUMENTS count=%u first=%u\n",$dt_count,$dt_first
dump binary memory ../tmp/drawtext-native-string.bin $dt_text $dt_text+$dt_count
set $dt_reg0=regs[0]
set $dt_reg1=regs[1]
set $dt_reg2=regs[2]
set $dt_reg3=regs[3]
set $dt_reg4=regs[4]
set $dt_reg5=regs[5]
set $dt_reg6=regs[6]
set $dt_reg7=regs[7]
set $dt_reg8=regs[8]
set $dt_reg9=regs[9]
set $dt_reg10=regs[10]
set $dt_reg11=regs[11]
set $dt_reg12=regs[12]
set $dt_reg13=regs[13]
set $dt_reg14=regs[14]
dump binary memory ../tmp/drawtext-native-enter-port.bin (char*)($dt_port) (char*)($dt_port)+108
dump binary memory ../tmp/drawtext-native-enter-pm.bin (char*)($dt_pm) (char*)($dt_pm)+50
dump binary memory ../tmp/drawtext-native-enter-vis.bin (char*)($dt_vis) (char*)($dt_vis)+10
dump binary memory ../tmp/drawtext-native-enter-clip.bin (char*)($dt_clip) (char*)($dt_clip)+10
dump binary memory ../tmp/drawtext-native-enter-pixels.bin $dt_pixels $dt_pixels+$dt_size
dump binary memory ../tmp/drawtext-native-enter-clut.bin $dt_clut $dt_clut+2056
tbreak *$dt_ret
continue
if $pc!=$dt_ret || $sp!=$dt_args+8 || $d0!=0
 echo FAIL DrawText return\n
 detach
 quit 1
end
if $d1!=$dt_reg1
 echo FAIL DrawText preserved d1\n
 detach
 quit 1
end
if $d2!=$dt_reg2
 echo FAIL DrawText preserved d2\n
 detach
 quit 1
end
if $a1!=$dt_reg9
 echo FAIL DrawText preserved a1\n
 detach
 quit 1
end
if $d3!=$dt_reg3
 echo FAIL DrawText preserved register\n
 detach
 quit 1
end
if $d4!=$dt_reg4
 echo FAIL DrawText preserved register\n
 detach
 quit 1
end
if $d5!=$dt_reg5
 echo FAIL DrawText preserved register\n
 detach
 quit 1
end
if $d6!=$dt_reg6
 echo FAIL DrawText preserved register\n
 detach
 quit 1
end
if $d7!=$dt_reg7
 echo FAIL DrawText preserved register\n
 detach
 quit 1
end
if $a2!=$dt_reg10
 echo FAIL DrawText preserved register\n
 detach
 quit 1
end
if $a3!=$dt_reg11
 echo FAIL DrawText preserved register\n
 detach
 quit 1
end
if $a4!=$dt_reg12
 echo FAIL DrawText preserved register\n
 detach
 quit 1
end
if $a5!=$dt_reg13
 echo FAIL DrawText preserved register\n
 detach
 quit 1
end
if $a6!=$dt_reg14
 echo FAIL DrawText preserved register\n
 detach
 quit 1
end
dump binary memory ../tmp/drawtext-native-return-port.bin (char*)($dt_port) (char*)($dt_port)+108
dump binary memory ../tmp/drawtext-native-return-pm.bin (char*)($dt_pm) (char*)($dt_pm)+50
dump binary memory ../tmp/drawtext-native-return-vis.bin (char*)($dt_vis) (char*)($dt_vis)+10
dump binary memory ../tmp/drawtext-native-return-clip.bin (char*)($dt_clip) (char*)($dt_clip)+10
dump binary memory ../tmp/drawtext-native-return-pixels.bin $dt_pixels $dt_pixels+$dt_size
dump binary memory ../tmp/drawtext-native-return-clut.bin $dt_clut $dt_clut+2056
echo PASS native original DrawText stack/register contract\n
