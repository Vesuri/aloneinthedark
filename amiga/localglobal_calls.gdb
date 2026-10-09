set $lg_n=1
while $lg_n<=2
 tbreak aitdLineADispatch if (*(unsigned short*)*(unsigned long*)(frame+2))==0xa870
 continue
 set $lg_args=(unsigned long)userStack
 set $lg_return=*(unsigned long*)(frame+2)+2
 set $lg_point=*(unsigned long*)$lg_args
 set $lg_port=*(unsigned long*)s_qdThePort
 set $lg_pm=*(unsigned long*)*(unsigned long*)($lg_port+2)
 printf "LG_BYTES n=%u data=%04X%04X%04X\n",$lg_n,*(unsigned short*)($lg_return-6),*(unsigned short*)($lg_return-4),*(unsigned short*)($lg_return-2)
 printf "LG_ENTRY n=%u sp=%X point=%X value=%08X port=%X bounds=%04X%04X%04X%04X d0=%08X d1=%08X d2=%08X d3=%08X d4=%08X d5=%08X d6=%08X d7=%08X a0=%08X a1=%08X a2=%08X a3=%08X a4=%08X a5=%08X a6=%08X\n",$lg_n,$lg_args,$lg_point,*(unsigned long*)$lg_point,$lg_port,*(unsigned short*)($lg_pm+6),*(unsigned short*)($lg_pm+8),*(unsigned short*)($lg_pm+10),*(unsigned short*)($lg_pm+12),regs[0],regs[1],regs[2],regs[3],regs[4],regs[5],regs[6],regs[7],regs[8],regs[9],regs[10],regs[11],regs[12],regs[13],regs[14]
 eval "dump binary memory ../tmp/localglobal-native-%u-entry-point.bin %u %u",$lg_n,$lg_point-4,$lg_point+8
 eval "dump binary memory ../tmp/localglobal-native-%u-entry-port.bin %u %u",$lg_n,$lg_port,$lg_port+108
 eval "dump binary memory ../tmp/localglobal-native-%u-entry-pm.bin %u %u",$lg_n,$lg_pm,$lg_pm+50
 tbreak *$lg_return
 continue
 if $pc!=$lg_return
  echo FAIL LocalToGlobal return\n
  detach
  quit 1
 end
 printf "LG_RETURN n=%u sp=%X point=%X value=%08X port=%X bounds=%04X%04X%04X%04X d0=%08X d1=%08X d2=%08X d3=%08X d4=%08X d5=%08X d6=%08X d7=%08X a0=%08X a1=%08X a2=%08X a3=%08X a4=%08X a5=%08X a6=%08X\n",$lg_n,$sp,$lg_point,*(unsigned long*)$lg_point,$lg_port,*(unsigned short*)($lg_pm+6),*(unsigned short*)($lg_pm+8),*(unsigned short*)($lg_pm+10),*(unsigned short*)($lg_pm+12),$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
 eval "dump binary memory ../tmp/localglobal-native-%u-return-point.bin %u %u",$lg_n,$lg_point-4,$lg_point+8
 eval "dump binary memory ../tmp/localglobal-native-%u-return-port.bin %u %u",$lg_n,$lg_port,$lg_port+108
 eval "dump binary memory ../tmp/localglobal-native-%u-return-pm.bin %u %u",$lg_n,$lg_pm,$lg_pm+50
 set $lg_n=$lg_n+1
end
echo PASS native LocalToGlobal calls=2\n