mac-trap-args
set $cur_ret=*(unsigned long*)($mac_frame+2)+2
set $cur_args=(unsigned long)$mac_stack
if $cur_ret!=(unsigned long)s_segments[7].begin+0xff8
 echo FAIL cursor original caller\n
 detach
 quit 1
end
printf "CUR_BYTES %04X%08X%08X%08X\n",*(unsigned short*)($cur_ret-14),*(unsigned long*)($cur_ret-12),*(unsigned long*)($cur_ret-8),*(unsigned long*)($cur_ret-4)
mac-trap-args
printf "CUR_NATIVE_ENTER level=%d obscured=%u initialized=%u image=%X allowed=%u visible=%u D0=%08X D1=%08X D2=%08X D3=%08X D4=%08X D5=%08X D6=%08X D7=%08X A0=%08X A1=%08X A2=%08X A3=%08X A4=%08X A5=%08X A6=%08X A7=%08X\n",s_cursor.visibility.level,s_cursor.visibility.obscured,s_cursor.initialized,s_cursor.image,s_loudStopScreen->m_mouseAllowed,s_loudStopScreen->m_cursorVisible,$mac_regs[0],$mac_regs[1],$mac_regs[2],$mac_regs[3],$mac_regs[4],$mac_regs[5],$mac_regs[6],$mac_regs[7],$mac_regs[8],$mac_regs[9],$mac_regs[10],$mac_regs[11],$mac_regs[12],$mac_regs[13],$mac_regs[14],$cur_args
tbreak *$cur_ret
continue
if $pc!=$cur_ret
 echo FAIL cursor original return\n
 detach
 quit 1
end
printf "CUR_NATIVE_RETURN level=%d obscured=%u initialized=%u image=%X allowed=%u visible=%u D0=%08X D1=%08X D2=%08X D3=%08X D4=%08X D5=%08X D6=%08X D7=%08X A0=%08X A1=%08X A2=%08X A3=%08X A4=%08X A5=%08X A6=%08X A7=%08X\n",s_cursor.visibility.level,s_cursor.visibility.obscured,s_cursor.initialized,s_cursor.image,s_loudStopScreen->m_mouseAllowed,s_loudStopScreen->m_cursorVisible,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6,$sp
echo PASS native original ObscureCursor\n
