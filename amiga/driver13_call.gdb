mac-trap-args
set $d13_sp=(unsigned long)$mac_stack
set $d13_return=*(unsigned long*)$d13_sp
set $d13_argument=*(unsigned long*)($d13_sp+8)
printf "DRIVER13_NATIVE_CALL selector=%X argument=%X sp=%X return=%X\n",*(unsigned long*)($d13_sp+4),$d13_argument,$d13_sp,$d13_return
if *(unsigned long*)(g_code3Base+0x1374)!=0x2f004878 || *(unsigned long*)(g_code3Base+0x1378)!=0x000d206d || *(unsigned long*)(g_code3Base+0x137c)!=0xf9544e90 || *(unsigned short*)(g_code3Base+0x1380)!=0x508f
 echo FAIL driver13 caller bytes\n
 detach
 quit 1
end
echo DRIVER13_NATIVE_BYTES 2F004878000D206DF9544E90508F\n
dump binary memory ../tmp/driver13-native-enter-state.bin (char*)&g_soundDriver (char*)&g_soundDriver+sizeof(g_soundDriver)
mac-trap-args
set $d13_reg2=$mac_regs[2]
set $d13_reg3=$mac_regs[3]
set $d13_reg4=$mac_regs[4]
set $d13_reg5=$mac_regs[5]
set $d13_reg6=$mac_regs[6]
set $d13_reg7=$mac_regs[7]
set $d13_reg8=$mac_regs[8]
set $d13_reg9=$mac_regs[9]
set $d13_reg10=$mac_regs[10]
set $d13_reg11=$mac_regs[11]
set $d13_reg12=$mac_regs[12]
set $d13_reg13=$mac_regs[13]
set $d13_reg14=$mac_regs[14]
tbreak *$d13_return if $sp==$d13_sp+4
continue
if $pc!=$d13_return || $sp!=$d13_sp+4 || $d0!=0 || $d1!=$d13_argument
 echo FAIL driver13 return\n
 detach
 quit 1
end
if $d2!=$d13_reg2
 echo FAIL driver13 preserved register\n
 detach
 quit 1
end
if $d3!=$d13_reg3
 echo FAIL driver13 preserved register\n
 detach
 quit 1
end
if $d4!=$d13_reg4
 echo FAIL driver13 preserved register\n
 detach
 quit 1
end
if $d5!=$d13_reg5
 echo FAIL driver13 preserved register\n
 detach
 quit 1
end
if $d6!=$d13_reg6
 echo FAIL driver13 preserved register\n
 detach
 quit 1
end
if $d7!=$d13_reg7
 echo FAIL driver13 preserved register\n
 detach
 quit 1
end
if $a0!=$d13_reg8
 echo FAIL driver13 preserved register\n
 detach
 quit 1
end
if $a1!=$d13_reg9
 echo FAIL driver13 preserved register\n
 detach
 quit 1
end
if $a2!=$d13_reg10
 echo FAIL driver13 preserved register\n
 detach
 quit 1
end
if $a3!=$d13_reg11
 echo FAIL driver13 preserved register\n
 detach
 quit 1
end
if $a4!=$d13_reg12
 echo FAIL driver13 preserved register\n
 detach
 quit 1
end
if $a5!=$d13_reg13
 echo FAIL driver13 preserved register\n
 detach
 quit 1
end
if $a6!=$d13_reg14
 echo FAIL driver13 preserved register\n
 detach
 quit 1
end
dump binary memory ../tmp/driver13-native-return-state.bin (char*)&g_soundDriver (char*)&g_soundDriver+sizeof(g_soundDriver)
if $d13_argument!=0 || g_soundDriver.songControl!=0
 echo FAIL driver13 argument/state\n
 detach
 quit 1
end
printf "DRIVER13_NATIVE_RETURN argument=%X value=%X calls=%u\n",$d13_argument,g_soundDriver.songControl,g_soundDriverCalls
echo PASS native driver13 parameter ABI\n
