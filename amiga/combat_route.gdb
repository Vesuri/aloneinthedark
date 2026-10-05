set pagination off
set confirm off
break AitdScreen::showLoudStop
commands
 silent
 printf "FAIL COMBAT %s / %s trap=%X selector=%u segment=%u offset=%X\n",manager,routine,g_trapWord,g_trapSelector,g_trapSegment,g_trapOffset
 detach
 quit 1
end
break aitdInputLampCheckpoint
commands
 silent
 set $world=(unsigned long)s_a5WorldStorage+75616
 set $actor=$world-0xb292+160
 printf "LAMP_USE_STATE stage=%u body=%d selected=%d track=%d\n",g_lampRouteStage,*(short*)($actor+2),*(short*)($world-0xd8a8),*(short*)($actor+0x52)
 set $lamp=$world-0x115f2+13*52
 printf "LAMP_NATIVE stage=%u tick=%u x=%d z=%d beta=%d anim=%d flags=%X count=%d slot0=%d slot1=%d objectFloor=%d objectRoom=%d frames=%u\n",g_lampRouteStage,g_macTicks,*(short*)($actor+0x1c),*(short*)($actor+0x20),*(short*)($actor+0x2a),*(short*)($actor+0x3e),*(unsigned short*)($lamp+12),*(short*)($world-0xd8a6),*(short*)($world-0xd8a4),*(short*)($world-0xd8a2),*(short*)($lamp+28),*(short*)($lamp+30),g_macSceneFramesCompleted
 eval "dump binary memory ../tmp/m3-combat/key-session-lamp-use-native-%u-a5.bin %u %u",g_lampRouteStage,$world-75616,$world
 if g_lampRouteStage==65535
  dump binary memory ../tmp/m3-combat/combat-lamp-fail-screen.bin s_colorScreen s_colorScreen+307200
  dump binary memory ../tmp/m3-combat/combat-lamp-fail-clut.bin s_windowManagerColors s_windowManagerColors+2056
  echo FAIL LAMP phase deadline\n
  detach
  quit 1
 end
 if g_lampRouteStage==25
  dump binary memory ../tmp/m3-combat/key-session-lamp-use-feedback-screen.bin s_colorScreen s_colorScreen+307200
  dump binary memory ../tmp/m3-combat/key-session-lamp-use-feedback-clut.bin s_windowManagerColors s_windowManagerColors+2056
 end
 if g_lampRouteStage==27
  dump binary memory ../tmp/m3-combat/key-session-lamp-use-native-screen.bin s_colorScreen s_colorScreen+307200
  dump binary memory ../tmp/m3-combat/key-session-lamp-use-native-clut.bin s_windowManagerColors s_windowManagerColors+2056
  echo PASS LAMP USE selected empty lamp and returned gameplay publication\n
 end
 continue
end
break aitdInputExploreCheckpoint
commands
 silent
 printf "KEY_PUBLICATION stage=%u frames=%u\n",g_exploreRouteStage,g_macSceneFramesCompleted
 set $actor=(unsigned long)s_a5WorldStorage+75616-0xb292+160
 printf "EXPLORE_NATIVE stage=%u tick=%u x=%d z=%d beta=%d anim=%d room=%d floor=%d track=%d\n",g_exploreRouteStage,g_macTicks,*(short*)($actor+0x1c),*(short*)($actor+0x20),*(short*)($actor+0x2a),*(short*)($actor+0x3e),*(short*)($actor+0x30),*(short*)($actor+0x2e),*(short*)($actor+0x52)
 eval "dump binary memory ../tmp/m3-combat/key-session-native-%u-actor.bin %u %u",g_exploreRouteStage,$actor,$actor+160
 if g_exploreRouteStage==65535
  echo FAIL EXPLORE phase deadline\n
  detach
  quit 1
 end
 eval "dump binary memory ../tmp/m3-combat/key-session-native-%u-a5.bin %u %u",g_exploreRouteStage,(unsigned long)s_a5WorldStorage,(unsigned long)s_a5WorldStorage+75616
 if g_exploreRouteStage==26
  dump binary memory ../tmp/m3-combat/key-session-stairs-native-screen.bin s_colorScreen s_colorScreen+307200
  dump binary memory ../tmp/m3-combat/key-session-stairs-native-clut.bin s_windowManagerColors s_windowManagerColors+2056
  end
 if g_exploreRouteStage==64
  echo PASS KEY SESSION lamp Use, hallway and published bedroom key pickup through ordinary keys\n
 end
 continue
end
break aitdInputExploreAlignCheckpoint
commands
 silent
 set $actor=(unsigned long)s_a5WorldStorage+75616-0xb292+160
 if g_combatRouteStage==0
  printf "ALIGN_NATIVE stage=%u state=%u tick=%u x=%d z=%d anim=%d\n",g_exploreRouteStage,g_exploreAlignment,g_macTicks,*(short*)($actor+0x1c),*(short*)($actor+0x20),*(short*)($actor+0x3e)
 else
  printf "COMBAT_ALIGN stage=%u state=%u tick=%u x=%d z=%d anim=%d\n",g_combatRouteStage,g_exploreAlignment,g_macTicks,*(short*)($actor+0x1c),*(short*)($actor+0x20),*(short*)($actor+0x3e)
 end
 continue
end
define combat-state
 set $world=(unsigned long)s_a5WorldStorage+75616
 set $actor=$world-0xb292+160
 set $vars=*(unsigned long*)($world-0xcbcc)
 set $enemy=$world-0x115f2+35*52
 set $slot=*(short*)$enemy
 printf "COMBAT_NATIVE stage=%u tick=%u x=%d z=%d beta=%d anim=%d track=%d var20=%d var21=%d var30=%d var31=%d var40=%d var90=%d npc=%d frames=%u fight=%u seen=%u attempts=%u\n",g_combatRouteStage,g_macTicks,*(short*)($actor+0x1c),*(short*)($actor+0x20),*(short*)($actor+0x2a),*(short*)($actor+0x3e),*(short*)($actor+0x52),*(short*)($vars+40),*(short*)($vars+42),*(short*)($vars+60),*(short*)($vars+62),*(short*)($vars+80),*(short*)($vars+180),$slot,g_macSceneFramesCompleted,g_combatFightEvent,g_combatSawEnemy,g_combatAttempts
 if $slot>=0
  set $npc=$world-0xb292+$slot*160
  printf "COMBAT_ENEMY stage=%u slot=%d body=%d floor=%d room=%d life=%d anim=%d x=%d z=%d\n",g_combatRouteStage,$slot,*(short*)($npc+2),*(short*)($npc+0x2e),*(short*)($npc+0x30),*(short*)($npc+0x34),*(short*)($npc+0x3e),*(short*)($npc+0x1c),*(short*)($npc+0x20)
 end
end
break aitdInputCombatCheckpoint
commands
 silent
 combat-state
 eval "dump binary memory ../tmp/m3-combat/combat-native-%u-a5.bin %u %u",g_combatRouteStage,$world-75616,$world
 eval "dump binary memory ../tmp/m3-combat/combat-native-%u-vars.bin %u %u",g_combatRouteStage,$vars,$vars+400
 if g_combatRouteStage==22 || g_combatRouteStage==25 || g_combatRouteStage==32 || g_combatRouteStage==36 || g_combatRouteStage==65535
  eval "dump binary memory ../tmp/m3-combat/combat-native-%u-screen.bin %u %u",g_combatRouteStage,(unsigned long)s_colorScreen,(unsigned long)s_colorScreen+307200
  eval "dump binary memory ../tmp/m3-combat/combat-native-%u-clut.bin %u %u",g_combatRouteStage,(unsigned long)s_windowManagerColors,(unsigned long)s_windowManagerColors+2056
 end
 if g_combatRouteStage==65535
  echo FAIL COMBAT state/health/deadline\n
  detach
  quit 1
 end
 if g_combatRouteStage==36
  echo PASS COMBAT spawned enemy, Fight, attacks, victory and published manual gameplay\n
  detach
  quit 0
 end
 continue
end
break aitdInputCombatAimCheckpoint
commands
 silent
 combat-state
 printf "COMBAT_AIM tick=%u target=%u beta=%u\n",g_macTicks,g_combatAimHeading,*(unsigned short*)($actor+0x2a)
 continue
end
break aitdInputCombatAttackCheckpoint
commands
 silent
 combat-state
 continue
end
continue
