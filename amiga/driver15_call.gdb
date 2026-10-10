set $d15_sp=$sp
set $d15_before=g_macTicks
set $d15_origin=g_soundDriver.clockOrigin
dump binary memory ../tmp/driver15-native-enter-state.bin (char*)&g_soundDriver (char*)&g_soundDriver+sizeof(g_soundDriver)
if *(unsigned long*)(g_code3Base+0xfbe)!=0x42a74878 || *(unsigned long*)(g_code3Base+0xfc2)!=0x000f206d || *(unsigned long*)(g_code3Base+0xfc6)!=0xf9544e90 || *(unsigned short*)(g_code3Base+0xfca)!=0x508f
 echo FAIL driver15 original caller bytes\n
 detach
 quit 1
end
if *(unsigned long*)$sp!=15 || *(unsigned long*)($sp+4)!=0
 echo FAIL driver15 original request\n
 detach
 quit 1
end
echo DRIVER15_NATIVE_BYTES 42A74878000F206DF9544E90508F\n
set $d15_d2=$d2
set $d15_d3=$d3
set $d15_d4=$d4
set $d15_d5=$d5
set $d15_d6=$d6
set $d15_d7=$d7
set $d15_a0=$a0
set $d15_a1=$a1
set $d15_a2=$a2
set $d15_a3=$a3
set $d15_a4=$a4
set $d15_a5=$a5
set $d15_a6=$a6
# The return trampoline may run queued original VBL callbacks. Bracket the
# query dispatcher itself so song progression cannot masquerade as a mutation.
tbreak dispatchMacTrap if trap==0xa0f8 && !inUserService && *(unsigned long*)(userStack+4)==15
continue
mac-trap-args
if trap!=0xa0f8 || inUserService || *(unsigned long*)($mac_stack+4)!=15
 echo FAIL driver15 query boundary\n
 detach
 quit 1
end
dump binary memory ../tmp/driver15-native-query-enter-state.bin (char*)&g_soundDriver (char*)&g_soundDriver+sizeof(g_soundDriver)
finish
dump binary memory ../tmp/driver15-native-query-return-state.bin (char*)&g_soundDriver (char*)&g_soundDriver+sizeof(g_soundDriver)
echo DRIVER15_QUERY_BOUNDARY dispatcher-return-before-callbacks\n
tbreak *(g_code3Base+0xfca) if $sp==$d15_sp
continue
if $pc!=(unsigned long)(g_code3Base+0xfca) || $sp!=$d15_sp || $d1!=0
 echo FAIL driver15 native return\n
 detach
 quit 1
end
if $d2!=$d15_d2
 echo FAIL driver15 preserved d2\n
 detach
 quit 1
end
if $d3!=$d15_d3
 echo FAIL driver15 preserved d3\n
 detach
 quit 1
end
if $d4!=$d15_d4
 echo FAIL driver15 preserved d4\n
 detach
 quit 1
end
if $d5!=$d15_d5
 echo FAIL driver15 preserved d5\n
 detach
 quit 1
end
if $d6!=$d15_d6
 echo FAIL driver15 preserved d6\n
 detach
 quit 1
end
if $d7!=$d15_d7
 echo FAIL driver15 preserved d7\n
 detach
 quit 1
end
if $a0!=$d15_a0
 echo FAIL driver15 preserved a0\n
 detach
 quit 1
end
if $a1!=$d15_a1
 echo FAIL driver15 preserved a1\n
 detach
 quit 1
end
if $a2!=$d15_a2
 echo FAIL driver15 preserved a2\n
 detach
 quit 1
end
if $a3!=$d15_a3
 echo FAIL driver15 preserved a3\n
 detach
 quit 1
end
if $a4!=$d15_a4
 echo FAIL driver15 preserved a4\n
 detach
 quit 1
end
if $a5!=$d15_a5
 echo FAIL driver15 preserved a5\n
 detach
 quit 1
end
if $a6!=$d15_a6
 echo FAIL driver15 preserved a6\n
 detach
 quit 1
end
set $d15_after=g_macTicks
set $d15_low=(unsigned int)($d15_before-$d15_origin)
set $d15_high=(unsigned int)($d15_after-$d15_origin)
if (unsigned int)($d0-$d15_low)>(unsigned int)($d15_high-$d15_low) || $d15_low==0
 echo FAIL driver15 live clock result\n
 detach
 quit 1
end
dump binary memory ../tmp/driver15-native-return-state.bin (char*)&g_soundDriver (char*)&g_soundDriver+sizeof(g_soundDriver)
printf "DRIVER15_NATIVE_RETURN before=%X after=%X origin=%X result=%X\n",$d15_before,$d15_after,$d15_origin,$d0
echo PASS native driver15 clock ABI\n
