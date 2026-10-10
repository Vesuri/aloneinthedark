mac-trap-args
set $gk_args=(unsigned long)$mac_stack
set $gk_ret=*(unsigned long*)($mac_frame+2)+2
set $gk_dest=*(unsigned long*)$gk_args
set $gk_map=(unsigned long)s_portLowMemory+16
if *(unsigned long*)($gk_ret-6)!=0x486efff0 || *(unsigned short*)($gk_ret-2)!=0xa976
 echo FAIL GetKeys original caller bytes\n
 detach
 quit 1
end
echo GETKEYS_BYTES n=1 data=486EFFF0A976\n
mac-trap-args
printf "GETKEYS_ENTER n=1 sp=%X destination=%X guard=%08X%08X%08X%08X%08X%08X keymap=%08X%08X%08X%08X d0=%08X d1=%08X d2=%08X d3=%08X d4=%08X d5=%08X d6=%08X d7=%08X a0=%08X a1=%08X a2=%08X a3=%08X a4=%08X a5=%08X a6=%08X\n",$gk_args,$gk_dest,*(unsigned long*)($gk_dest+-4),*(unsigned long*)($gk_dest+0),*(unsigned long*)($gk_dest+4),*(unsigned long*)($gk_dest+8),*(unsigned long*)($gk_dest+12),*(unsigned long*)($gk_dest+16),*(unsigned long*)($gk_map+0),*(unsigned long*)($gk_map+4),*(unsigned long*)($gk_map+8),*(unsigned long*)($gk_map+12),$mac_regs[0],$mac_regs[1],$mac_regs[2],$mac_regs[3],$mac_regs[4],$mac_regs[5],$mac_regs[6],$mac_regs[7],$mac_regs[8],$mac_regs[9],$mac_regs[10],$mac_regs[11],$mac_regs[12],$mac_regs[13],$mac_regs[14]
tbreak *$gk_ret if $sp==$gk_args+4
continue
if $pc!=$gk_ret
 echo FAIL GetKeys original return\n
 detach
 quit 1
end
printf "GETKEYS_RETURN n=1 sp=%X destination=%X guard=%08X%08X%08X%08X%08X%08X keymap=%08X%08X%08X%08X d0=%08X d1=%08X d2=%08X d3=%08X d4=%08X d5=%08X d6=%08X d7=%08X a0=%08X a1=%08X a2=%08X a3=%08X a4=%08X a5=%08X a6=%08X\n",$sp,$gk_dest,*(unsigned long*)($gk_dest+-4),*(unsigned long*)($gk_dest+0),*(unsigned long*)($gk_dest+4),*(unsigned long*)($gk_dest+8),*(unsigned long*)($gk_dest+12),*(unsigned long*)($gk_dest+16),*(unsigned long*)($gk_map+0),*(unsigned long*)($gk_map+4),*(unsigned long*)($gk_map+8),*(unsigned long*)($gk_map+12),$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
echo PASS native original GetKeys calls=1\n
