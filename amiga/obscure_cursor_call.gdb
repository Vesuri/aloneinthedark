set $cur_ret=*(unsigned long*)(frame+2)+2
set $cur_args=(unsigned long)userStack
if $cur_ret!=(unsigned long)s_segments[7].begin+0xff8
 echo FAIL cursor original caller\n
 detach
 quit 1
end
printf "CUR_BYTES %04X%08X%08X%08X\n",*(unsigned short*)($cur_ret-14),*(unsigned long*)($cur_ret-12),*(unsigned long*)($cur_ret-8),*(unsigned long*)($cur_ret-4)
printf "CUR_NATIVE_ENTER level=%d obscured=%u initialized=%u image=%X allowed=%u visible=%u D0=%08X D1=%08X D2=%08X D3=%08X D4=%08X D5=%08X D6=%08X D7=%08X A0=%08X A1=%08X A2=%08X A3=%08X A4=%08X A5=%08X A6=%08X A7=%08X\n",s_cursor.visibility.level,s_cursor.visibility.obscured,s_cursor.initialized,s_cursor.image,s_loudStopScreen->m_mouseAllowed,s_loudStopScreen->m_cursorVisible,regs[0],regs[1],regs[2],regs[3],regs[4],regs[5],regs[6],regs[7],regs[8],regs[9],regs[10],regs[11],regs[12],regs[13],regs[14],$cur_args
tbreak *$cur_ret
continue
if $pc!=$cur_ret
 echo FAIL cursor original return\n
 detach
 quit 1
end
printf "CUR_NATIVE_RETURN level=%d obscured=%u initialized=%u image=%X allowed=%u visible=%u D0=%08X D1=%08X D2=%08X D3=%08X D4=%08X D5=%08X D6=%08X D7=%08X A0=%08X A1=%08X A2=%08X A3=%08X A4=%08X A5=%08X A6=%08X A7=%08X\n",s_cursor.visibility.level,s_cursor.visibility.obscured,s_cursor.initialized,s_cursor.image,s_loudStopScreen->m_mouseAllowed,s_loudStopScreen->m_cursorVisible,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6,$sp
echo PASS native original ObscureCursor\n
