set pagination off
set confirm off
break AitdScreen::showLoudStop
commands
 silent
 printf "FAIL GAMEPLAY %s / %s\n",manager,routine
 detach
 quit 1
end
break aitdInputInGameCheckpoint
commands
 silent
 printf "BOOT_STAGE stage=%u tick=%u\n",g_ingameStage,g_macTicks
 continue
end
break aitdInputGameplayFightCheckpoint
commands
 silent
 printf "INPUT_FIGHT_EVENT tick=%u delivered=%u\n",g_macTicks,g_gameInputFightEvent
 continue
end
break aitdInputGameplayCheckpoint
commands
 silent
 set $world=(unsigned long)s_a5WorldStorage+75616
 set $actor=$world-0xb292+160
 printf "INPUT_ACCEPT stage=%u tick=%u anim=%d actions=%u room=%d floor=%d\n",g_gameInputStage,g_macTicks,*(short*)($actor+0x3e),*(unsigned short*)($world-0xd868),*(short*)($actor+0x30),*(short*)($actor+0x2e)
 if g_gameInputStage==65535
  echo FAIL GAMEPLAY command acceptance deadline\n
  detach
  quit 1
 end
 printf "INPUT_STAGE stage=%u tick=%u key=%d direction=%d action=%d\n",g_gameInputStage,g_macTicks,*(short*)($world-0x11af4),*(short*)($world-0x11af8),*(short*)($world-0x11af0)
 if g_gameInputStage==1
  dump binary memory ../tmp/m3-input/input-1-actors.bin $world-0xb292 $world-0xb292+16000
  dump binary memory ../tmp/m3-input/input-1-screen.bin s_colorScreen s_colorScreen+307200
  dump binary memory ../tmp/m3-input/input-1-clut.bin s_windowManagerColors s_windowManagerColors+2056
 end
 if g_gameInputStage==2
  dump binary memory ../tmp/m3-input/input-2-actors.bin $world-0xb292 $world-0xb292+16000
  dump binary memory ../tmp/m3-input/input-2-screen.bin s_colorScreen s_colorScreen+307200
  dump binary memory ../tmp/m3-input/input-2-clut.bin s_windowManagerColors s_windowManagerColors+2056
 end
 if g_gameInputStage==3
  dump binary memory ../tmp/m3-input/input-3-actors.bin $world-0xb292 $world-0xb292+16000
  dump binary memory ../tmp/m3-input/input-3-screen.bin s_colorScreen s_colorScreen+307200
  dump binary memory ../tmp/m3-input/input-3-clut.bin s_windowManagerColors s_windowManagerColors+2056
 end
 if g_gameInputStage==4
  dump binary memory ../tmp/m3-input/input-4-actors.bin $world-0xb292 $world-0xb292+16000
  dump binary memory ../tmp/m3-input/input-4-screen.bin s_colorScreen s_colorScreen+307200
  dump binary memory ../tmp/m3-input/input-4-clut.bin s_windowManagerColors s_windowManagerColors+2056
 end
 if g_gameInputStage==5
  dump binary memory ../tmp/m3-input/input-5-actors.bin $world-0xb292 $world-0xb292+16000
  dump binary memory ../tmp/m3-input/input-5-screen.bin s_colorScreen s_colorScreen+307200
  dump binary memory ../tmp/m3-input/input-5-clut.bin s_windowManagerColors s_windowManagerColors+2056
 end
 if g_gameInputStage==6
  dump binary memory ../tmp/m3-input/input-6-actors.bin $world-0xb292 $world-0xb292+16000
  dump binary memory ../tmp/m3-input/input-6-screen.bin s_colorScreen s_colorScreen+307200
  dump binary memory ../tmp/m3-input/input-6-clut.bin s_windowManagerColors s_windowManagerColors+2056
 end
 if g_gameInputStage==7
  dump binary memory ../tmp/m3-input/input-7-actors.bin $world-0xb292 $world-0xb292+16000
  dump binary memory ../tmp/m3-input/input-7-screen.bin s_colorScreen s_colorScreen+307200
  dump binary memory ../tmp/m3-input/input-7-clut.bin s_windowManagerColors s_windowManagerColors+2056
 end

 if g_gameInputStage==8
  dump binary memory ../tmp/m3-input/input-8-actors.bin $world-0xb292 $world-0xb292+16000
  dump binary memory ../tmp/m3-input/input-8-screen.bin s_colorScreen s_colorScreen+307200
  dump binary memory ../tmp/m3-input/input-8-clut.bin s_windowManagerColors s_windowManagerColors+2056
 end
 if g_gameInputStage==9
  dump binary memory ../tmp/m3-input/input-9-actors.bin $world-0xb292 $world-0xb292+16000
  dump binary memory ../tmp/m3-input/input-9-screen.bin s_colorScreen s_colorScreen+307200
  dump binary memory ../tmp/m3-input/input-9-clut.bin s_windowManagerColors s_windowManagerColors+2056
 end
 if g_gameInputStage==9
  printf "INPUT_TRAPS wait=%u next=%u keys=%u button=%u still=%u flush=%u systemclick=%u obscure=%u windows=%u\n",g_gameInputTraps[0],g_gameInputTraps[1],g_gameInputTraps[2],g_gameInputTraps[3],g_gameInputTraps[4],g_gameInputTraps[5],g_gameInputTraps[6],g_gameInputTraps[7],g_systemWindows
  if s_keyDown[0x4c] || s_keyDown[0x60] || s_keyDown[0x23] || s_keyDown[0x40]
   echo FAIL GAMEPLAY retained keys\n
   detach
   quit 1
  end
  echo PASS GAMEPLAY input sequence completed\n
  detach
  quit 0
 end
 continue
end
continue
printf "STOP_STATE boot=%u input=%u tick=%u key=%u\n",g_ingameStage,g_gameInputStage,g_macTicks,s_keyDown[0x40]
