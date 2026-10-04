set pagination off
set confirm off
set $ae_seen=0
set $ae_handler_seen=0
set $sane_count=0
set $sane_mask=0
tbreak getFontNumber
continue
set $ae_engine=s_segments[7].begin
break *($ae_engine+0x21e8)
commands
 silent
 if *(unsigned short*)$pc!=0xa816 || ($d0&65535)!=0x21b || g_appleLaunchState!=2
  echo FAIL AE original process call/event state\n
  detach
  quit 1
 end
 set $ae_sp=$sp
 set $ae_event=*(unsigned long*)$sp
 set $ae_d3=$d3
 set $ae_d4=$d4
 set $ae_d5=$d5
 set $ae_d6=$d6
 set $ae_d7=$d7
 set $ae_a2=$a2
 set $ae_a3=$a3
 set $ae_a4=$a4
 set $ae_a5=$a5
 set $ae_a6=$a6
 printf "AE_NATIVE_ENTER what=%X class=%X id=%X tick=%u sp=%X\n",*(unsigned short*)$ae_event,*(unsigned long*)($ae_event+2),*(unsigned long*)($ae_event+10),*(unsigned long*)($ae_event+6),$sp
 continue
end
break *($ae_engine+0x4ea)
commands
 silent
 if *(unsigned long*)$pc!=0x4e560000 || *(unsigned long*)($pc+4)!=0x426e0014 || *(unsigned long*)($pc+8)!=0x4e5e4e74 || *(unsigned short*)($pc+12)!=12
  echo FAIL AE original handler bytes\n
  detach
  quit 1
 end
 if g_appleLaunchState!=3 || g_appleCallbackDepth!=1 || g_macServiceActive || g_systemWindowActive || ($sr&0x2000)
  echo FAIL AE handler outside safe user-mode return\n
  detach
  quit 1
 end
 if $a5!=$ae_a5 || *(unsigned long*)($sp+4)!=0
  echo FAIL AE callback A5/refCon\n
  detach
  quit 1
 end
 set $ae_reply=*(unsigned long*)($sp+8)
 set $ae_desc=*(unsigned long*)($sp+12)
 set $ae_handle=*(unsigned long*)($ae_desc+4)
 if *(unsigned long*)$ae_reply!=0x6e756c6c || *(unsigned long*)($ae_reply+4)!=0 || *(unsigned long*)$ae_desc!=0x61657674 || !$ae_handle
  echo FAIL AE descriptor types/ownership\n
  detach
  quit 1
 end
 set $ae_data=*(unsigned long*)$ae_handle
 if !$ae_data || *(unsigned long*)$ae_data!=0x61657674 || *(unsigned long*)($ae_data+4)!=0x6f617070
  echo FAIL AE owned event identity\n
  detach
  quit 1
 end
 set $ae_handler_seen=$ae_handler_seen+1
 printf "AE_NATIVE_HANDLER user=1 active=0 depth=1 refCon=0 eventType=aevt replyType=null sp=%X\n",$sp
 continue
end
break *($ae_engine+0x21ea)
commands
 silent
 if $sp!=$ae_sp+4 || *(unsigned short*)$sp || $d0 || g_appleLaunchState!=4 || g_appleCallbackDepth || g_appleLaunchDelivered!=1 || $ae_handler_seen!=1
  echo FAIL AE process result/cleanup\n
  detach
  quit 1
 end
 if $d3!=$ae_d3 || $d4!=$ae_d4 || $d5!=$ae_d5 || $d6!=$ae_d6 || $d7!=$ae_d7 || $a2!=$ae_a2 || $a3!=$ae_a3 || $a4!=$ae_a4 || $a5!=$ae_a5 || $a6!=$ae_a6
  echo FAIL AE process preserved registers\n
  detach
  quit 1
 end
 set $ae_seen=$ae_seen+1
 echo PASS native launch Apple Event delivered=1 result=0 preserved=10 cleanup=4 user=1\n
 continue
end
break dispatchMacTrap if trap==0xa9eb && !inUserService
commands
 silent
 set $op=*(unsigned short*)userStack
 if $op==0x200e
  set $sane_mask=$sane_mask|1
 else
  if $op==0x1004
   set $sane_mask=$sane_mask|2
  else
   if $op==0x2000
    set $sane_mask=$sane_mask|4
   else
    if $op==0x16
     set $sane_mask=$sane_mask|8
    else
     if $op==0x2010
      set $sane_mask=$sane_mask|16
     else
      echo FAIL AE integrated SANE selector\n
      detach
      quit 1
     end
    end
   end
  end
 end
 set $sane_count=$sane_count+1
 continue
end
break aitdInputMenuProbeFinished
commands
 silent
 if $ae_seen!=1 || g_appleLaunchState || g_appleCallbackDepth || g_appleLaunchDelivered!=1 || $sane_count<10 || $sane_mask!=31
  echo FAIL AE integrated delivery/SANE/shutdown positive controls\n
  detach
  quit 1
 end
 printf "PASS integrated Apple delivery and five SANE operations calls=%u mask=%X\n",$sane_count,$sane_mask
 continue
end
source menu_keyboard.gdb
