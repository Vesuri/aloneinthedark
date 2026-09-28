# Build with LINEAPROBE=1. This tests the native exception path, not game boot.
set pagination off
set confirm off
set $vector_seen=0
break aitd_line_a_probe
commands
  silent
  if g_macLineAInstalled != 1 || *(unsigned long *)g_macLineAVectorAddress != (unsigned long)aitd_line_a_handler
    echo line-a FAIL: vector not installed\n
    detach
    quit 1
  end
  set $vector_seen=1
  printf "line-a installed vector=$%08x old=$%08x handler=$%08x\n", g_macLineAVectorAddress, g_macSavedLineAVector, aitd_line_a_handler
  continue
end
break aitdLineAProbeComplete
continue
if $vector_seen != 1 || g_lineAProbe[6] != 1 || g_lineAProbe[7] != 1
  echo line-a FAIL: vector/stack restoration\n
  detach
  quit 1
end
if g_lineAProbe[0] != (unsigned long)g_macStackBase+65536-4 || g_lineAProbe[1] != 0x12345678
  echo line-a FAIL: Mac stack or A5\n
  detach
  quit 1
end
if (g_lineAProbe[2]&31) != 20 || (g_lineAProbe[3]&31) != 16 || (g_lineAProbe[4]&31) != 24 || (g_lineAProbe[5]&31) != 31
  printf "line-a FAIL: CCR=%x/%x/%x/%x\n",g_lineAProbe[2],g_lineAProbe[3],g_lineAProbe[4],g_lineAProbe[5]
  detach
  quit 1
end
if (g_lineAProbe[8]&31) != 20 || g_lineAProbe[9] != 1
  echo line-a FAIL: callback clobbered CCR or did not run\n
  detach
  quit 1
end
if g_lineAProbe[39] != 0 || g_lineAProbe[40] != 0 || g_lineAProbe[41] != 0
 echo line-a FAIL: cache services\n
 detach
 quit 1
end
if g_lineAProbe[14] != 0x89aba155 || g_lineAProbe[15] != 0x01230155 || g_lineAProbe[16] != (unsigned long)aitd_patch_second_return || g_lineAProbe[17] != 0xabcdef00 || g_lineAProbe[18] != 2
 echo line-a FAIL: OS patch input/original forwarding\n
 detach
 quit 1
end
define check_os_patch_return
 if g_lineAProbe[$arg0] != 0xffffff94 || g_lineAProbe[$arg0+1] != 0x89abcdef || g_lineAProbe[$arg0+2] != 0x01234567 || g_lineAProbe[$arg0+3] != $arg1 || g_lineAProbe[$arg0+4] != 0x55667788 || g_lineAProbe[$arg0+5] != 0x33445566 || (g_lineAProbe[$arg0+6]>>16 & 31) != 24 || g_lineAProbe[$arg0+7] != g_lineAProbe[38]
  echo line-a FAIL: OS patch return ABI\n
  x/40wx g_lineAProbe
  detach
  quit 1
 end
end
check_os_patch_return 19 0x11223344
check_os_patch_return 27 0x2468ace0
if g_lineAProbe[37] != 1 || g_lineAProbe[36] != g_lineAProbe[38] || g_lineAProbe[35] == 0 || *(unsigned long *)g_lineAProbe[35] != (unsigned long)g_startupCode
 echo line-a FAIL: Toolbox patch original/parameters/result/stack\n
 detach
 quit 1
end
echo line-a patches PASS: OS input/restore/A0-flags/CCR originals=2 Toolbox originals=1 stack-balanced\n
break AitdScreen::showLoudStop
continue
if g_lineAProbe[10] == 0 || g_lineAProbe[10]-g_lineAProbe[11] != 75616
  echo line-a FAIL: CurrentA5/CurStackBase shadows\n
  detach
  quit 1
end
printf "line-a shadows CurrentA5=$%08x CurStackBase=$%08x callback-CCR=$%x\n", g_lineAProbe[10], g_lineAProbe[11], g_lineAProbe[8]&31
printf "line-a PASS: stack=65536 A5=12345678 CCR=%x/%x/%x/%x restored=%u/%u selector-low-word=1\n",g_lineAProbe[2]&31,g_lineAProbe[3]&31,g_lineAProbe[4]&31,g_lineAProbe[5]&31,g_lineAProbe[6],g_lineAProbe[7]
detach
quit 0
