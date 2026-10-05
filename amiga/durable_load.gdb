set pagination off
set confirm off
break AitdScreen::showLoudStop
commands
 silent
 printf "FAIL MENUS %s / %s trap=%X selector=%u segment=%u offset=%X\n",manager,routine,g_trapWord,g_trapSelector,g_trapSegment,g_trapOffset
 detach
 quit 1
end
tbreak *recordKey
continue
set $quit8_seen=0
break *(g_code3Base+0x1dcc)
commands
 silent
 if *(unsigned long*)(g_code3Base+0x1dc4)!=0x48780008 || *(unsigned long*)(g_code3Base+0x1dc8)!=0x206df954 || *(unsigned long*)(g_code3Base+0x1dcc)!=0x4e90588f || *(unsigned long*)$sp!=8
  echo FAIL driver8 caller bytes/request\n
  detach
  quit 1
 end
 set $quit8_sp=$sp
 set $quit8_d2=$d2
 set $quit8_d3=$d3
 set $quit8_d4=$d4
 set $quit8_d5=$d5
 set $quit8_d6=$d6
 set $quit8_d7=$d7
 set $quit8_a0=$a0
 set $quit8_a1=$a1
 set $quit8_a2=$a2
 set $quit8_a3=$a3
 set $quit8_a4=$a4
 set $quit8_a5=$a5
 set $quit8_a6=$a6
 printf "DRIVER8_NATIVE_ENTER sp=%X initialized=%u playing=%u owned=%u\n",$sp,g_soundDriver.initialized,g_song.playing,g_song.ownedCount
 dump binary memory ../tmp/m3-menu/driver8-native-enter-config.bin (char*)&g_soundDriver.songLimit (char*)&g_soundDriver.songs
 continue
end
break *(g_code3Base+0x1dce)
commands
 silent
 if $sp!=$quit8_sp || $d0!=0 || $d1!=1 || ($sr&31)!=4
  echo FAIL driver8 return ABI\n
  detach
  quit 1
 end
 if $d2!=$quit8_d2
  echo FAIL driver8 preserved d2\n
  detach
  quit 1
 end
 if $d3!=$quit8_d3
  echo FAIL driver8 preserved d3\n
  detach
  quit 1
 end
 if $d4!=$quit8_d4
  echo FAIL driver8 preserved d4\n
  detach
  quit 1
 end
 if $d5!=$quit8_d5
  echo FAIL driver8 preserved d5\n
  detach
  quit 1
 end
 if $d6!=$quit8_d6
  echo FAIL driver8 preserved d6\n
  detach
  quit 1
 end
 if $d7!=$quit8_d7
  echo FAIL driver8 preserved d7\n
  detach
  quit 1
 end
 if $a0!=$quit8_a0
  echo FAIL driver8 preserved a0\n
  detach
  quit 1
 end
 if $a1!=$quit8_a1
  echo FAIL driver8 preserved a1\n
  detach
  quit 1
 end
 if $a2!=$quit8_a2
  echo FAIL driver8 preserved a2\n
  detach
  quit 1
 end
 if $a3!=$quit8_a3
  echo FAIL driver8 preserved a3\n
  detach
  quit 1
 end
 if $a4!=$quit8_a4
  echo FAIL driver8 preserved a4\n
  detach
  quit 1
 end
 if $a5!=$quit8_a5
  echo FAIL driver8 preserved a5\n
  detach
  quit 1
 end
 if $a6!=$quit8_a6
  echo FAIL driver8 preserved a6\n
  detach
  quit 1
 end
 if g_soundDriver.initialized || g_song.playing || g_song.ownedCount || g_song.sampleCount || g_song.prepared || g_effects[0].chip || g_effects[1].chip || (*(unsigned short*)0xdff002&15)
  echo FAIL driver8 playback/resources/DMA\n
  detach
  quit 1
 end
 set $quit8_seen=1
 dump binary memory ../tmp/m3-menu/driver8-native-return-config.bin (char*)&g_soundDriver.songLimit (char*)&g_soundDriver.songs
 printf "PASS driver8 native ABI preserved=13 ccr=%u DMA=%u\n",$sr&31,*(unsigned short*)0xdff002&15
 continue
end
break aitdMenuKeyCheckpoint
commands
 silent
 printf "MENUKEY_NATIVE key=%X result=%X\n",g_menuProbeKey,g_menuProbeResult
 continue
end
break aitdMenuFeedbackCheckpoint
commands
 silent
 printf "MENU_FEEDBACK stage=%u length=%u tick=%u\n",g_menuFeedbackStage,g_menuFeedbackLength,g_macTicks
 eval "dump binary memory ../tmp/m3-menu/feedback-%u-text.bin %u %u",g_menuFeedbackStage,g_menuFeedbackText,g_menuFeedbackText+g_menuFeedbackLength
 eval "dump binary memory ../tmp/m3-menu/feedback-%u-screen.bin s_colorScreen s_colorScreen+307200",g_menuFeedbackStage
 eval "dump binary memory ../tmp/m3-menu/feedback-%u-clut.bin s_windowManagerColors s_windowManagerColors+2056",g_menuFeedbackStage
 continue
end
break aitdInputSaveLoadCheckpoint
commands
 silent
 set $world=(unsigned long)s_a5WorldStorage+75616
 set $actor=$world-0xb292+160
 printf "SAVELOAD_STATE stage=%u tick=%u x=%d z=%d anim=%d room=%d floor=%d saved=%d,%d closed=%u read=%u\n",g_saveLoadStage,g_macTicks,*(short*)($actor+0x1c),*(short*)($actor+0x20),*(short*)($actor+0x3e),*(short*)($actor+0x30),*(short*)($actor+0x2e),g_saveLoadSavedX,g_saveLoadSavedZ,g_saveLoadClosedBytes,g_saveLoadReadBytes
 eval "dump binary memory ../tmp/m3-saveload/durable-native-%u-actor.bin %u %u",g_saveLoadStage,$actor,$actor+160
 if g_saveLoadStage==65535
  echo FAIL SAVELOAD state deadline\n
  detach
  quit 1
 end
 continue
end
break aitdMenuProbeCheckpoint
commands
 silent
 if g_menuProbeStage==11
  if g_saveLoadStage!=6 || g_saveLoadClosedBytes!=0 || g_saveLoadReadBytes<10000
   echo FAIL SAVELOAD missing write/move/read/restore\n
   detach
   quit 1
  end
  if !$quit8_seen
   echo FAIL MENUS missing driver8 return\n
   detach
   quit 1
  end
  if g_soundDriver.initialized || g_song.playing || g_song.ownedCount || g_song.sampleCount || g_song.prepared || g_effects[0].chip || g_effects[1].chip
   echo FAIL MENUS retained audio resources\n
   detach
   quit 1
  end
  set $i=0
  while $i<4
   if g_soundDriver.channels[$i]!=-1
    echo FAIL MENUS retained audio channel\n
    detach
    quit 1
   end
   set $i=$i+1
  end
  printf "MENU_EXIT ok=%u linea=%u view=%u dma=%X/%X irq=%X/%X\n",g_menuProbeExitOK,g_macLineAInstalled,g_restoreViewMatches,g_restoreSavedDmacon,g_restoreActualDmacon,g_restoreSavedIntena,g_restoreActualIntena
  if !g_menuProbeExitOK || g_macLineAInstalled || g_macHostReturnSP || g_macServiceActive || g_systemWindowActive || g_macServiceEntered!=g_macServiceCompleted || g_macVBLCallbackEntry || g_restoreViewMatches!=1 || g_restoreActualDmacon!=(g_restoreSavedDmacon&0x7ff) || g_restoreActualIntena!=((g_restoreSavedIntena&0x7fff)|0x4000) || g_probePaulaZeroedMask!=15
   quit 1
  end
  echo PASS DURABLE LOAD restored saved state after abrupt restart and Quit\n
  detach
  quit 0
 end
 set $options=(unsigned long)*s_menuManager.entries[3].handle
 set $item1=$options+15+*(unsigned char*)($options+14)
 set $item2=$item1+5+*(unsigned char*)$item1
 printf "MENU_STAGE stage=%u tick=%u song=%u playing=%u effectMark=%u musicMark=%u menus=%u\n",g_menuProbeStage,g_macTicks,g_song.id,g_song.playing,*(unsigned char*)($item1+3+*(unsigned char*)$item1),*(unsigned char*)($item2+3+*(unsigned char*)$item2),s_menuManager.count
 if g_menuProbeStage==1
  dump binary memory ../tmp/m3-menu/native-1-screen.bin s_colorScreen s_colorScreen+307200
  dump binary memory ../tmp/m3-menu/native-1-clut.bin s_windowManagerColors s_windowManagerColors+2056
 end
 if g_menuProbeStage==2
  dump binary memory ../tmp/m3-menu/native-2-screen.bin s_colorScreen s_colorScreen+307200
  dump binary memory ../tmp/m3-menu/native-2-clut.bin s_windowManagerColors s_windowManagerColors+2056
 end
 if g_menuProbeStage==3
  dump binary memory ../tmp/m3-menu/native-3-screen.bin s_colorScreen s_colorScreen+307200
  dump binary memory ../tmp/m3-menu/native-3-clut.bin s_windowManagerColors s_windowManagerColors+2056
 end
 if g_menuProbeStage==4
  dump binary memory ../tmp/m3-menu/native-4-screen.bin s_colorScreen s_colorScreen+307200
  dump binary memory ../tmp/m3-menu/native-4-clut.bin s_windowManagerColors s_windowManagerColors+2056
 end
 if g_menuProbeStage==5
  dump binary memory ../tmp/m3-menu/native-5-screen.bin s_colorScreen s_colorScreen+307200
  dump binary memory ../tmp/m3-menu/native-5-clut.bin s_windowManagerColors s_windowManagerColors+2056
 end
 if g_menuProbeStage==6
  dump binary memory ../tmp/m3-menu/native-6-screen.bin s_colorScreen s_colorScreen+307200
  dump binary memory ../tmp/m3-menu/native-6-clut.bin s_windowManagerColors s_windowManagerColors+2056
 end
 if g_menuProbeStage==7
  dump binary memory ../tmp/m3-menu/native-7-screen.bin s_colorScreen s_colorScreen+307200
  dump binary memory ../tmp/m3-menu/native-7-clut.bin s_windowManagerColors s_windowManagerColors+2056
 end
 if g_menuProbeStage==8
  dump binary memory ../tmp/m3-menu/native-8-screen.bin s_colorScreen s_colorScreen+307200
  dump binary memory ../tmp/m3-menu/native-8-clut.bin s_windowManagerColors s_windowManagerColors+2056
 end
 if g_menuProbeStage==9
  dump binary memory ../tmp/m3-menu/native-9-screen.bin s_colorScreen s_colorScreen+307200
  dump binary memory ../tmp/m3-menu/native-9-clut.bin s_windowManagerColors s_windowManagerColors+2056
 end
 if g_menuProbeStage==10
  dump binary memory ../tmp/m3-menu/native-10-screen.bin s_colorScreen s_colorScreen+307200
  dump binary memory ../tmp/m3-menu/native-10-clut.bin s_windowManagerColors s_windowManagerColors+2056
 end
 continue
end
continue
printf "MENU_STOP stage=%u boot=%u tick=%u\n",g_menuProbeStage,g_ingameStage,g_macTicks
