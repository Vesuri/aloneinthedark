# Original menu calls; observation only, no writes to game memory/registers.
set pagination off
set width 0
set confirm off
source .run/startup-state.gdb
set $menu_seq=0
set $menu_inflight=0
break AitdScreen::showLoudStop
tbreak getFontNumber
continue
if s_segments[7].begin==0 || s_userService.trap!=0xa900
 echo FAIL native menu: initial font boundary\n
 detach
 quit 1
end
set $engine=s_segments[7].begin
if *(unsigned long*)($engine+0x2dee)!=0xa9503a1f || *(unsigned long*)($engine+0x2e0c)!=0xa946486e || *(unsigned long*)($engine+0x2ec2)!=0xa9476002
 echo FAIL native menu: original call bytes\n
 detach
 quit 1
end
printf "ARM native menu original Engine calls\n"
printf "MENU_ARM count=A9503A1F get=A946486E set=A9476002\n"
define menu_bytes
 set $word=0
 while $word<64
  printf "%08X",*(unsigned long*)($dump_address+$word*4)
  set $word=$word+1
 end
 printf "\n"
end
define menu_enter
 if $menu_inflight!=0
  echo FAIL native menu: nested call\n
  detach
  quit 1
 end
 set $menu_inflight=1
 set $menu_seq=$menu_seq+1
 set $menu_trap=$arg0
 set $menu_offset=$arg1
 set $menu_sp=$sp
 set $menu_item=0
 set $menu_text=0
 if $menu_trap==0xa950
  set $menu_handle=*(unsigned long*)$sp
 else
  set $menu_handle=*(unsigned long*)($sp+6)
  set $menu_item=*(unsigned short*)($sp+4)
  set $menu_text=*(unsigned long*)$sp
 end
 set $saved_d3=$d3
 set $saved_d4=$d4
 set $saved_d5=$d5
 set $saved_d6=$d6
 set $saved_d7=$d7
 set $saved_a2=$a2
 set $saved_a3=$a3
 set $saved_a4=$a4
 set $saved_a5=$a5
 set $saved_a6=$a6
 printf "MENU_ENTER seq=%X trap=%04X offset=%X menu=%04X item=%X sp=%X next=%08X d0=%08X d1=%08X d2=%08X d3=%08X d4=%08X d5=%08X d6=%08X d7=%08X a0=%08X a1=%08X a2=%08X a3=%08X a4=%08X a5=%08X a6=%08X\n",$menu_seq,$menu_trap,$menu_offset,*(unsigned short*)*(unsigned long*)$menu_handle,$menu_item,$sp,*(unsigned long*)($pc+2),$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
 printf "MENU_BEFORE seq=%X data=",$menu_seq
 set $dump_address=*(unsigned long*)$menu_handle
 menu_bytes
 if $menu_trap==0xa947
  printf "TEXT_BEFORE seq=%X data=",$menu_seq
  set $dump_address=$menu_text
  menu_bytes
 end
end
define menu_return
 if $menu_inflight!=1 || $d0!=0 || $sp!=$menu_sp+($menu_trap==0xa950?4:10) || $d3!=$saved_d3 || $d4!=$saved_d4 || $d5!=$saved_d5 || $d6!=$saved_d6 || $d7!=$saved_d7 || $a2!=$saved_a2 || $a3!=$saved_a3 || $a4!=$saved_a4 || $a5!=$saved_a5 || $a6!=$saved_a6
  echo FAIL native menu: return stack/registers\n
  detach
  quit 1
 end
 set $menu_result=0
 if $menu_trap==0xa950
  set $menu_result=*(unsigned short*)$sp
 end
 printf "MENU_RETURN seq=%X trap=%04X sp=%X expected=%X result=%04X d0=%08X d1=%08X d2=%08X d3=%08X d4=%08X d5=%08X d6=%08X d7=%08X a0=%08X a1=%08X a2=%08X a3=%08X a4=%08X a5=%08X a6=%08X\n",$menu_seq,$menu_trap,$sp,$menu_sp+($menu_trap==0xa950?4:10),$menu_result,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
 printf "MENU_AFTER seq=%X data=",$menu_seq
 set $dump_address=*(unsigned long*)$menu_handle
 menu_bytes
 if $menu_trap!=0xa950
  printf "TEXT_AFTER seq=%X data=",$menu_seq
  set $dump_address=$menu_text
  menu_bytes
 end
 set $menu_inflight=0
end
break *($engine+0x2dee)
commands
 silent
 menu_enter 0xa950 0x2dee
 continue
end
break *($engine+0x2df0)
commands
 silent
 menu_return
 continue
end
break *($engine+0x2e0c)
commands
 silent
 menu_enter 0xa946 0x2e0c
 continue
end
break *($engine+0x2e0e)
commands
 silent
 menu_return
 continue
end
break *($engine+0x2ec2)
commands
 silent
 menu_enter 0xa947 0x2ec2
 continue
end
break *($engine+0x2ec4)
commands
 silent
 menu_return
 continue
end
continue
if g_stageBState!=3 || g_trapWord!=0xa8aa || g_trapSegment!=9 || g_trapOffset!=0xe90 || *(unsigned long*)(g_trapRoutine+0)!=0x53454354 || *(unsigned long*)(g_trapRoutine+4)!=0x52454354 || *(unsigned char*)(g_trapRoutine+8)!=0 || $menu_seq!=32 || $menu_inflight!=0 || g_soundDriverCalls!=2 || g_macServiceActive!=0 || g_systemWindows!=$startup_windows || g_macServiceEntered!=$startup_entered || g_macServiceCompleted!=$startup_completed || g_resourceRuntimeReads!=62 || g_resourceRuntimeBytes!=265454 || g_overlayRuntimeReads!=31 || g_overlayRuntimeBytes!=80650
 printf "FAIL native menu: next %s/%s calls=%u\n",g_trapManager,g_trapRoutine,$menu_seq
 detach
 quit 1
end
printf "MENU_COUNTS app=%u/%u overlay=%u/%u windows=%u services=%u/%u lowmem=%u mask=%x resources=%u\n",g_resourceRuntimeReads,g_resourceRuntimeBytes,g_overlayRuntimeReads,g_overlayRuntimeBytes,g_systemWindows,g_macServiceEntered,g_macServiceCompleted,g_lowMemoryAppliedSites,g_loadedCodeMask,g_resourceCount
printf "PASS native menu calls=20 inflight=0 next=SECTRECT\n"
detach
quit 0
