set $ev_n=$ev_n+1
mac-trap-args
set $ev_args=(unsigned long)$mac_stack
set $ev_ptr=*(unsigned long*)($ev_args+8)
set $ev_ret=*(unsigned long*)($mac_frame+2)+2
if $ev_ret!=(unsigned long)s_segments[7].begin+0x44f2
 echo FAIL event original caller\n
 detach
 quit 1
end
if $ev_n==1
 printf "WNE_BYTES %08X%08X%08X%08X\n",*(unsigned long*)($ev_ret-16),*(unsigned long*)($ev_ret-12),*(unsigned long*)($ev_ret-8),*(unsigned long*)($ev_ret-4)
end
mac-trap-args
printf "WNE_ENTER n=%u args=%X stack=%08X%08X%08X%08X event=%X record=%08X%08X%08X%08X ticks=%X D0=%08X D1=%08X D2=%08X D3=%08X D4=%08X D5=%08X D6=%08X D7=%08X A0=%08X A1=%08X A2=%08X A3=%08X A4=%08X A5=%08X A6=%08X A7=%08X\n",$ev_n,$ev_args,*(unsigned long*)($ev_args+0),*(unsigned long*)($ev_args+4),*(unsigned long*)($ev_args+8),*(unsigned long*)($ev_args+12),$ev_ptr,*(unsigned long*)($ev_ptr+0),*(unsigned long*)($ev_ptr+4),*(unsigned long*)($ev_ptr+8),*(unsigned long*)($ev_ptr+12),g_macTicks,$mac_regs[0],$mac_regs[1],$mac_regs[2],$mac_regs[3],$mac_regs[4],$mac_regs[5],$mac_regs[6],$mac_regs[7],$mac_regs[8],$mac_regs[9],$mac_regs[10],$mac_regs[11],$mac_regs[12],$mac_regs[13],$mac_regs[14],$ev_args
printf "WNE_GUARD phase=ENTER n=%u data=%08X%08X%08X%08X%08X%08X\n",$ev_n,*(unsigned long*)($ev_ptr-4),*(unsigned long*)($ev_ptr+0),*(unsigned long*)($ev_ptr+4),*(unsigned long*)($ev_ptr+8),*(unsigned long*)($ev_ptr+12),*(unsigned long*)($ev_ptr+16)
printf "WNE_STATE n=%u mouse=%d/%d front=%X behind=%X\n",$ev_n,s_mouseX,s_mouseY,s_windowList,*(unsigned long*)(s_windowList+144)
tbreak *$ev_ret
continue
if $pc!=$ev_ret
 echo FAIL event original return\n
 detach
 quit 1
end
printf "WNE_RETURN n=%u args=%X stack=%08X%08X%08X%08X event=%X record=%08X%08X%08X%08X ticks=%X D0=%08X D1=%08X D2=%08X D3=%08X D4=%08X D5=%08X D6=%08X D7=%08X A0=%08X A1=%08X A2=%08X A3=%08X A4=%08X A5=%08X A6=%08X A7=%08X\n",$ev_n,$ev_args,*(unsigned long*)($ev_args+0),*(unsigned long*)($ev_args+4),*(unsigned long*)($ev_args+8),*(unsigned long*)($ev_args+12),$ev_ptr,*(unsigned long*)($ev_ptr+0),*(unsigned long*)($ev_ptr+4),*(unsigned long*)($ev_ptr+8),*(unsigned long*)($ev_ptr+12),g_macTicks,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6,$sp
printf "WNE_GUARD phase=RETURN n=%u data=%08X%08X%08X%08X%08X%08X\n",$ev_n,*(unsigned long*)($ev_ptr-4),*(unsigned long*)($ev_ptr+0),*(unsigned long*)($ev_ptr+4),*(unsigned long*)($ev_ptr+8),*(unsigned long*)($ev_ptr+12),*(unsigned long*)($ev_ptr+16)
