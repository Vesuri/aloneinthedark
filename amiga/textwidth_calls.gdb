set $tw_finished=0
set $tw_n=0
set $binding_captured=0
set $sr_n=0
set $ev_n=0
set $gc_n=0
set $wrgb_captured=0
set $paint_captured=0
while $tw_finished==0
 tbreak dispatchMacTrap if (trap==0xaa95 && *(unsigned long*)(frame+2)==(unsigned long)s_segments[5].begin+0x20cc) || (trap==0xaa91 && *(unsigned long*)(frame+2)==(unsigned long)s_segments[5].begin+0x201c) || (trap==0xaa18 && *(unsigned short*)userStack==129) || ($paint_captured==0 && trap==0xa8a2) || ($wrgb_captured==0 && trap==0xaa14 && *(unsigned long*)(frame+2)==(unsigned long)s_segments[12].begin+0x624a) || ($gc_n<2 && (trap==0xaa19 || trap==0xaa1a)) || trap==0xa856 || trap==0xa860 || trap==0xa886 || (trap==0xab1d && *(unsigned long*)(frame+2)==(unsigned long)s_segments[9].begin+0xe0a)
 continue
 if g_stageBState==3
  loop_break
 end
 if trap==0xaa95
  source binding129_call.gdb
  source presentpicture_calls.gdb
  tbreak dispatchMacTrap if trap==0xaa95 && *(unsigned long*)(frame+2)==(unsigned long)s_segments[5].begin+0x214c
  continue
  source restorepalette_call.gdb
  tbreak dispatchMacTrap if trap==0xa8ec && *(unsigned long*)(frame+2)==(unsigned long)s_segments[10].begin+0x24d2
  continue
  source copybits8_call.gdb
  tbreak dispatchMacTrap if trap==0xa0f8 && inUserService && *(unsigned long*)(userStack+4)==22
  continue
  source driver22_call.gdb
  tbreak dispatchMacTrap if trap==0xa0f8 && inUserService && *(unsigned long*)(userStack+4)==17
  continue
  source driver17_call.gdb
  source driver20_calls.gdb
  tbreak *((unsigned long)s_segments[13].begin+0xd52) if *(unsigned short*)(*(unsigned long*)s_qdThePort+56)==0 && *(unsigned long*)(*(unsigned long*)s_qdThePort+80)==18 && *(unsigned long*)*(unsigned long*)$sp==0x00c00075 && *(unsigned long*)(*(unsigned long*)$sp+4)==0x00c800b5
  continue
  if $pc!=(unsigned long)s_segments[13].begin+0xd52 || *(unsigned short*)$pc!=0xa8a2
   echo FAIL later PaintRect original instruction boundary\n
   detach
   quit 1
  end
  printf "PL_BOUNDARY pc=%X opcode=%X sp=%X\n",$pc,*(unsigned short*)$pc,$sp
  tbreak dispatchMacTrap
  continue
  if trap!=0xa8a2
   echo FAIL later PaintRect dispatch boundary\n
   detach
   quit 1
  end
  if g_stageBState==3
   echo FAIL later PaintRect aligned call not reached\n
   detach
   quit 1
  end
  source paintlater_call.gdb
  tbreak dispatchMacTrap if trap==0xa885 && inUserService
  continue
  if g_stageBState==3
   echo FAIL DrawText not reached\n
   detach
   quit 1
  end
  source drawtext_call.gdb
  tbreak *((unsigned long)s_segments[4].begin+0x1dbc)
  continue
  tbreak dispatchMacTrap
  continue
  source copylate_call.gdb
  tbreak *((unsigned long)s_segments[12].begin+0x13c)
  continue
  if *(unsigned long*)($pc-4)!=0x486efff8 || *(unsigned short*)$pc!=0xa88b
   echo FAIL Times FontInfo original bytes\n
   detach
   quit 1
  end
  set $dot_info=*(unsigned long*)$sp
  set $dot_info_sp=$sp
  set $dot_info_tail=*(unsigned long*)($dot_info+8)
  tbreak *((unsigned long)s_segments[12].begin+0x13e)
  continue
  if $sp!=$dot_info_sp+4 || *(unsigned long*)$dot_info!=0x000c0004 || *(unsigned long*)($dot_info+4)!=0x000f0000 || *(unsigned long*)($dot_info+8)!=$dot_info_tail
   echo FAIL Times FontInfo layout metrics or extent\n
   detach
   quit 1
  end
  echo PASS native Times FontInfo ascent=12 descent=4 maximum=15 leading=0\n
  tbreak *((unsigned long)s_segments[12].begin+0x346) if *(unsigned short*)$sp==8 && *(unsigned short*)($sp+2)==0 && *(unsigned short*)*(unsigned long*)($sp+4)==0x49fa
  continue
  tbreak dispatchMacTrap if trap==0xa885 && inUserService
  continue
  source dottext_call.gdb
  set $postdot_n=0
  while g_stageBState!=3
   tbreak dispatchMacTrap if inUserService || trap==0xa891
   continue
   if g_stageBState==3
    loop_break
   end
   if trap==0xa891
    source windowline_call.gdb
    tbreak *((unsigned long)s_segments[12].begin+0x346) if *(unsigned short*)$sp==4 && *(unsigned short*)($sp+2)==0 && *(unsigned long*)*(unsigned long*)($sp+4)==0x5961896c
    continue
    tbreak dispatchMacTrap if trap==0xa885 && inUserService
    continue
    source accenttext_call.gdb
    tbreak *((unsigned long)s_segments[4].begin+0x5220)
    continue
    if $pc!=(unsigned long)s_segments[4].begin+0x5220 || $d0!=0
     echo FAIL original intro return\n
     detach
     quit 1
    end
    printf "INTRO_PROGRESS second-return d0=%u frames=%u ticks=%u\n",$d0,g_macFramesPresented,g_macTicks
    tbreak *((unsigned long)s_segments[13].begin+0x7fa)
    continue
    tbreak dispatchMacTrap
    continue
    if trap!=0xa8ec
     echo FAIL post-intro CopyBits dispatch\n
     detach
     quit 1
    end
    source postcopy_call.gdb
    tbreak *((unsigned long)s_segments[12].begin+0x583a)
    continue
    tbreak dispatchMacTrap
    continue
    if trap!=0xa976
     echo FAIL GetKeys dispatch\n
     detach
     quit 1
    end
    source getkeys_call.gdb
    tbreak *((unsigned long)s_segments[3].begin+0x137e)
    continue
    tbreak dispatchMacTrap if inUserService && trap==0xa0f8
    continue
    source driver13_call.gdb
    tbreak *(g_code3Base+0x138c)
    continue
    source song_start_call.gdb
    tbreak *(g_code3Base+0xfc8)
    continue
    source driver15_call.gdb
    tbreak *(g_code3Base+0x1fc8)
    continue
    source driver4_call.gdb
    tbreak dispatchMacTrap if trap==0xa8df
    continue
    source rectrgn_call.gdb
    continue
    loop_break
   end
   set $postdot_n=$postdot_n+1
   printf "POSTDOT_SERVICE n=%u trap=%X entered=%u completed=%u queries=%u\n",$postdot_n,trap,g_macServiceEntered,g_macServiceCompleted,g_effectStatusCalls
  end
  loop_break
 end
 if trap==0xaa91
  source palette129_call.gdb
  loop_continue
 end
 if trap==0xaa18
  source ctable129_call.gdb
  loop_continue
 end
 if trap==0xa8a2
  source paintrect_call.gdb
  set $paint_captured=1
  loop_continue
 end
 if trap==0xaa14
  source window_rgb_calls.gdb
  set $wrgb_captured=1
  loop_continue
 end
 if trap==0xaa19 || trap==0xaa1a
  source getcolor_call.gdb
  loop_continue
 end
 if trap==0xa856
  source obscure_cursor_call.gdb
  loop_continue
 end
 if trap==0xa860
  source startup_event_call.gdb
  loop_continue
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
if $ev_n<4
 echo FAIL startup event call count\n
 detach
 quit 1
end
printf "PASS native startup events calls=%u\n",$ev_n
if $gc_n!=2
 echo FAIL colour getter call count\n
 detach
 quit 1
end
