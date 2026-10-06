set pagination off
set confirm off
break AitdScreen::showLoudStop
commands
 silent
 printf "FAIL CIRCUIT %s / %s\n",manager,routine
 detach
 quit 1
end
break aitdInputLampCheckpoint
commands
 silent
 if g_lampRouteStage==65535
  echo FAIL CIRCUIT lamp prerequisite\n
  detach
  quit 1
 end
 continue
end
break aitdInputExploreCheckpoint
commands
 silent
 if g_exploreRouteStage==65535
  echo FAIL CIRCUIT exploration prerequisite\n
  detach
  quit 1
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
  eval "dump binary memory ../tmp/firstfloor-circuit/cycle-%u-stage-%u-a5.bin %u %u",g_circuitCycle,g_circuitStage,$world-75616,$world
  eval "dump binary memory ../tmp/firstfloor-circuit/cycle-%u-stage-%u-vars.bin %u %u",g_circuitCycle,g_circuitStage,$vars,$vars+400
  eval "dump binary memory ../tmp/firstfloor-circuit/cycle-%u-stage-%u-screen.bin %u %u",g_circuitCycle,g_circuitStage,s_colorScreen,s_colorScreen+307200
  eval "dump binary memory ../tmp/firstfloor-circuit/cycle-%u-stage-%u-clut.bin %u %u",g_circuitCycle,g_circuitStage,s_windowManagerColors,s_windowManagerColors+2056
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
