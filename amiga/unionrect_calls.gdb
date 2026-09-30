set $ur_count=0
while $ur_count<20
 tbreak dispatchMacTrap if trap==0xa8ab
 continue
 set $ur_count=$ur_count+1
 set $args=(unsigned long)userStack
 set $ur_base=(unsigned long)s_segments[13].begin
 set $ur_ret=*(unsigned long*)(frame+2)+2
 if $ur_ret!=$ur_base+0x1dc
  echo FAIL UnionRect original caller\n
  detach
  quit 1
 end
 set $dst=*(unsigned long*)$args
 set $r2=*(unsigned long*)($args+4)
 set $r1=*(unsigned long*)($args+8)
 printf "UR_ENTER n=%u fixture=0 sp=%X dst=%X r1=%X r2=%X data1=%08X%08X data2=%08X%08X dest=%08X%08X d0=%08X d1=%08X d2=%08X d3=%08X d4=%08X d5=%08X d6=%08X d7=%08X a0=%08X a1=%08X a2=%08X a3=%08X a4=%08X a5=%08X a6=%08X\n",$ur_count,$args,$dst,$r1,$r2,*(unsigned long*)$r1,*(unsigned long*)($r1+4),*(unsigned long*)$r2,*(unsigned long*)($r2+4),*(unsigned long*)$dst,*(unsigned long*)($dst+4),regs[0],regs[1],regs[2],regs[3],regs[4],regs[5],regs[6],regs[7],regs[8],regs[9],regs[10],regs[11],regs[12],regs[13],regs[14]
 if $ur_count==1
  printf "UR_BYTES data=%04X%04X%04X%04X%04X%04X%04X%04X%04X%04X%04X%04X%04X%04X%04X%04X%04X%04X\n",*(unsigned short*)($ur_base+0x1bc),*(unsigned short*)($ur_base+0x1be),*(unsigned short*)($ur_base+0x1c0),*(unsigned short*)($ur_base+0x1c2),*(unsigned short*)($ur_base+0x1c4),*(unsigned short*)($ur_base+0x1c6),*(unsigned short*)($ur_base+0x1c8),*(unsigned short*)($ur_base+0x1ca),*(unsigned short*)($ur_base+0x1cc),*(unsigned short*)($ur_base+0x1ce),*(unsigned short*)($ur_base+0x1d0),*(unsigned short*)($ur_base+0x1d2),*(unsigned short*)($ur_base+0x1d4),*(unsigned short*)($ur_base+0x1d6),*(unsigned short*)($ur_base+0x1d8),*(unsigned short*)($ur_base+0x1da),*(unsigned short*)($ur_base+0x1dc),*(unsigned short*)($ur_base+0x1de)
 end
 tbreak *$ur_ret
 continue
 if $pc!=$ur_ret
  echo FAIL UnionRect return\n
  detach
  quit 1
 end
 printf "UR_RETURN n=%u fixture=0 sp=%X dst=%X r1=%X r2=%X data1=%08X%08X data2=%08X%08X dest=%08X%08X returnsp=%X d0=%08X d1=%08X d2=%08X d3=%08X d4=%08X d5=%08X d6=%08X d7=%08X a0=%08X a1=%08X a2=%08X a3=%08X a4=%08X a5=%08X a6=%08X\n",$ur_count,$args,$dst,$r1,$r2,*(unsigned long*)$r1,*(unsigned long*)($r1+4),*(unsigned long*)$r2,*(unsigned long*)($r2+4),*(unsigned long*)$dst,*(unsigned long*)($dst+4),$sp,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
end
echo PASS native UnionRect calls=20\n
