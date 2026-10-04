# ACTIONNAV=1: guest keyboard levels and VBI-owned mouse positions.
set pagination off
set confirm off
set $down=0
set $up=0
set $mouse=0
set $cancel=0
set $captured=0
if *(unsigned short*)((unsigned long)_start+0x58)!=0x4eb9 || *(unsigned long*)((unsigned long)_start+0x5a)!=(unsigned long)main
 echo FAIL ACTION NAV CRT return guard\n
 detach
 quit 1
end
break AitdScreen::showLoudStop
commands
 silent
 printf "FAIL ACTION NAV %s / %s\n",manager,routine
 detach
 quit 1
end
tbreak getFontNumber
continue
if *(unsigned long*)(s_segments[12].begin+0xc92)!=0x4e56ffee || *(unsigned short*)(s_segments[12].begin+0x8a8)!=0x4e75
 echo FAIL ACTION NAV original routine bytes\n
 detach
 quit 1
end
break *(s_segments[12].begin+0xc92) if g_actionNavStage
commands
 silent
 printf "ACTION_NAV_DRAW stage=%u tick=%u selection=%d keyTick=%u\n",g_actionNavStage,g_macTicks,*(short*)($sp+4),g_actionNavTick
 if g_actionNavStage==3 && *(short*)($sp+4)==1
  set $down=1
 end
 if g_actionNavStage==5 && *(short*)($sp+4)==0
  set $up=1
 end
 continue
end
break *(s_segments[12].begin+0x10ee) if g_actionNavStage==3 || g_actionNavStage==4 || g_actionNavStage==7
commands
 silent
 if (g_actionNavStage==3 || g_actionNavStage==4) && (short)$d4==1 && !$captured
  dump binary memory ../tmp/m3-action/native-nav-screen.bin s_colorScreen s_colorScreen+sizeof(s_colorScreen)
  dump binary memory ../tmp/m3-action/native-nav-clut.bin s_windowManagerColors s_windowManagerColors+sizeof(s_windowManagerColors)
  set $captured=1
 end
 if g_actionNavStage==7
  printf "ACTION_NAV_HOVER tick=%u selection=%d mouse=%d,%d samples=%u\n",g_macTicks,(short)$d4,*(short*)(s_portLowMemory+44),*(short*)(s_portLowMemory+42),g_mouseProbeSamples
  if (short)$d4==0 && *(short*)(s_portLowMemory+44)==410 && *(short*)(s_portLowMemory+42)==285 && g_mouseProbeSamples
   set $mouse=1
  end
 end
 continue
end
break *(s_segments[12].begin+0x8a8) if g_actionNavStage>=9
commands
 silent
 printf "ACTION_NAV_CANCEL tick=%u actions=%X room=%u\n",g_macTicks,*(unsigned short*)(s_currentA5-0xd868),*(unsigned short*)(s_currentA5-0xcd68)
 if *(unsigned short*)(s_currentA5-0xd868) || *(unsigned short*)(s_currentA5-0xcd68)
  echo FAIL ACTION NAV cancellation result\n
  detach
  quit 1
 end
 set $cancel=1
 continue
end
break *((unsigned long)_start+0x5e)
commands
 silent
 if !$down || !$up || !$mouse || !$cancel || !$captured || $d0 || g_macExitState!=4 || g_macLineAInstalled || g_macServiceActive || g_macServiceEntered!=g_macServiceCompleted || g_restoreViewMatches!=1 || g_systemWindowActive || g_fileOpenHandles || g_fileCloseErrors || g_resourceSourceOpen || g_overlaySourceOpen || g_resourceSourceCloseErrors || g_overlaySourceCloseErrors || g_restoreActualDmacon!=(g_restoreSavedDmacon&0x7ff) || g_restoreActualIntena!=((g_restoreSavedIntena&0x7fff)|0x4000) || g_probePaulaZeroedMask!=15
  printf "FAIL ACTION NAV controls down=%u up=%u mouse=%u cancel=%u exit=%u\n",$down,$up,$mouse,$cancel,g_macExitState
  detach
  quit 1
 end
 echo PASS native action navigation down up hover cancel quit\n
 detach
 quit 0
end
continue
