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
 set $lampWorld=(unsigned long)s_a5WorldStorage+75616
 set $lampActor=$lampWorld-0xb292+160
 printf "ROOM3_PREFIX lamp=%u tick=%u x=%d z=%d beta=%u animation=%d track=%d\n",g_lampRouteStage,g_macTicks,*(short*)($lampActor+0x1c),*(short*)($lampActor+0x20),*(unsigned short*)($lampActor+0x2a),*(short*)($lampActor+0x3e),*(short*)($lampActor+0x52)
 if g_lampRouteStage==1
  set $lampVars=*(unsigned long*)($lampWorld-0xcbcc)
  printf "NEWGAME_NATIVE tick=%u room=%d floor=%d hp=%d inventory=%d\n",g_macTicks,*(short*)($lampActor+0x30),*(short*)($lampActor+0x2e),*(short*)($lampVars+42),*(short*)($lampWorld-0xd8a6)
  dump binary memory ../tmp/m3-newgame-circuit/current/recovery/newgame-a5.bin s_a5WorldStorage s_a5WorldStorage+75616
  dump binary memory ../tmp/m3-newgame-circuit/current/recovery/newgame-vars.bin $lampVars $lampVars+400
 end
 if g_lampRouteStage==65535
  dump binary memory ../tmp/m3-newgame-circuit/current/recovery/native-lamp-failure-a5.bin s_a5WorldStorage s_a5WorldStorage+75616
  dump binary memory ../tmp/m3-newgame-circuit/current/recovery/native-lamp-failure-screen.bin s_colorScreen s_colorScreen+307200
  dump binary memory ../tmp/m3-newgame-circuit/current/recovery/native-lamp-failure-clut.bin s_windowManagerColors s_windowManagerColors+2056
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
  dump binary memory ../tmp/m3-newgame-circuit/current/recovery/native-prefix-failure-a5.bin s_a5WorldStorage s_a5WorldStorage+75616
  dump binary memory ../tmp/m3-newgame-circuit/current/recovery/native-prefix-failure-screen.bin s_colorScreen s_colorScreen+307200
  dump binary memory ../tmp/m3-newgame-circuit/current/recovery/native-prefix-failure-clut.bin s_windowManagerColors s_windowManagerColors+2056
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
  dump binary memory ../tmp/m3-newgame-circuit/current/recovery/native-failure-a5.bin s_a5WorldStorage s_a5WorldStorage+75616
  dump binary memory ../tmp/m3-newgame-circuit/current/recovery/native-failure-vars.bin $vars $vars+400
  dump binary memory ../tmp/m3-newgame-circuit/current/recovery/native-failure-screen.bin s_colorScreen s_colorScreen+307200
  dump binary memory ../tmp/m3-newgame-circuit/current/recovery/native-failure-clut.bin s_windowManagerColors s_windowManagerColors+2056
  echo FAIL ROOM3 phase guard\n
  detach
  quit 1
 end
 if g_combatRouteStage==21 || g_combatRouteStage==22 || g_combatRouteStage==23 || g_combatRouteStage==66
  eval "dump binary memory ../tmp/m3-newgame-circuit/current/recovery/native-%u-a5.bin %u %u",g_combatRouteStage,$world-75616,$world
  eval "dump binary memory ../tmp/m3-newgame-circuit/current/recovery/native-%u-vars.bin %u %u",g_combatRouteStage,$vars,$vars+400
  eval "dump binary memory ../tmp/m3-newgame-circuit/current/recovery/native-%u-screen.bin %u %u",g_combatRouteStage,(unsigned long)s_colorScreen,(unsigned long)s_colorScreen+307200
  eval "dump binary memory ../tmp/m3-newgame-circuit/current/recovery/native-%u-clut.bin %u %u",g_combatRouteStage,(unsigned long)s_windowManagerColors,(unsigned long)s_windowManagerColors+2056
 end
 continue
end
break aitdInputRoom4RecoveryCheckpoint
commands
 silent
 set $world=(unsigned long)s_a5WorldStorage+75616
 set $actor=$world-0xb292+160
 set $vars=*(unsigned long*)($world-0xcbcc)
 set $slot=*(short*)($world-0x115f2+62*52)
 set $dx=0
 set $dz=0
 if $slot>=0 && $slot<50
  set $npc=$world-0xb292+$slot*160
  set $dx=*(short*)($npc+0x22)-*(short*)($actor+0x22)
  set $dz=*(short*)($npc+0x26)-*(short*)($actor+0x26)
 end
 printf "ROOM4_RECOVERY stage=%u combat=%u tick=%u room=%d floor=%d body=%d animation=%d track=%d hp=%d enemyHp=%d action=%d x=%d z=%d beta=%u dx=%d dz=%d drops=%u\n",g_room4RecoveryStage,g_combatRouteStage,g_macTicks,*(short*)($actor+0x30),*(short*)($actor+0x2e),*(short*)($actor+2),*(short*)($actor+0x3e),*(short*)($actor+0x52),*(short*)($vars+42),*(short*)($vars+114),*(short*)($vars+180),*(short*)($actor+0x1c),*(short*)($actor+0x20),*(unsigned short*)($actor+0x2a),$dx,$dz,g_returnDroppedKeys
 eval "dump binary memory ../tmp/m3-newgame-circuit/current/recovery/recovery-%u-a5.bin %u %u",g_room4RecoveryStage,$world-75616,$world
 eval "dump binary memory ../tmp/m3-newgame-circuit/current/recovery/recovery-%u-vars.bin %u %u",g_room4RecoveryStage,$vars,$vars+400
 if g_room4RecoveryStage==65535 || g_returnDroppedKeys!=0 || *(short*)($vars+42)<=0
  echo FAIL ROOM4 recovery living phase guard\n
  detach
  quit 1
 end
 if g_room4RecoveryStage==30
  dump binary memory ../tmp/m3-newgame-circuit/current/recovery/final-screen.bin s_colorScreen s_colorScreen+307200
  dump binary memory ../tmp/m3-newgame-circuit/current/recovery/final-clut.bin s_windowManagerColors s_windowManagerColors+2056
  if *(short*)($actor+0x30)!=5 || *(short*)($actor+0x3e)!=4 || *(short*)($actor+0x52)!=1 || *(short*)($vars+180)!=64 || *(short*)($world-0x115f2+62*52)!=-1
   echo FAIL ROOM4 recovery actual final state\n
   detach
   quit 1
  end
  echo PASS ROOM4 recovery living room4 fight and room5 Search\n
 end
 continue
end
set $aimCount=0
break aitdInputCombatAimCheckpoint
commands
 silent
 if g_room4RecoveryStage>=12 && g_room4RecoveryStage!=65535
  set $world=(unsigned long)s_a5WorldStorage+75616
  set $actor=$world-0xb292+160
  set $vars=*(unsigned long*)($world-0xcbcc)
  set $slot=*(short*)($world-0x115f2+62*52)
  set $dx=0
  set $dz=0
  if $slot>=0 && $slot<50
   set $npc=$world-0xb292+$slot*160
   set $dx=*(short*)($npc+0x22)-*(short*)($actor+0x22)
   set $dz=*(short*)($npc+0x26)-*(short*)($actor+0x26)
  end
  set $aimCount=$aimCount+1
  printf "ROOM4_AIM index=%u tick=%u room=%d animation=%d track=%d hp=%d x=%d z=%d beta=%u dx=%d dz=%d target=%u key=%d\n",$aimCount,g_macTicks,*(short*)($actor+0x30),*(short*)($actor+0x3e),*(short*)($actor+0x52),*(short*)($vars+42),*(short*)($actor+0x1c),*(short*)($actor+0x20),*(unsigned short*)($actor+0x2a),$dx,$dz,g_combatAimHeading,*(short*)($world-0x11af4)
  eval "dump binary memory ../tmp/m3-newgame-circuit/current/recovery/aim-%u-a5.bin %u %u",$aimCount,$world-75616,$world
  eval "dump binary memory ../tmp/m3-newgame-circuit/current/recovery/aim-%u-vars.bin %u %u",$aimCount,$vars,$vars+400
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
  eval "dump binary memory ../tmp/m3-newgame-circuit/current/circuit/cycle-%u-stage-%u-a5.bin %u %u",g_circuitCycle,g_circuitStage,$world-75616,$world
  eval "dump binary memory ../tmp/m3-newgame-circuit/current/circuit/cycle-%u-stage-%u-vars.bin %u %u",g_circuitCycle,g_circuitStage,$vars,$vars+400
  eval "dump binary memory ../tmp/m3-newgame-circuit/current/circuit/cycle-%u-stage-%u-screen.bin %u %u",g_circuitCycle,g_circuitStage,s_colorScreen,s_colorScreen+307200
  eval "dump binary memory ../tmp/m3-newgame-circuit/current/circuit/cycle-%u-stage-%u-clut.bin %u %u",g_circuitCycle,g_circuitStage,s_windowManagerColors,s_windowManagerColors+2056
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
