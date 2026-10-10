mac-trap-args
set $d22_sp=(unsigned long)$mac_stack
set $d22_return=*(unsigned long*)$d22_sp
set $d22_ignored=*(unsigned long*)($d22_sp+8)
printf "DRIVER22_NATIVE_CALL selector=%X ignored=%X sp=%X return=%X\n",*(unsigned long*)($d22_sp+4),$d22_ignored,$d22_sp,$d22_return
printf "DRIVER22_NATIVE_BYTES %04X%04X%04X%04X%04X%04X\n",*(unsigned short*)(g_code3Base+0x1a6c),*(unsigned short*)(g_code3Base+0x1a6e),*(unsigned short*)(g_code3Base+0x1a70),*(unsigned short*)(g_code3Base+0x1a72),*(unsigned short*)(g_code3Base+0x1a74),*(unsigned short*)(g_code3Base+0x1a76)
dump binary memory ../tmp/driver22-native-enter-state.bin (char*)&g_soundDriver (char*)&g_soundDriver+sizeof(g_soundDriver)
set $d22_reg2=$mac_regs[2]
set $d22_reg3=$mac_regs[3]
set $d22_reg4=$mac_regs[4]
set $d22_reg5=$mac_regs[5]
set $d22_reg6=$mac_regs[6]
set $d22_reg7=$mac_regs[7]
set $d22_reg8=$mac_regs[8]
set $d22_reg9=$mac_regs[9]
set $d22_reg10=$mac_regs[10]
set $d22_reg11=$mac_regs[11]
set $d22_reg12=$mac_regs[12]
set $d22_reg13=$mac_regs[13]
set $d22_reg14=$mac_regs[14]
tbreak *$d22_return
continue
if $pc!=$d22_return || $sp!=$d22_sp+4 || $d0!=0 || $d1!=$d22_ignored
 echo FAIL driver22 return\n
 detach
 quit 1
end
if $d2!=$d22_reg2
 echo FAIL driver22 preserved register\n
 detach
 quit 1
end
if $d3!=$d22_reg3
 echo FAIL driver22 preserved register\n
 detach
 quit 1
end
if $d4!=$d22_reg4
 echo FAIL driver22 preserved register\n
 detach
 quit 1
end
if $d5!=$d22_reg5
 echo FAIL driver22 preserved register\n
 detach
 quit 1
end
if $d6!=$d22_reg6
 echo FAIL driver22 preserved register\n
 detach
 quit 1
end
if $d7!=$d22_reg7
 echo FAIL driver22 preserved register\n
 detach
 quit 1
end
if $a0!=$d22_reg8
 echo FAIL driver22 preserved register\n
 detach
 quit 1
end
if $a1!=$d22_reg9
 echo FAIL driver22 preserved register\n
 detach
 quit 1
end
if $a2!=$d22_reg10
 echo FAIL driver22 preserved register\n
 detach
 quit 1
end
if $a3!=$d22_reg11
 echo FAIL driver22 preserved register\n
 detach
 quit 1
end
if $a4!=$d22_reg12
 echo FAIL driver22 preserved register\n
 detach
 quit 1
end
if $a5!=$d22_reg13
 echo FAIL driver22 preserved register\n
 detach
 quit 1
end
if $a6!=$d22_reg14
 echo FAIL driver22 preserved register\n
 detach
 quit 1
end
dump binary memory ../tmp/driver22-native-return-state.bin (char*)&g_soundDriver (char*)&g_soundDriver+sizeof(g_soundDriver)
printf "DRIVER22_NATIVE_RETURN calls=%u initialized=%u rate=%u interpolation=%u limits=%u/%u/%u effects=%u/%u\n",g_soundDriverCalls,g_soundDriver.initialized,g_soundDriver.requestedRate,g_soundDriver.interpolation,g_soundDriver.songLimit,g_soundDriver.normalizedLimit,g_soundDriver.effectLimit,g_soundDriver.effects[0].active,g_soundDriver.effects[1].active
echo PASS native driver22 stop-effects ABI\n
