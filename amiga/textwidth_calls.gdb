set $tw_finished=0
set $tw_n=0
set $binding_captured=0
set $sr_n=0
while $tw_finished==0
 tbreak dispatchMacTrap if trap==0xa886 || (trap==0xab1d && *(unsigned long*)(frame+2)==(unsigned long)s_segments[9].begin+0xe0a)
 continue
 if g_stageBState==3
  loop_break
 end
 if trap==0xab1d
  if $binding_captured==0
   source world_restore_call.gdb
   source localglobal_calls.gdb
   source device_attribute_call.gdb
   set $binding_captured=1
  end
  source sectrect_call.gdb
  loop_continue
 end
 set $tw_n=$tw_n+1
 set $tw_args=(unsigned long)userStack
 set $tw_return=*(unsigned long*)(frame+2)+2
 set $tw_port=*(unsigned long*)s_qdThePort
 set $tw_count=*(unsigned short*)$tw_args
 set $tw_first=*(unsigned short*)($tw_args+2)
 set $tw_text=*(unsigned long*)($tw_args+4)
 printf "TW_NATIVE_ENTER n=%u sp=%X count=%X first=%X font=%X size=%X face=%X extra=%X segment12offset=%X\n",$tw_n,$tw_args,$tw_count,$tw_first,*(unsigned short*)($tw_port+68),*(unsigned short*)($tw_port+74),*(unsigned char*)($tw_port+70),*(unsigned long*)($tw_port+76),$tw_return-(unsigned long)s_segments[12].begin-2
 printf "TW_NATIVE_BYTES n=%u data=%04X%04X%04X\n",$tw_n,*(unsigned short*)($tw_return-6),*(unsigned short*)($tw_return-4),*(unsigned short*)($tw_return-2)
 eval "dump binary memory ../tmp/textwidth-native-%u-text.bin %u %u",$tw_n,$tw_text+$tw_first,$tw_text+$tw_first+$tw_count
 eval "dump binary memory ../tmp/textwidth-native-%u-before-port.bin %u %u",$tw_n,$tw_port,$tw_port+108
 set $tw_reg0=regs[0]
 set $tw_reg1=regs[1]
 set $tw_reg2=regs[2]
 set $tw_reg3=regs[3]
 set $tw_reg4=regs[4]
 set $tw_reg5=regs[5]
 set $tw_reg6=regs[6]
 set $tw_reg7=regs[7]
 set $tw_reg8=regs[8]
 set $tw_reg9=regs[9]
 set $tw_reg10=regs[10]
 set $tw_reg11=regs[11]
 set $tw_reg12=regs[12]
 set $tw_reg13=regs[13]
 set $tw_reg14=regs[14]
 tbreak *$tw_return
 continue
 if g_stageBState==3
  echo FAIL TextWidth did not return\n
  detach
  quit 1
 end
 if $d0!=$tw_reg0
  echo FAIL native TextWidth preserved d0\n
  detach
  quit 1
 end
 if $d1!=$tw_reg1
  echo FAIL native TextWidth preserved d1\n
  detach
  quit 1
 end
 if $d2!=$tw_reg2
  echo FAIL native TextWidth preserved d2\n
  detach
  quit 1
 end
 if $d3!=$tw_reg3
  echo FAIL native TextWidth preserved d3\n
  detach
  quit 1
 end
 if $d4!=$tw_reg4
  echo FAIL native TextWidth preserved d4\n
  detach
  quit 1
 end
 if $d5!=$tw_reg5
  echo FAIL native TextWidth preserved d5\n
  detach
  quit 1
 end
 if $d6!=$tw_reg6
  echo FAIL native TextWidth preserved d6\n
  detach
  quit 1
 end
 if $d7!=$tw_reg7
  echo FAIL native TextWidth preserved d7\n
  detach
  quit 1
 end
 if $a0!=$tw_reg8
  echo FAIL native TextWidth preserved a0\n
  detach
  quit 1
 end
 if $a1!=$tw_reg9
  echo FAIL native TextWidth preserved a1\n
  detach
  quit 1
 end
 if $a2!=$tw_reg10
  echo FAIL native TextWidth preserved a2\n
  detach
  quit 1
 end
 if $a3!=$tw_reg11
  echo FAIL native TextWidth preserved a3\n
  detach
  quit 1
 end
 if $a4!=$tw_reg12
  echo FAIL native TextWidth preserved a4\n
  detach
  quit 1
 end
 if $a5!=$tw_reg13
  echo FAIL native TextWidth preserved a5\n
  detach
  quit 1
 end
 if $a6!=$tw_reg14
  echo FAIL native TextWidth preserved a6\n
  detach
  quit 1
 end
 printf "TW_NATIVE_RETURN n=%u sp=%X width=%X\n",$tw_n,$sp,*(unsigned short*)$sp
 eval "dump binary memory ../tmp/textwidth-native-%u-after-port.bin %u %u",$tw_n,$tw_port,$tw_port+108
end
printf "PASS native TextWidth calls=%u\n",$tw_n
