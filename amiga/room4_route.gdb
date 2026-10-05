set pagination off
set confirm off
break AitdScreen::showLoudStop
commands
 silent
 printf "FAIL ROOM4 %s / %s\n",manager,routine
 detach
 quit 1
end
break aitdInputLampCheckpoint
commands
 silent
 printf "ROOM4_PREFIX lamp=%u tick=%u\n",g_lampRouteStage,g_macTicks
 if g_lampRouteStage==65535
  echo FAIL ROOM4 lamp prerequisite\n
  detach
  quit 1
 end
 continue
end
break aitdInputExploreCheckpoint
commands
 silent
 printf "ROOM4_PREFIX explore=%u tick=%u\n",g_exploreRouteStage,g_macTicks
 if g_exploreRouteStage==65535
  echo FAIL ROOM4 exploration prerequisite\n
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
 printf "ROOM4_NATIVE stage=%u tick=%u room=%d floor=%d body=%d animation=%d track=%d health=%d action=%d frames=%u drops=%u\n",g_combatRouteStage,g_macTicks,*(short*)($actor+0x30),*(short*)($actor+0x2e),*(short*)($actor+2),*(short*)($actor+0x3e),*(short*)($actor+0x52),*(short*)($vars+42),*(short*)($vars+180),g_macSceneFramesCompleted,g_returnDroppedKeys
 if g_combatRouteStage==65535
  dump binary memory ../tmp/m3-room4/native-failure-a5.bin s_a5WorldStorage s_a5WorldStorage+75616
  echo FAIL ROOM4 phase guard\n
  detach
  quit 1
 end
 if g_combatRouteStage==42 || g_combatRouteStage==53
  eval "dump binary memory ../tmp/m3-room4/native-%u-a5.bin %u %u",g_combatRouteStage,$world-75616,$world
  eval "dump binary memory ../tmp/m3-room4/native-%u-vars.bin %u %u",g_combatRouteStage,$vars,$vars+400
  eval "dump binary memory ../tmp/m3-room4/native-%u-screen.bin %u %u",g_combatRouteStage,(unsigned long)s_colorScreen,(unsigned long)s_colorScreen+307200
  eval "dump binary memory ../tmp/m3-room4/native-%u-clut.bin %u %u",g_combatRouteStage,(unsigned long)s_windowManagerColors,(unsigned long)s_windowManagerColors+2056
  if g_combatRouteStage==53
   echo PASS ROOM4 bypass room5-room4-western hallway living manual gameplay\n
   detach
   quit 0
  end
 end
 continue
end
continue
