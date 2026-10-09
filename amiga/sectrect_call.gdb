set $sr_n=$sr_n+1
tbreak aitdLineADispatch if (*(unsigned short*)*(unsigned long*)(frame+2))==0xa8aa
continue
set $sr_args=(unsigned long)userStack
set $sr_return=*(unsigned long*)(frame+2)+2
set $sr_out=*(unsigned long*)$sr_args
set $sr_b=*(unsigned long*)($sr_args+4)
set $sr_a=*(unsigned long*)($sr_args+8)
if $sr_return!=(unsigned long)s_segments[9].begin+0xe92
 echo FAIL original SectRect caller\n
 detach
 quit 1
end
if $sr_n==1
printf "SR_BYTES data=%04X%04X%04X%04X%04X%04X%04X%04X%04X\n",*(unsigned short*)($sr_return-18),*(unsigned short*)($sr_return-16),*(unsigned short*)($sr_return-14),*(unsigned short*)($sr_return-12),*(unsigned short*)($sr_return-10),*(unsigned short*)($sr_return-8),*(unsigned short*)($sr_return-6),*(unsigned short*)($sr_return-4),*(unsigned short*)($sr_return-2)
end
printf "SR_ENTER n=%u fixture=0 sp=%X dst=%X r1=%X r2=%X data1=%08X%08X data2=%08X%08X dest=%08X%08X result=%04X d0=%08X d1=%08X d2=%08X d3=%08X d4=%08X d5=%08X d6=%08X d7=%08X a0=%08X a1=%08X a2=%08X a3=%08X a4=%08X a5=%08X a6=%08X\n",$sr_n,$sr_args,$sr_out,$sr_a,$sr_b,*(unsigned long*)$sr_a,*(unsigned long*)($sr_a+4),*(unsigned long*)$sr_b,*(unsigned long*)($sr_b+4),*(unsigned long*)$sr_out,*(unsigned long*)($sr_out+4),*(unsigned short*)($sr_args+12),regs[0],regs[1],regs[2],regs[3],regs[4],regs[5],regs[6],regs[7],regs[8],regs[9],regs[10],regs[11],regs[12],regs[13],regs[14]
eval "dump binary memory ../tmp/sectrect-native-%u-enter-guard.bin %u %u",$sr_n,$sr_out-4,$sr_out+12
tbreak *$sr_return
continue
if $pc!=$sr_return
 echo FAIL SectRect return\n
 detach
 quit 1
end
printf "SR_RETURN n=%u fixture=0 sp=%X dst=%X r1=%X r2=%X data1=%08X%08X data2=%08X%08X dest=%08X%08X result=%04X returnsp=%X d0=%08X d1=%08X d2=%08X d3=%08X d4=%08X d5=%08X d6=%08X d7=%08X a0=%08X a1=%08X a2=%08X a3=%08X a4=%08X a5=%08X a6=%08X\n",$sr_n,$sr_args,$sr_out,$sr_a,$sr_b,*(unsigned long*)$sr_a,*(unsigned long*)($sr_a+4),*(unsigned long*)$sr_b,*(unsigned long*)($sr_b+4),*(unsigned long*)$sr_out,*(unsigned long*)($sr_out+4),*(unsigned short*)($sr_args+12),$sp,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
eval "dump binary memory ../tmp/sectrect-native-%u-return-guard.bin %u %u",$sr_n,$sr_out-4,$sr_out+12
printf "PASS native original SectRect n=%u\n",$sr_n
