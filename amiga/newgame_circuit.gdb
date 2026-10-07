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
 if g_lampRouteStage==1
  set $world=(unsigned long)s_a5WorldStorage+75616
  set $actor=$world-0xb292+160
  set $vars=*(unsigned long*)($world-0xcbcc)
  printf "NEWGAME_NATIVE tick=%u room=%d floor=%d hp=%d inventory=%d\n",g_macTicks,*(short*)($actor+0x30),*(short*)($actor+0x2e),*(short*)($vars+42),*(short*)($world-0xd8a6)
  dump binary memory ../tmp/m3-newgame-direct/current/prefix/newgame-a5.bin s_a5WorldStorage s_a5WorldStorage+75616
  dump binary memory ../tmp/m3-newgame-direct/current/prefix/newgame-vars.bin $vars $vars+400
 end
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
  dump binary memory ../tmp/m3-newgame-direct/current/prefix/native-prefix-failure-a5.bin s_a5WorldStorage s_a5WorldStorage+75616
  dump binary memory ../tmp/m3-newgame-direct/current/prefix/native-prefix-failure-screen.bin s_colorScreen s_colorScreen+307200
  dump binary memory ../tmp/m3-newgame-direct/current/prefix/native-prefix-failure-clut.bin s_windowManagerColors s_windowManagerColors+2056
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
  dump binary memory ../tmp/m3-newgame-direct/current/prefix/native-failure-a5.bin s_a5WorldStorage s_a5WorldStorage+75616
  dump binary memory ../tmp/m3-newgame-direct/current/prefix/native-failure-vars.bin $vars $vars+400
  dump binary memory ../tmp/m3-newgame-direct/current/prefix/native-failure-screen.bin s_colorScreen s_colorScreen+307200
  dump binary memory ../tmp/m3-newgame-direct/current/prefix/native-failure-clut.bin s_windowManagerColors s_windowManagerColors+2056
  echo FAIL ROOM3 phase guard\n
  detach
  quit 1
 end
 if g_combatRouteStage==21 || g_combatRouteStage==22 || g_combatRouteStage==23 || g_combatRouteStage==42 || g_combatRouteStage==53 || g_combatRouteStage==66
  eval "dump binary memory ../tmp/m3-newgame-direct/current/prefix/native-%u-a5.bin %u %u",g_combatRouteStage,$world-75616,$world
  eval "dump binary memory ../tmp/m3-newgame-direct/current/prefix/native-%u-vars.bin %u %u",g_combatRouteStage,$vars,$vars+400
  eval "dump binary memory ../tmp/m3-newgame-direct/current/prefix/native-%u-screen.bin %u %u",g_combatRouteStage,(unsigned long)s_colorScreen,(unsigned long)s_colorScreen+307200
  eval "dump binary memory ../tmp/m3-newgame-direct/current/prefix/native-%u-clut.bin %u %u",g_combatRouteStage,(unsigned long)s_windowManagerColors,(unsigned long)s_windowManagerColors+2056
  if g_combatRouteStage==66
   echo PASS ROOM3 bathroom through living room4 bypass\n

  end
 end
 continue
end
break aitdInputExploreAlignCheckpoint
commands
 silent
 if g_combatRouteStage==53
  set $world=(unsigned long)s_a5WorldStorage+75616
  set $actor=$world-0xb292+160
  printf "HALL_ALIGNMENT phase=%u tick=%u room=%d z=%d animation=%d up=%u down=%u\n",g_exploreAlignment,g_macTicks,*(short*)($actor+0x30),*(short*)($actor+0x20),*(short*)($actor+0x3e),s_keyDown[0x4c],s_keyDown[0x4d]
 end
 continue
end
break aitdInputCircuitCheckpoint
commands
 silent
 set $world=(unsigned long)s_a5WorldStorage+75616
 set $actor=$world-0xb292+160
 set $vars=*(unsigned long*)($world-0xcbcc)
 printf "CIRCUIT_NATIVE cycle=%u stage=%u tick=%u room=%d floor=%d body=%d animation=%d track=%d x=%d z=%d beta=%d hp=%d enemyHp=%d npc=%d action=%d frames=%u active=%u move=%u turn=%u kick=%u samples=%u drops=%u attempts=%u\n",g_circuitCycle,g_circuitStage,g_macTicks,*(short*)($actor+0x30),*(short*)($actor+0x2e),*(short*)($actor+2),*(short*)($actor+0x3e),*(short*)($actor+0x52),*(short*)($actor+0x1c),*(short*)($actor+0x20),*(short*)($actor+0x2a),*(short*)($vars+42),*(short*)($vars+80),*(short*)($world-0x115f2+35*52),*(short*)($vars+180),g_macSceneFramesCompleted,g_activeGameplayTicks,g_activeMoveTicks,g_activeTurnTicks,g_activeKickTicks,g_activeGameplaySamples,g_returnDroppedKeys,g_circuitAttempts
 if g_circuitStage==2 || g_circuitStage==8 || g_circuitStage==12 || g_circuitStage==21 || g_circuitStage==24 || g_circuitStage==35 || g_circuitStage==36 || g_circuitStage==41 || g_circuitStage==45 || g_circuitStage==54 || g_circuitStage==61 || g_circuitStage==72 || g_circuitStage==65535 || g_circuitStage==65534
  eval "dump binary memory ../tmp/m3-newgame-direct/current/circuit/cycle-%u-stage-%u-a5.bin %u %u",g_circuitCycle,g_circuitStage,$world-75616,$world
  eval "dump binary memory ../tmp/m3-newgame-direct/current/circuit/cycle-%u-stage-%u-vars.bin %u %u",g_circuitCycle,g_circuitStage,$vars,$vars+400
  eval "dump binary memory ../tmp/m3-newgame-direct/current/circuit/cycle-%u-stage-%u-screen.bin %u %u",g_circuitCycle,g_circuitStage,s_colorScreen,s_colorScreen+307200
  eval "dump binary memory ../tmp/m3-newgame-direct/current/circuit/cycle-%u-stage-%u-clut.bin %u %u",g_circuitCycle,g_circuitStage,s_windowManagerColors,s_windowManagerColors+2056
 end
 if g_circuitStage==65535 || g_returnDroppedKeys!=0
  echo FAIL CIRCUIT living phase guard or dropped input\n
  detach
  quit 1
 end
 if g_circuitStage==65534
  echo PASS native continuous firstfloor circuit\n
  detach
  quit 0
 end
 continue
end
continue
