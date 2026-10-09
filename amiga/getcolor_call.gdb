set $gc_n=$gc_n+1
set $gc_args=(unsigned long)userStack
set $gc_ret=*(unsigned long*)(frame+2)+2
set $gc_trap=*(unsigned short*)*(unsigned long*)(frame+2)
set $gc_rgb=*(unsigned long*)$gc_args
set $gc_port=*(unsigned long*)s_qdThePort
if ($gc_trap==0xaa19 && $gc_ret!=(unsigned long)s_segments[12].begin+0x623e) || ($gc_trap==0xaa1a && $gc_ret!=(unsigned long)s_segments[12].begin+0x6244)
 echo FAIL colour getter caller\n
 detach
 quit 1
end
printf "GC_BYTES n=%u data=%04X%04X%04X\n",$gc_n,*(unsigned short*)($gc_ret-6),*(unsigned short*)($gc_ret-4),*(unsigned short*)($gc_ret-2)
printf "GC_ENTER n=%u fixture=0 trap=%X sp=%X rgb=%X value=%04X%04X%04X guard=%04X%04X%04X%04X%04X%04X%04X port=%X fields=%04X%04X%04X%04X%04X%04X version=%X d0=%08X d1=%08X d2=%08X d3=%08X d4=%08X d5=%08X d6=%08X d7=%08X a0=%08X a1=%08X a2=%08X a3=%08X a4=%08X a5=%08X a6=%08X\n",$gc_n,$gc_trap,$gc_args,$gc_rgb,*(unsigned short*)($gc_rgb+0),*(unsigned short*)($gc_rgb+2),*(unsigned short*)($gc_rgb+4),*(unsigned short*)($gc_rgb-4),*(unsigned short*)($gc_rgb-2),*(unsigned short*)($gc_rgb+0),*(unsigned short*)($gc_rgb+2),*(unsigned short*)($gc_rgb+4),*(unsigned short*)($gc_rgb+6),*(unsigned short*)($gc_rgb+8),$gc_port,*(unsigned short*)($gc_port+36),*(unsigned short*)($gc_port+38),*(unsigned short*)($gc_port+40),*(unsigned short*)($gc_port+42),*(unsigned short*)($gc_port+44),*(unsigned short*)($gc_port+46),*(unsigned short*)($gc_port+6),regs[0],regs[1],regs[2],regs[3],regs[4],regs[5],regs[6],regs[7],regs[8],regs[9],regs[10],regs[11],regs[12],regs[13],regs[14]
eval "dump binary memory ../tmp/getcolor-native-%u-enter-port.bin %u %u",$gc_n,$gc_port,$gc_port+108
tbreak *$gc_ret
continue
if $pc!=$gc_ret
 echo FAIL colour getter return\n
 detach
 quit 1
end
printf "GC_RETURN n=%u fixture=0 trap=%X sp=%X rgb=%X value=%04X%04X%04X guard=%04X%04X%04X%04X%04X%04X%04X port=%X fields=%04X%04X%04X%04X%04X%04X version=%X d0=%08X d1=%08X d2=%08X d3=%08X d4=%08X d5=%08X d6=%08X d7=%08X a0=%08X a1=%08X a2=%08X a3=%08X a4=%08X a5=%08X a6=%08X\n",$gc_n,$gc_trap,$sp,$gc_rgb,*(unsigned short*)($gc_rgb+0),*(unsigned short*)($gc_rgb+2),*(unsigned short*)($gc_rgb+4),*(unsigned short*)($gc_rgb-4),*(unsigned short*)($gc_rgb-2),*(unsigned short*)($gc_rgb+0),*(unsigned short*)($gc_rgb+2),*(unsigned short*)($gc_rgb+4),*(unsigned short*)($gc_rgb+6),*(unsigned short*)($gc_rgb+8),$gc_port,*(unsigned short*)($gc_port+36),*(unsigned short*)($gc_port+38),*(unsigned short*)($gc_port+40),*(unsigned short*)($gc_port+42),*(unsigned short*)($gc_port+44),*(unsigned short*)($gc_port+46),*(unsigned short*)($gc_port+6),$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
eval "dump binary memory ../tmp/getcolor-native-%u-return-port.bin %u %u",$gc_n,$gc_port,$gc_port+108
printf "PASS native colour getter n=%u\n",$gc_n
