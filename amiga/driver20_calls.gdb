printf "DRIVER20_COVERAGE start statuses=%u\n",g_effectStatusCalls
set $d20_scoped=g_effectStatusCalls
set $line_seen=0
set $d20_n=0
set $d20_active=0
set $d20_finished=0
while $d20_finished==0
 tbreak *aitd_line_a_trap_entry if $line_seen==0 && *(unsigned short*)*(unsigned long*)((*(unsigned char**)($sp+4))+2)==0xa891
 set $d20_line_bp=$bpnum
 tbreak dispatchMacTrap if (trap==0xa0f8 && *(unsigned long*)(userStack+4)==20) || (trap==0xa8a2 && *(unsigned long*)(frame+2)==(unsigned long)s_segments[5].begin+0x1e44)
 set $d20_service_bp=$bpnum
 continue
 delete $d20_line_bp $d20_service_bp
 mac-trap-args
 set $d20_trap=*(unsigned short*)*(unsigned long*)($mac_frame+2)
 if g_stageBState==3
  echo FAIL driver20 unexpected drawing dependency\n
  detach
  quit 1
 end
 if $d20_trap==0xa891
  printf "DRIVER20_COVERAGE line-before statuses=%u observed=%u\n",g_effectStatusCalls,$d20_n
  set $d20_scope_start=g_effectStatusCalls
  source lineto_call.gdb
  source aga_startup_call.gdb
  printf "DRIVER20_COVERAGE line-after statuses=%u observed=%u\n",g_effectStatusCalls,$d20_n
  set $d20_scoped=$d20_scoped+g_effectStatusCalls-$d20_scope_start
  set $line_seen=1
  loop_continue
 end
 if $d20_trap==0xa8a2
  printf "DRIVER20_COVERAGE paint-before statuses=%u observed=%u\n",g_effectStatusCalls,$d20_n
  set $d20_scope_start=g_effectStatusCalls
  source paintworld_call.gdb
  printf "DRIVER20_COVERAGE paint-after statuses=%u observed=%u\n",g_effectStatusCalls,$d20_n
  set $d20_scoped=$d20_scoped+g_effectStatusCalls-$d20_scope_start
  loop_continue
 end
 set $d20_n=$d20_n+1
 mac-trap-args
 set $d20_sp=(unsigned long)$mac_stack
 set $d20_return=*(unsigned long*)$d20_sp
 set $d20_ignored=*(unsigned long*)($d20_sp+8)
 if $d20_n==1
  eval "dump binary memory ../tmp/driver20-native-packet.bin %u %u",$d20_ignored,$d20_ignored+26
 end
mac-trap-args
set $d20_reg2=$mac_regs[2]
set $d20_reg3=$mac_regs[3]
set $d20_reg4=$mac_regs[4]
set $d20_reg5=$mac_regs[5]
set $d20_reg6=$mac_regs[6]
set $d20_reg7=$mac_regs[7]
set $d20_reg8=$mac_regs[8]
set $d20_reg9=$mac_regs[9]
set $d20_reg10=$mac_regs[10]
set $d20_reg11=$mac_regs[11]
set $d20_reg12=$mac_regs[12]
set $d20_reg13=$mac_regs[13]
set $d20_reg14=$mac_regs[14]
set $d20_scope_start=g_effectStatusCalls
tbreak *$d20_return if $sp==$d20_sp+4
continue
if g_effectStatusCalls<$d20_scope_start+1
 echo FAIL driver20 query counter did not advance\n
 detach
 quit 1
end
set $d20_scoped=$d20_scoped+g_effectStatusCalls-$d20_scope_start-1
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
printf "DRIVER20_ACCOUNTING observed=%u scoped=%u total=%u\n",$d20_n,$d20_scoped,g_effectStatusCalls
if $d20_n+$d20_scoped!=g_effectStatusCalls
 echo FAIL driver20 unaccounted status query\n
 detach
 quit 1
end
printf "DRIVER20_NATIVE_SEQUENCE calls=%u active=%u complete=1 driverCalls=%u statusCalls=%u starts=%u stops=%u\n",$d20_n,$d20_active,g_soundDriverCalls,g_effectStatusCalls,g_effectStarts,g_effectStops
echo PASS native driver20 playing-to-finished sequence ABI and cleanup\n
printf "DRIVER17_CLEANUP starts=%u stops=%u tick=%u elapsed=%u active=%u channel=%d chip=%X allocated=%u dma=%X\n",g_effectStarts,g_effectStops,g_macTicks,g_macTicks-g_effects[0].started,g_soundDriver.effects[0].active,g_soundDriver.effects[0].channel,g_effects[0].chip,g_effects[0].allocated,*(unsigned short*)0xdff002
echo PASS native driver17 natural completion DMA-off and sample released\n

# Check the first effect here; later intro states may start another sound.
if g_effectStarts!=1 || g_effectStops!=1 || g_soundDriver.effects[0].active || g_soundDriver.effects[0].channel!=-1 || g_soundDriver.channels[0]!=-1
 echo FAIL driver: effect playback\n
 detach
 quit 1
end
if g_soundDriver.effects[1].active || g_soundDriver.effects[1].sample || g_soundDriver.effects[1].channel!=-1
 echo FAIL driver: unused effect voice\n
 detach
 quit 1
end
set $vi=1
while $vi<4
 if g_soundDriver.channels[$vi]!=-1
  echo FAIL driver: unused channel\n
  detach
  quit 1
 end
 set $vi=$vi+1
end
