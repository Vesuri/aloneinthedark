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
 set $lamp=$world-0x115f2+13*52
 printf "LAMP_NATIVE stage=%u tick=%u x=%d z=%d beta=%d anim=%d flags=%X count=%d slot0=%d slot1=%d objectFloor=%d objectRoom=%d frames=%u\n",g_lampRouteStage,g_macTicks,*(short*)($actor+0x1c),*(short*)($actor+0x20),*(short*)($actor+0x2a),*(short*)($actor+0x3e),*(unsigned short*)($lamp+12),*(short*)($world-0xd8a6),*(short*)($world-0xd8a4),*(short*)($world-0xd8a2),*(short*)($lamp+28),*(short*)($lamp+30),g_macSceneFramesCompleted
 eval "dump binary memory ../tmp/m3-explore/lamp-native-%u-a5.bin %u %u",g_lampRouteStage,$world-75616,$world
 if g_lampRouteStage==65535
  echo FAIL LAMP phase deadline\n
  detach
  quit 1
 end
 if g_lampRouteStage==15
  dump binary memory ../tmp/m3-explore/lamp-native-screen.bin s_colorScreen s_colorScreen+307200
  dump binary memory ../tmp/m3-explore/lamp-native-clut.bin s_windowManagerColors s_windowManagerColors+2056
  echo PASS LAMP taken world object, inventory slot and returned gameplay publication\n
  detach
  quit 0
 end
 continue
end
continue
