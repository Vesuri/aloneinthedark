# Sourced at MacLoader::run; CODE 3 is not loaded until original LoadSeg runs.
# CODE 0 JT69: 03e0 3f3c 0003 a9f0 -> CODE 3+$03e4 (header-inclusive).
set pagination off
set confirm off
break AitdScreen::showLoudStop
commands
  silent
  if g_resourceExitPhase==3 && g_resourceExitPrepared==1 && g_resourceExitError==0 && g_resourceStageFault==1 && g_macExitState!=3 && g_macExitState!=4 && g_macServiceActive==1 && g_macServiceEntered==g_macServiceCompleted+1 && g_fileOpenHandles==1 && g_macLineAInstalled==1 && *(unsigned short *)(g_macLowMemory+140)==0xffdc && g_resourceExitHandle!=0 && *(unsigned long *)*(unsigned long *)g_resourceExitHandle==0x45584954
    printf "PASS resource-exit fault stop=%s resident=EXIT service=active stream=open\n",g_trapRoutine
    detach
    quit 0
  end
  if g_stageBState == 2
    printf "resource-exit FAIL loud stop: %s / %s CODE %u\n", g_trapManager, g_trapRoutine, g_trapSegment
  else
    printf "resource-exit FAIL loud stop: %s / %s CODE %u+$%04x\n", g_trapManager, g_trapRoutine, g_trapSegment, g_trapOffset
  end
  detach
  quit 1
end
# CODE 1+$AA is reached after CREL and before its original jump-table fill.
if g_startupCode == 0 || g_code3Base != 0 || g_loadedCodeMask != 3 || *(unsigned long *)(g_startupCode+0xaa) != 0x4eba013a
  echo resource-exit FAIL: startup residency or loader byte mismatch\n
  detach
  quit 1
end
set $exit_loaded=g_startupCode+0xaa
tbreak *$exit_loaded
continue
if $pc != (unsigned long)$exit_loaded || g_code3Base == 0 || g_loadedCodeMask != 11
  echo resource-exit FAIL: Core loader endpoint not reached\n
  detach
  quit 1
end
set $main=g_code3Base+0x3e4
if *(unsigned long *)(g_startupCode+0x48)!=0x2a6d0ee0 || *(unsigned long *)(g_startupCode+0x4c)!=0x206d006c || *(unsigned long *)(g_startupCode+0x50)!=0x4e90a9f4 || *(unsigned long *)($a5+0x6c)!=g_startupCode+0x4aa
 echo resource-exit FAIL: runtime exit byte guard\n
 detach
 quit 1
end
set $unpatch=g_startupCode+0x4aa
if *(unsigned long *)$unpatch!=0x226d0068 || *(unsigned long *)($unpatch+4)!=0x303ca9f0 || *(unsigned long *)($unpatch+8)!=0x20690008 || *(unsigned long *)($unpatch+12)!=0xa047303c || *(unsigned long *)($unpatch+16)!=0xa9f12069 || *(unsigned long *)($unpatch+20)!=0x0014a047 || *(unsigned long *)($unpatch+24)!=0x303ca9f4 || *(unsigned long *)($unpatch+28)!=0x20690020 || *(unsigned long *)($unpatch+32)!=0xa0472049 || *(unsigned long *)($unpatch+36)!=0xa01f4e75
 echo resource-exit FAIL: unpatch bytes\n
 detach
 quit 1
end
set $exit_phase=g_resourceExitPhase
tbreak *aitdResourceExitFixture
continue
if $pc!=(unsigned long)aitdResourceExitFixture || *(unsigned long *)$sp!=g_startupCode+0x48
 echo resource-exit FAIL: original return address\n
 detach
 quit 1
end
tbreak *aitdResourceExitFixtureFinished
continue
if *(unsigned long *)$main!=0x4e56ff00 || *(unsigned long *)($main+4)!=0x4ebafd7c
 echo resource-exit FAIL: restored Core bytes\n
 detach
 quit 1
end
printf "resource-exit fixture phase=%u prepared=%u step=%u error=%u d0=$%x\n",g_resourceExitPhase,g_resourceExitPrepared,g_resourceExitStep,g_resourceExitError,g_resourceLookupD0
if $pc!=(unsigned long)aitdResourceExitFixtureFinished || g_resourceExitPrepared!=1 || g_resourceExitError!=0 || g_resourceExitStep!=($exit_phase==2?0x1006:7)
 echo resource-exit FAIL: fixture\n
 detach
 quit 1
end
tbreak *aitd_user_exit_trampoline
continue
if $pc!=(unsigned long)aitd_user_exit_trampoline || g_macExitState!=3 || g_macServiceActive!=0 || g_macServiceEntered!=g_macServiceCompleted || g_fileOpenHandles!=0
 echo resource-exit FAIL: original runtime exit\n
 detach
 quit 1
end
tbreak *aitdResourceExitCleanupFinished
continue
printf "resource-exit cleanup state=%u ok=%u dma=$%x/$%x int=$%x/$%x view=%u service=%u/%u streams=%u source=%u\n",g_macExitState,g_resourceExitCleanupOK,g_restoreSavedDmacon,g_restoreActualDmacon,g_restoreSavedIntena,g_restoreActualIntena,g_restoreViewMatches,g_macServiceEntered,g_macServiceCompleted,g_fileOpenHandles,g_resourceSourceOpen
if $pc!=(unsigned long)aitdResourceExitCleanupFinished || g_macExitState!=4 || g_resourceExitCleanupOK!=1 || g_macHostReturnSP!=0 || g_macLineAInstalled!=0 || g_macServiceActive!=0 || g_macServiceEntered!=g_macServiceCompleted || g_fileOpenHandles!=0 || g_fileCloseErrors!=0 || g_resourceSourceOpen!=0 || g_resourceSourceCloseErrors!=0 || g_macVBLCallbackEntry!=0 || g_macVBLCallbackTask!=0 || g_macVBLCallbackA5!=0 || g_macVBLCallbackReturn!=0 || g_systemWindowActive!=0 || ((struct ExecBase*)SysBase)->TDNestCnt!=-1 || g_restoreActualDmacon!=(g_restoreSavedDmacon&0x07ff) || g_restoreActualIntena!=((g_restoreSavedIntena&0x7fff)|0x4000) || g_restoreViewMatches!=1 || g_probePaulaZeroedMask!=15
 echo resource-exit FAIL: restored state\n
 detach
 quit 1
end
if *(unsigned short *)((unsigned long)_start+0x58)!=0x4eb9 || *(unsigned long *)((unsigned long)_start+0x5a)!=(unsigned long)main || *(unsigned short *)((unsigned long)_start+0x82)!=0x4e75
 echo resource-exit FAIL: CRT return guard\n
 detach
 quit 1
end
tbreak *((unsigned long)_start+0x5e)
continue
if $pc!=(unsigned long)_start+0x5e || $d0!=0
 echo resource-exit FAIL: native main result\n
 detach
 quit 1
end
tbreak *((unsigned long)_start+0x82)
continue
if $pc!=(unsigned long)_start+0x82
 echo resource-exit FAIL: final CRT return not reached\n
 detach
 quit 1
end
printf "PASS resource-exit phase=%u original-return=1 restored=1 main-result=0 crt-return=1\n",$exit_phase
detach
quit 0
