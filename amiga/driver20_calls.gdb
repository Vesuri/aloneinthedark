printf "DRIVER20_COVERAGE start statuses=%u\n",g_effectStatusCalls
set $line_seen=0
set $d20_n=0
set $d20_active=0
set $d20_finished=0
while $d20_finished==0
 tbreak dispatchMacTrap if (trap==0xa891 && $line_seen==0) || (trap==0xa0f8 && inUserService && *(unsigned long*)(userStack+4)==20) || (trap==0xa8a2 && *(unsigned long*)(frame+2)==(unsigned long)s_segments[5].begin+0x1e44)
 continue
 if g_stageBState==3
  echo FAIL driver20 unexpected drawing dependency\n
  detach
  quit 1
 end
 if trap==0xa891
  printf "DRIVER20_COVERAGE line-before statuses=%u observed=%u\n",g_effectStatusCalls,$d20_n
  source aga_startup_call.gdb
  source lineto_call.gdb
  printf "DRIVER20_COVERAGE line-after statuses=%u observed=%u\n",g_effectStatusCalls,$d20_n
  set $line_seen=1
  loop_continue
 end
 if trap==0xa8a2
  printf "DRIVER20_COVERAGE paint-before statuses=%u observed=%u\n",g_effectStatusCalls,$d20_n
  source paintworld_call.gdb
  printf "DRIVER20_COVERAGE paint-after statuses=%u observed=%u\n",g_effectStatusCalls,$d20_n
  loop_continue
 end
 set $d20_n=$d20_n+1
 set $d20_sp=(unsigned long)userStack
 set $d20_return=*(unsigned long*)$d20_sp
 set $d20_ignored=*(unsigned long*)($d20_sp+8)
 if $d20_n==1
  eval "dump binary memory ../tmp/driver20-native-packet.bin %u %u",$d20_ignored,$d20_ignored+26
 end
set $d20_reg2=regs[2]
set $d20_reg3=regs[3]
set $d20_reg4=regs[4]
set $d20_reg5=regs[5]
set $d20_reg6=regs[6]
set $d20_reg7=regs[7]
set $d20_reg8=regs[8]
set $d20_reg9=regs[9]
set $d20_reg10=regs[10]
set $d20_reg11=regs[11]
set $d20_reg12=regs[12]
set $d20_reg13=regs[13]
set $d20_reg14=regs[14]
tbreak *((unsigned long)*g_soundDriverHandle+2)
continue
printf "DRIVER20_STUB pc=%X sp=%X d0=%X d1=%X expected=%X returnword=%X\n",$pc,$sp,$d0,$d1,$d20_return,*(unsigned short*)$d20_return
if $pc!=(unsigned long)*g_soundDriverHandle+2
 echo FAIL driver20 stub return checkpoint\n
 detach
 quit 1
end
stepi
if $pc!=$d20_return || $sp!=$d20_sp+4 || $d0>1 || $d1!=$d20_ignored
 echo FAIL driver20 return\n
 detach
 quit 1
end
if $d2!=$d20_reg2
 echo FAIL driver20 preserved register\n
 detach
 quit 1
end
if $d3!=$d20_reg3
 echo FAIL driver20 preserved register\n
 detach
 quit 1
end
if $d4!=$d20_reg4
 echo FAIL driver20 preserved register\n
 detach
 quit 1
end
if $d5!=$d20_reg5
 echo FAIL driver20 preserved register\n
 detach
 quit 1
end
if $d6!=$d20_reg6
 echo FAIL driver20 preserved register\n
 detach
 quit 1
end
if $d7!=$d20_reg7
 echo FAIL driver20 preserved register\n
 detach
 quit 1
end
if $a0!=$d20_reg8
 echo FAIL driver20 preserved register\n
 detach
 quit 1
end
if $a1!=$d20_reg9
 echo FAIL driver20 preserved register\n
 detach
 quit 1
end
if $a2!=$d20_reg10
 echo FAIL driver20 preserved register\n
 detach
 quit 1
end
if $a3!=$d20_reg11
 echo FAIL driver20 preserved register\n
 detach
 quit 1
end
if $a4!=$d20_reg12
 echo FAIL driver20 preserved register\n
 detach
 quit 1
end
if $a5!=$d20_reg13
 echo FAIL driver20 preserved register\n
 detach
 quit 1
end
if $a6!=$d20_reg14
 echo FAIL driver20 preserved register\n
 detach
 quit 1
end

 if $d0==0
  if g_soundDriver.effects[0].active!=1 || g_effectStops!=0
   echo FAIL driver20 reported active without playback\n
   detach
   quit 1
  end
  set $d20_active=$d20_active+1
 else
  if $d20_active==0 || g_soundDriver.effects[0].active || g_effectStops!=1 || g_effects[0].chip || (*(unsigned short*)0xdff002&15)
   echo FAIL driver20 reported completed without cleanup\n
   detach
   quit 1
  end
  set $d20_finished=1
 end
 if $d20_n>10000
  echo FAIL driver20 poll bound\n
  detach
  quit 1
 end
end
printf "DRIVER20_NATIVE_SEQUENCE calls=%u active=%u complete=1 driverCalls=%u statusCalls=%u starts=%u stops=%u\n",$d20_n,$d20_active,g_soundDriverCalls,g_effectStatusCalls,g_effectStarts,g_effectStops
echo PASS native driver20 playing-to-finished sequence ABI and cleanup\n
printf "DRIVER17_CLEANUP starts=%u stops=%u tick=%u elapsed=%u active=%u channel=%d chip=%X allocated=%u dma=%X\n",g_effectStarts,g_effectStops,g_macTicks,g_macTicks-g_effects[0].started,g_soundDriver.effects[0].active,g_soundDriver.effects[0].channel,g_effects[0].chip,g_effects[0].allocated,*(unsigned short*)0xdff002
echo PASS native driver17 natural completion DMA-off and sample released\n
