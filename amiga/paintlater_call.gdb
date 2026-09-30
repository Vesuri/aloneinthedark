set $pl_args=(unsigned long)userStack
set $pl_ret=*(unsigned long*)(frame+2)+2
set $pl_rect=*(unsigned long*)$pl_args
set $pl_port=*(unsigned long*)s_qdThePort
set $pl_pm=*(unsigned long*)(*(unsigned long*)($pl_port+2))
set $pl_vis=*(unsigned long*)(*(unsigned long*)($pl_port+24))
set $pl_clip=*(unsigned long*)(*(unsigned long*)($pl_port+28))
set $pl_pixels=*(unsigned long*)$pl_pm
set $pl_size=(*(unsigned short*)($pl_pm+4)&0x3fff)*(*(short*)($pl_pm+10)-*(short*)($pl_pm+6))
set $pl_clut=*(unsigned long*)*(unsigned long*)($pl_pm+42)
printf "PL_LAYOUT port=%X pixels=%X bytes=%u fore=%u mode=%u rect=%04X%04X%04X%04X\n",$pl_port,$pl_pixels,$pl_size,*(unsigned long*)($pl_port+80),*(unsigned short*)($pl_port+56),*(unsigned short*)$pl_rect,*(unsigned short*)($pl_rect+2),*(unsigned short*)($pl_rect+4),*(unsigned short*)($pl_rect+6)
if $pl_ret!=(unsigned long)s_segments[13].begin+0xd54
 echo FAIL later mode-0 PaintRect caller\n
 detach
 quit 1
end
printf "PL_NATIVE_BYTES %04X%04X%04X\n",*(unsigned short*)($pl_ret-6),*(unsigned short*)($pl_ret-4),*(unsigned short*)($pl_ret-2)
set $pl_reg0=regs[0]
set $pl_reg1=regs[1]
set $pl_reg2=regs[2]
set $pl_reg3=regs[3]
set $pl_reg4=regs[4]
set $pl_reg5=regs[5]
set $pl_reg6=regs[6]
set $pl_reg7=regs[7]
set $pl_reg8=regs[8]
set $pl_reg9=regs[9]
set $pl_reg10=regs[10]
set $pl_reg11=regs[11]
set $pl_reg12=regs[12]
set $pl_reg13=regs[13]
set $pl_reg14=regs[14]
dump binary memory ../tmp/paintlater-native-enter-port.bin (char*)($pl_port) (char*)($pl_port)+108
dump binary memory ../tmp/paintlater-native-enter-pm.bin (char*)($pl_pm) (char*)($pl_pm)+50
dump binary memory ../tmp/paintlater-native-enter-rect.bin (char*)($pl_rect-4) (char*)($pl_rect-4)+16
dump binary memory ../tmp/paintlater-native-enter-vis.bin (char*)($pl_vis) (char*)($pl_vis)+10
dump binary memory ../tmp/paintlater-native-enter-clip.bin (char*)($pl_clip) (char*)($pl_clip)+10
dump binary memory ../tmp/paintlater-native-enter-pixels.bin $pl_pixels $pl_pixels+$pl_size
dump binary memory ../tmp/paintlater-native-enter-clut.bin $pl_clut $pl_clut+2056
tbreak *$pl_ret
continue
if $pc!=$pl_ret || $sp!=$pl_args+4 || $d0!=0 || $d1!=(($pl_reg1&0xffff0000)|8) || $a1!=$pl_port
 echo FAIL later mode-0 PaintRect return\n
 detach
 quit 1
end
if $d3!=$pl_reg3
 echo FAIL later mode-0 PaintRect preserved register\n
 detach
 quit 1
end
if $d4!=$pl_reg4
 echo FAIL later mode-0 PaintRect preserved register\n
 detach
 quit 1
end
if $d5!=$pl_reg5
 echo FAIL later mode-0 PaintRect preserved register\n
 detach
 quit 1
end
if $d6!=$pl_reg6
 echo FAIL later mode-0 PaintRect preserved register\n
 detach
 quit 1
end
if $d7!=$pl_reg7
 echo FAIL later mode-0 PaintRect preserved register\n
 detach
 quit 1
end
if $a2!=$pl_reg10
 echo FAIL later mode-0 PaintRect preserved register\n
 detach
 quit 1
end
if $a3!=$pl_reg11
 echo FAIL later mode-0 PaintRect preserved register\n
 detach
 quit 1
end
if $a4!=$pl_reg12
 echo FAIL later mode-0 PaintRect preserved register\n
 detach
 quit 1
end
if $a5!=$pl_reg13
 echo FAIL later mode-0 PaintRect preserved register\n
 detach
 quit 1
end
if $a6!=$pl_reg14
 echo FAIL later mode-0 PaintRect preserved register\n
 detach
 quit 1
end
dump binary memory ../tmp/paintlater-native-return-port.bin (char*)($pl_port) (char*)($pl_port)+108
dump binary memory ../tmp/paintlater-native-return-pm.bin (char*)($pl_pm) (char*)($pl_pm)+50
dump binary memory ../tmp/paintlater-native-return-rect.bin (char*)($pl_rect-4) (char*)($pl_rect-4)+16
dump binary memory ../tmp/paintlater-native-return-vis.bin (char*)($pl_vis) (char*)($pl_vis)+10
dump binary memory ../tmp/paintlater-native-return-clip.bin (char*)($pl_clip) (char*)($pl_clip)+10
dump binary memory ../tmp/paintlater-native-return-pixels.bin $pl_pixels $pl_pixels+$pl_size
dump binary memory ../tmp/paintlater-native-return-clut.bin $pl_clut $pl_clut+2056
echo PASS native original later mode-0 PaintRect stack/register contract\n
