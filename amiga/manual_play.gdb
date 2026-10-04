# Read-only observer for the owner-operated M3.4 first-floor session.
# Build INGAME=1 PROBES=1, without GAMEINPUT or MENUPROBE.
# Duration is evidence, not acceptance: the owner must confirm room coverage.
set pagination off
set confirm off
set $manual_started=0
set $manual_tick=0
if *(unsigned short*)((unsigned long)_start+0x58)!=0x4eb9 || *(unsigned long*)((unsigned long)_start+0x5a)!=(unsigned long)main
 echo FAIL MANUAL CRT return guard\n
 detach
 quit 1
end
break AitdScreen::showLoudStop
commands
 silent
 printf "FAIL MANUAL %s / %s CODE %u+$%04x tick=%u elapsed=%u\n",g_trapManager,g_trapRoutine,g_trapSegment,g_trapOffset,g_macTicks,g_macTicks-$manual_tick
 printf "MANUAL_TRAP word=%X selector=%d stack=%X\n",g_trapWord,g_trapSelector,g_trapUserStack
 if g_trapWord==0xa0f8
  printf "MANUAL_DRIVER selector=%u argument=%u\n",*(unsigned long*)(g_trapUserStack+4),*(unsigned long*)(g_trapUserStack+8)
 end
 detach
 quit 1
end
break aitdInputInGameCheckpoint
commands
 silent
 if g_ingameStage==5
  if g_appleLaunchDelivered!=1 || g_appleLaunchState!=4 || g_appleCallbackDepth
   echo FAIL MANUAL launch delivery\n
   detach
   quit 1
  end
  set $manual_started=1
  set $manual_tick=g_macTicks
  printf "MANUAL_READY tick=%u launchDelivered=%u audio=%u\n",g_macTicks,g_appleLaunchDelivered,g_song.playing
 end
 continue
end
break *((unsigned long)_start+0x5e) if $manual_started
commands
 silent
 if $d0 || g_macExitState!=4 || g_macLineAInstalled || g_macServiceActive || g_macServiceEntered!=g_macServiceCompleted || g_systemWindowActive || g_resourceSourceOpen || g_overlaySourceOpen || g_resourceSourceCloseErrors || g_overlaySourceCloseErrors || g_appleLaunchState || g_appleCallbackDepth || g_appleLaunchDelivered!=1 || g_restoreViewMatches!=1 || g_restoreActualDmacon!=(g_restoreSavedDmacon&0x7ff) || g_restoreActualIntena!=((g_restoreSavedIntena&0x7fff)|0x4000)
  echo FAIL MANUAL shutdown restoration\n
  detach
  quit 1
 end
 printf "MANUAL_END tick=%u elapsedTicks=%u frames=%u delivered=%u services=%u/%u\n",g_macTicks,g_macTicks-$manual_tick,g_macFramesPresented,g_appleLaunchDelivered,g_macServiceEntered,g_macServiceCompleted
 echo MANUAL_PENDING owner confirmation of ten-minute first-floor coverage\n
 detach
 quit 0
end
continue
echo FAIL MANUAL unexpected debugger stop\n
detach
quit 1
