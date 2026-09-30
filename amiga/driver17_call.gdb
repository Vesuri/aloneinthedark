set $d17_sp=(unsigned long)userStack
set $d17_return=*(unsigned long*)$d17_sp
set $d17_ignored=*(unsigned long*)($d17_sp+8)
printf "DRIVER17_NATIVE_CALL selector=%X ignored=%X sp=%X return=%X\n",*(unsigned long*)($d17_sp+4),$d17_ignored,$d17_sp,$d17_return
set $d17_packet=$d17_ignored
set $d17_sample=*(unsigned long*)$d17_packet
set $d17_size=*(unsigned long*)($d17_packet+4)
eval "dump binary memory ../tmp/driver17-native-packet.bin %u %u",$d17_packet,$d17_packet+26
eval "dump binary memory ../tmp/driver17-native-sample.bin %u %u",$d17_sample,$d17_sample+$d17_size
set $d17_reg2=regs[2]
set $d17_reg3=regs[3]
set $d17_reg4=regs[4]
set $d17_reg5=regs[5]
set $d17_reg6=regs[6]
set $d17_reg7=regs[7]
set $d17_reg8=regs[8]
set $d17_reg9=regs[9]
set $d17_reg10=regs[10]
set $d17_reg11=regs[11]
set $d17_reg12=regs[12]
set $d17_reg13=regs[13]
set $d17_reg14=regs[14]
tbreak *((unsigned long)*g_soundDriverHandle+2)
continue
printf "DRIVER17_STUB pc=%X sp=%X d0=%X d1=%X expected=%X returnword=%X\n",$pc,$sp,$d0,$d1,$d17_return,*(unsigned short*)$d17_return
if $pc!=(unsigned long)*g_soundDriverHandle+2
 echo FAIL driver17 stub return checkpoint\n
 detach
 quit 1
end
stepi
if $pc!=$d17_return || $sp!=$d17_sp+4 || $d0!=0 || $d1!=(($d17_ignored&0xffff0000)|0x7fff)
 echo FAIL driver17 return\n
 detach
 quit 1
end
if $d2!=$d17_reg2
 echo FAIL driver17 preserved register\n
 detach
 quit 1
end
if $d3!=$d17_reg3
 echo FAIL driver17 preserved register\n
 detach
 quit 1
end
if $d4!=$d17_reg4
 echo FAIL driver17 preserved register\n
 detach
 quit 1
end
if $d5!=$d17_reg5
 echo FAIL driver17 preserved register\n
 detach
 quit 1
end
if $d6!=$d17_reg6
 echo FAIL driver17 preserved register\n
 detach
 quit 1
end
if $d7!=$d17_reg7
 echo FAIL driver17 preserved register\n
 detach
 quit 1
end
if $a0!=$d17_reg8
 echo FAIL driver17 preserved register\n
 detach
 quit 1
end
if $a1!=$d17_reg9
 echo FAIL driver17 preserved register\n
 detach
 quit 1
end
if $a2!=$d17_reg10
 echo FAIL driver17 preserved register\n
 detach
 quit 1
end
if $a3!=$d17_reg11
 echo FAIL driver17 preserved register\n
 detach
 quit 1
end
if $a4!=$d17_reg12
 echo FAIL driver17 preserved register\n
 detach
 quit 1
end
if $a5!=$d17_reg13
 echo FAIL driver17 preserved register\n
 detach
 quit 1
end
if $a6!=$d17_reg14
 echo FAIL driver17 preserved register\n
 detach
 quit 1
end
set $d17_chip=(unsigned long)g_effects[0].chip
eval "dump binary memory ../tmp/driver17-native-chip.bin %u %u",$d17_chip,$d17_chip+g_effects[0].allocated
printf "DRIVER17_NATIVE_RETURN calls=%u starts=%u stops=%u size=%u rate=%X period=%u duration=%u id=%X active=%u channel=%d chip=%X allocated=%u\n",g_soundDriverCalls,g_effectStarts,g_effectStops,g_effects[0].size,g_effects[0].rate,g_effects[0].period,g_effects[0].ends-g_effects[0].started-1,g_effects[0].id,g_soundDriver.effects[0].active,g_soundDriver.effects[0].channel,$d17_chip,g_effects[0].allocated
if g_soundDriverCalls!=4 || g_effectStarts!=1 || g_effectStops!=0 || g_effects[0].size!=$d17_size || g_soundDriver.effects[0].active!=1 || g_soundDriver.effects[0].channel!=0
 echo FAIL driver17 native playback state\n
 detach
 quit 1
end
echo PASS native driver17 play-effect ABI and publication\n
if (*(unsigned short*)0xdff002&1)==0
 echo FAIL driver17 Paula DMA inactive\n
 detach
 quit 1
end
printf "DRIVER17_DMA started=%X\n",*(unsigned short*)0xdff002
