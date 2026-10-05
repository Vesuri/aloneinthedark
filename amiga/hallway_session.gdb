set pagination off
set confirm off
break AitdScreen::showLoudStop
commands
 silent
 printf "FAIL LAMP %s / %s trap=%X selector=%u segment=%u offset=%X\n",manager,routine,g_trapWord,g_trapSelector,g_trapSegment,g_trapOffset
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
 eval "dump binary memory ../tmp/m3-explore/hallway-session-lamp-use-native-%u-a5.bin %u %u",g_lampRouteStage,$world-75616,$world
 if g_lampRouteStage==65535
  echo FAIL LAMP phase deadline\n
  detach
  quit 1
 end
 if g_lampRouteStage==25
  dump binary memory ../tmp/m3-explore/hallway-session-lamp-use-feedback-screen.bin s_colorScreen s_colorScreen+307200
  dump binary memory ../tmp/m3-explore/hallway-session-lamp-use-feedback-clut.bin s_windowManagerColors s_windowManagerColors+2056
 end
 if g_lampRouteStage==27
  dump binary memory ../tmp/m3-explore/hallway-session-lamp-use-native-screen.bin s_colorScreen s_colorScreen+307200
  dump binary memory ../tmp/m3-explore/hallway-session-lamp-use-native-clut.bin s_windowManagerColors s_windowManagerColors+2056
  echo PASS LAMP USE selected empty lamp and returned gameplay publication\n
 end
 continue
end
break aitdInputExploreCheckpoint
commands
 silent
 set $actor=(unsigned long)s_a5WorldStorage+75616-0xb292+160
 printf "EXPLORE_NATIVE stage=%u tick=%u x=%d z=%d beta=%d anim=%d room=%d floor=%d track=%d\n",g_exploreRouteStage,g_macTicks,*(short*)($actor+0x1c),*(short*)($actor+0x20),*(short*)($actor+0x2a),*(short*)($actor+0x3e),*(short*)($actor+0x30),*(short*)($actor+0x2e),*(short*)($actor+0x52)
 eval "dump binary memory ../tmp/m3-explore/hallway-session-native-%u-actor.bin %u %u",g_exploreRouteStage,$actor,$actor+160
 if g_exploreRouteStage==65535
  echo FAIL EXPLORE phase deadline\n
  detach
  quit 1
 end
 eval "dump binary memory ../tmp/m3-explore/hallway-session-native-%u-a5.bin %u %u",g_exploreRouteStage,(unsigned long)s_a5WorldStorage,(unsigned long)s_a5WorldStorage+75616
 if g_exploreRouteStage==39
  dump binary memory ../tmp/m3-explore/hallway-session-stairs-native-screen.bin s_colorScreen s_colorScreen+307200
  dump binary memory ../tmp/m3-explore/hallway-session-stairs-native-clut.bin s_windowManagerColors s_windowManagerColors+2056
  echo PASS HALLWAY SESSION lamp Use and published first-floor hallway through ordinary keys\n
  detach
  quit 0
 end
 continue
end
continue
