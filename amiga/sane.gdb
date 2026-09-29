set pagination off
set confirm off
set width 0
source .run/startup-state.gdb
set $sane_seq=0
set $sane_inflight=0
break AitdScreen::showLoudStop
tbreak getFontNumber
continue
set $engine=s_segments[7].begin
define sane_enter
 if $sane_inflight!=0 || *(unsigned short*)$pc!=0xa9eb
  echo FAIL SANE entry/original opcode\n
  detach
  quit 1
 end
 set $sane_seq=$sane_seq+1
 set $sane_inflight=1
 set $sane_sp=$sp
 set $sane_sr=$sr
 set $sane_op=*(unsigned short*)$sp
 set $sane_dest=*(unsigned long*)($sp+2)
 set $sane_source=$sane_dest
 if $sane_op!=0x16
  set $sane_source=*(unsigned long*)($sp+6)
 end
 printf "SANE_ENTER seq=%X offset=%X sp=%X op=%X dest=%X source=%X fp=%X d0=%08X d1=%08X d2=%08X d3=%08X d4=%08X d5=%08X d6=%08X d7=%08X a0=%08X a1=%08X a2=%08X a3=%08X a4=%08X a5=%08X a6=%08X sr=%X\n",$sane_seq,$pc-$engine,$sp,$sane_op,$sane_dest,$sane_source,*(unsigned short*)(s_portLowMemory+56),$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6,$sr
 printf "SANE_DEST_BEFORE seq=%X data=%08X%08X%08X\n",$sane_seq,*(unsigned long*)$sane_dest,*(unsigned long*)($sane_dest+4),*(unsigned long*)($sane_dest+8)
 printf "SANE_SOURCE seq=%X data=%08X%08X%08X\n",$sane_seq,*(unsigned long*)$sane_source,*(unsigned long*)($sane_source+4),*(unsigned long*)($sane_source+8)
end
define sane_return
 if $sane_inflight!=1 || $sp!=$sane_sp+($sane_op==0x16 ? 6 : 10) || (*(unsigned short*)$sane_frame&31)!=($sane_sr&31)
  echo FAIL SANE return/stack/native CCR\n
  detach
  quit 1
 end
 printf "SANE_RETURN seq=%X sp=%X fp=%X d0=%08X d1=%08X d2=%08X d3=%08X d4=%08X d5=%08X d6=%08X d7=%08X a0=%08X a1=%08X a2=%08X a3=%08X a4=%08X a5=%08X a6=%08X sr=%X\n",$sane_seq,$sp,*(unsigned short*)(s_portLowMemory+56),$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6,$sr
 printf "SANE_DEST_AFTER seq=%X data=%08X%08X%08X\n",$sane_seq,*(unsigned long*)$sane_dest,*(unsigned long*)($sane_dest+4),*(unsigned long*)($sane_dest+8)
 printf "SANE_FRAME_RETURN seq=%X sr=%X\n",$sane_seq,*(unsigned short*)$sane_frame
 set $sane_inflight=0
end
tbreak *($engine+0x479e)
continue
printf "POSITION_INPUT shadow=%d instruction=%08X rect=%08X%08X selected=%X main=%X\n",*(short*)(s_portLowMemory+156),*(unsigned long*)$pc,*(unsigned long*)($a6-8),*(unsigned long*)($a6-4),*(unsigned long*)($a6+16),$a4
tbreak *($engine+0x47c2)
continue
while $sane_seq<10
 sane_enter
 set $sane_return_pc=$pc+2
 tbreak dispatchMacTrap if trap==0xa9eb
 continue
 set $sane_frame=frame
 set $sane_sr=*(unsigned short*)frame
 printf "SANE_FRAME seq=%X sr=%X\n",$sane_seq,$sane_sr
 tbreak *$sane_return_pc
 continue
 sane_return
 if $sane_seq<10
  if $sane_seq==1
   set $next=0x47d0
  end
  if $sane_seq==2
   set $next=0x47de
  end
  if $sane_seq==3
   set $next=0x47e8
  end
  if $sane_seq==4
   set $next=0x47f6
  end
  if $sane_seq==5
   set $next=0x481e
  end
  if $sane_seq==6
   set $next=0x482c
  end
  if $sane_seq==7
   set $next=0x483a
  end
  if $sane_seq==8
   set $next=0x4844
  end
  if $sane_seq==9
   set $next=0x4852
  end
  tbreak *($engine+$next)
  continue
 end
end
tbreak *($engine+0x48a2)
continue
printf "SANE_POSITION front=%X vertical=%d horizontal=%d\n",*(unsigned char*)$sp,*(short*)($sp+2),*(short*)($sp+4)
if *(unsigned short*)$pc!=0xa91b || *(unsigned char*)$sp!=0 || *(short*)($sp+2)!=205 || *(short*)($sp+4)!=177
 echo FAIL original positioning result\n
 detach
 quit 1
end
continue
printf "SANE_NEXT state=%u trap=%X selector=%X segment=%u offset=%X routine=%s windows=%u services=%u/%u calls=%u\n",g_stageBState,g_trapWord,g_trapSelector,g_trapSegment,g_trapOffset,g_trapRoutine,g_systemWindows,g_macServiceEntered,g_macServiceCompleted,$sane_seq
if g_stageBState!=3 || g_trapWord!=0xa816 || g_trapSegment!=7 || g_trapOffset!=0x1038 || $sane_seq!=10 || $sane_inflight!=0 || g_macServiceActive!=0 || g_trapSelector!=0x91f || g_systemWindows!=$startup_windows || g_macServiceEntered!=$startup_entered || g_macServiceCompleted!=$startup_completed || g_resourceRuntimeReads!=28 || g_resourceRuntimeBytes!=123387
 echo FAIL original SANE progression\n
 detach
 quit 1
end
echo PASS native SANE positioning calls=A\n
detach
quit 0
