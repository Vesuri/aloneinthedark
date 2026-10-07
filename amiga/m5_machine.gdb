source m5_snapshot.gdb
set pagination off
set confirm off
break AitdScreen::showLoudStop
commands
 silent
 echo FAIL M5 machine startup\n
 detach
 quit 1
end
break aitdInputFirstFloorLoadCheckpoint
commands
 silent
 if g_firstFloorLoadStage==65535
  echo FAIL M5 ordinary Load\n
  detach
  quit 1
 end
 if g_firstFloorLoadStage==5
  if g_m5Audit.cpuFlags!=7 || g_m5Audit.totalFast!=8388608 || g_m5Audit.accountingErrors || g_m5Audit.failures
   echo FAIL M5 machine identity or allocation\n
   detach
   quit 1
  end
  m5_snapshot
  echo PASS M5 reference 68030 OS-visible CPU/RAM and ordinary Load\n
  detach
  quit 0
 end
 continue
end
continue
