set pagination off
set confirm off
break AitdScreen::showLoudStop
commands
 silent
 printf "FAIL ROOM3 %s / %s\n",manager,routine
 detach
 quit 1
end
break aitdInputLampCheckpoint
commands
 silent
 printf "ROOM3_PREFIX lamp=%u tick=%u\n",g_lampRouteStage,g_macTicks
 if g_lampRouteStage==65535
  echo FAIL ROOM3 lamp prerequisite\n
  detach
  quit 1
 end
 continue
end
break aitdInputExploreCheckpoint
commands
 silent
 set $world=(unsigned long)s_a5WorldStorage+75616
 set $actor=$world-0xb292+160
 printf "ROOM3_PREFIX explore=%u tick=%u room=%d floor=%d body=%d animation=%d track=%d x=%d z=%d beta=%d down=%u input=%d\n",g_exploreRouteStage,g_macTicks,*(short*)($actor+0x30),*(short*)($actor+0x2e),*(short*)($actor+2),*(short*)($actor+0x3e),*(short*)($actor+0x52),*(short*)($actor+0x1c),*(short*)($actor+0x20),*(short*)($actor+0x2a),s_keyDown[0x4d],*(short*)($world-0xd864)
 if g_exploreRouteStage==65535
  dump binary memory ../tmp/m3-room3/native-prefix-failure-a5.bin s_a5WorldStorage s_a5WorldStorage+75616
  dump binary memory ../tmp/m3-room3/native-prefix-failure-screen.bin s_colorScreen s_colorScreen+307200
  dump binary memory ../tmp/m3-room3/native-prefix-failure-clut.bin s_windowManagerColors s_windowManagerColors+2056
  echo FAIL ROOM3 exploration prerequisite\n
  detach
  quit 1
 end
 continue
end
break aitdInputCombatCheckpoint
commands
 silent
 set $world=(unsigned long)s_a5WorldStorage+75616
 set $actor=$world-0xb292+160
 set $vars=*(unsigned long*)($world-0xcbcc)
 printf "ROOM3_NATIVE stage=%u tick=%u room=%d floor=%d body=%d animation=%d track=%d health=%d action=%d frames=%u drops=%u\n",g_combatRouteStage,g_macTicks,*(short*)($actor+0x30),*(short*)($actor+0x2e),*(short*)($actor+2),*(short*)($actor+0x3e),*(short*)($actor+0x52),*(short*)($vars+42),*(short*)($vars+180),g_macSceneFramesCompleted,g_returnDroppedKeys
 if g_combatRouteStage==65535
  printf "ROOM3_FAILURE elapsed=%u attempts=%u kicks=%u x=%d z=%d beta=%u enemySlot=%d\n",g_macTicks-g_combatRouteTick,g_combatAttempts,g_combatKicks,*(short*)($actor+0x1c),*(short*)($actor+0x20),*(unsigned short*)($actor+0x2a),*(short*)($world-0x115f2+62*52)
  dump binary memory ../tmp/m3-room3/native-failure-a5.bin s_a5WorldStorage s_a5WorldStorage+75616
  dump binary memory ../tmp/m3-room3/native-failure-vars.bin $vars $vars+400
  dump binary memory ../tmp/m3-room3/native-failure-screen.bin s_colorScreen s_colorScreen+307200
  dump binary memory ../tmp/m3-room3/native-failure-clut.bin s_windowManagerColors s_windowManagerColors+2056
  echo FAIL ROOM3 phase guard\n
  detach
  quit 1
 end
 if g_combatRouteStage==42 || g_combatRouteStage==53 || g_combatRouteStage==66
  eval "dump binary memory ../tmp/m3-room3/native-%u-a5.bin %u %u",g_combatRouteStage,$world-75616,$world
  eval "dump binary memory ../tmp/m3-room3/native-%u-vars.bin %u %u",g_combatRouteStage,$vars,$vars+400
  eval "dump binary memory ../tmp/m3-room3/native-%u-screen.bin %u %u",g_combatRouteStage,(unsigned long)s_colorScreen,(unsigned long)s_colorScreen+307200
  eval "dump binary memory ../tmp/m3-room3/native-%u-clut.bin %u %u",g_combatRouteStage,(unsigned long)s_windowManagerColors,(unsigned long)s_windowManagerColors+2056
  if g_combatRouteStage==66
   echo PASS ROOM3 bathroom through living room4 bypass\n
   detach
   quit 0
  end
 end
 continue
end
continue
