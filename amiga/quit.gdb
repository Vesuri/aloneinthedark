set pagination off
set confirm off
set stack-cache off
set code-cache off
set $exit_seen=0
set $cleanup_seen=0
printf "QUIT_START workbench=%u\n",g_quitWorkbench
break AitdScreen::showLoudStop
commands
 silent
 printf "FAIL QUIT loud stop %s / %s\n",manager,routine
 detach
 quit 1
end
break aitdMenuProbeCheckpoint
commands
 silent
 printf "QUIT_MENU stage=%u ticks=%u frames=%u\n",g_menuProbeStage,g_macTicks,g_macSceneFramesCompleted
 if g_menuProbeStage==10
  set $exit_seen=1
 end
 continue
end
break aitdQuitCheckpoint
commands
 silent
 printf "QUIT_RETURN stage=%u result=%u workbench=%u chip=%u fast=%u errors=%u files=%u\n",g_quitStage,g_quitResult,g_quitWorkbench,g_m5Audit.liveChip,g_m5Audit.liveFast,g_m5Audit.accountingErrors,g_fileOpenHandles
 if g_quitStage==2
  if !$exit_seen || g_menuProbeStage!=11 || !g_menuProbeExitOK || g_quitResult || g_m5Audit.liveChip || g_m5Audit.liveFast || g_m5Audit.accountingErrors || g_m5Audit.failures || g_fileOpenHandles || g_fileCloseErrors || g_resourceSourceOpen || g_overlaySourceOpen || g_resourceSourceCloseErrors || g_overlaySourceCloseErrors
   echo FAIL QUIT owned resource ledger\n
   detach
   quit 1
  end
  if g_applicationZoneBase || g_systemZoneBase || g_macStackBase || g_macLineAInstalled || g_macHostReturnSP || g_macServiceActive || g_systemWindowActive || g_macServiceEntered!=g_macServiceCompleted || g_macVBLCallbackEntry || (unsigned long)'GCCRuntime.cpp'::GfxBase || (unsigned long)'GCCRuntime.cpp'::DOSBase || (unsigned long)'M5Audit.cpp'::TimerBase
   echo FAIL QUIT retained service/library/zone\n
   detach
   quit 1
  end
  if g_musicTimerSource || g_soundDriver.initialized || g_song.playing || g_song.ownedCount || g_song.sampleCount || g_song.prepared || g_effects[0].chip || g_effects[1].chip
   echo FAIL QUIT retained audio\n
   detach
   quit 1
  end
  set $i=0
  while $i<4
   if g_soundDriver.channels[$i]!=-1
    echo FAIL QUIT audio channel\n
    detach
    quit 1
   end
   set $i=$i+1
  end
  printf "QUIT_OS view=%u dma=%X/%X irq=%X/%X paula=%u\n",g_restoreViewMatches,g_restoreSavedDmacon,g_restoreActualDmacon,g_restoreSavedIntena,g_restoreActualIntena,g_probePaulaZeroedMask
  if g_restoreViewMatches!=1 || g_restoreActualDmacon!=(g_restoreSavedDmacon&0x7ff) || g_restoreActualIntena!=((g_restoreSavedIntena&0x7fff)|0x4000) || g_probePaulaZeroedMask!=15
   echo FAIL QUIT OS restoration\n
   detach
   quit 1
  end
  set $linea_ok=(*(unsigned long*)g_macLineAVectorAddress==g_macSavedLineAVector)
  set $vertb_ok=(SysBase->IntVects[5].iv_Data=='PlatformAmiga.cpp'::s_savedVertb.iv_Data && SysBase->IntVects[5].iv_Code=='PlatformAmiga.cpp'::s_savedVertb.iv_Code && SysBase->IntVects[5].iv_Node=='PlatformAmiga.cpp'::s_savedVertb.iv_Node)
  set $keyboard_ok=('MacInput.cpp'::s_ciaaBase==0 && 'MacInput.cpp'::s_savedVector==0)
  set $timer_ok=('M5Audit.cpp'::s_port==0)
  printf "QUIT_VECTORS linea=%u vertb=%u keyboard=%u timer=%u\n",$linea_ok,$vertb_ok,$keyboard_ok,$timer_ok
  if !$linea_ok || !$vertb_ok || !$keyboard_ok || !$timer_ok
   echo FAIL QUIT vectors or owned device port\n
   detach
   quit 1
  end
  set $cleanup_seen=1
 end
 if g_quitStage==3
  if !$cleanup_seen
   echo FAIL QUIT missing cleanup checkpoint\n
   detach
   quit 1
  end
  echo PASS QUIT original exit, empty ledgers, closed libraries and restored OS\n
  detach
  quit 0
 end
 continue
end
continue
