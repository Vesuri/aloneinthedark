set pagination off
set confirm off
break AitdScreen::showLoudStop
commands
 silent
 printf "FAIL FIRSTFLOOR LOAD %s / %s\n",manager,routine
 detach
 quit 1
end
break aitdInputFirstFloorLoadCheckpoint
commands
 silent
 printf "FIRSTFLOOR_LOAD stage=%u tick=%u frames=%u read=%u\n",g_firstFloorLoadStage,g_macTicks,g_macSceneFramesCompleted,g_firstFloorLoadReadBytes
 if g_firstFloorLoadStage==1
  set $world=(unsigned long)s_a5WorldStorage+75616
  dump binary memory ../tmp/firstfloor-load-before-actor.bin $world-0xb292+160 $world-0xb292+320
 end
 if g_firstFloorLoadStage==3
  dump binary memory ../tmp/firstfloor-load-choice-screen.bin s_colorScreen s_colorScreen+307200
  dump binary memory ../tmp/firstfloor-load-choice-clut.bin s_windowManagerColors s_windowManagerColors+2056
 end
 if g_firstFloorLoadStage==5
  set $world=(unsigned long)s_a5WorldStorage+75616
  set $actor=$world-0xb292+160
  set $vars=*(unsigned long*)($world-0xcbcc)
  printf "FIRSTFLOOR_LOADED room=%d floor=%d x=%d z=%d beta=%d hp=%d action=%d read=%u\n",*(short*)($actor+0x30),*(short*)($actor+0x2e),*(short*)($actor+0x1c),*(short*)($actor+0x20),*(short*)($actor+0x2a),*(short*)($vars+42),*(short*)($vars+180),g_firstFloorLoadReadBytes
  dump binary memory ../tmp/firstfloor-load-a5.bin s_a5WorldStorage s_a5WorldStorage+75616
  dump binary memory ../tmp/firstfloor-load-vars.bin $vars $vars+400
  echo PASS native ordinary firstfloor checkpoint Load\n
  detach
  quit 0
 end
 if g_firstFloorLoadStage==65535
  echo FAIL FIRSTFLOOR ordinary Load\n
  detach
  quit 1
 end
 continue
end
continue
