set pagination off
set confirm off
set stack-cache off
set code-cache off
break AitdScreen::showLoudStop
commands
 silent
 printf "FAIL EXPLORE %s / %s trap=%X selector=%u segment=%u offset=%X\n",manager,routine,g_trapWord,g_trapSelector,g_trapSegment,g_trapOffset
 detach
 quit 1
end
break aitdInputExploreCheckpoint
commands
 silent
 printf "STAIRS_RATE stage=%u tick=%u frames=%u fields=%u\n",g_exploreRouteStage,g_macTicks,g_macSceneFramesCompleted,g_vbiCount
 set $actor=(unsigned long)s_a5WorldStorage+75616-0xb292+160
 printf "EXPLORE_NATIVE stage=%u tick=%u x=%d z=%d beta=%d anim=%d room=%d floor=%d track=%d\n",g_exploreRouteStage,g_macTicks,*(short*)($actor+0x1c),*(short*)($actor+0x20),*(short*)($actor+0x2a),*(short*)($actor+0x3e),*(short*)($actor+0x30),*(short*)($actor+0x2e),*(short*)($actor+0x52)
 eval "dump binary memory ../tmp/stairs-regression/native-%u-actor.bin %u %u",g_exploreRouteStage,$actor,$actor+160
 if g_exploreRouteStage==65535
  echo FAIL EXPLORE phase deadline\n
  detach
  quit 1
 end
 if g_exploreRouteStage==19
  dump binary memory ../tmp/stairs-regression/stairs-native-screen.bin s_colorScreen s_colorScreen+307200
  dump binary memory ../tmp/stairs-regression/stairs-native-clut.bin s_windowManagerColors s_windowManagerColors+2056
  echo PASS EXPLORE reached published first floor through ordinary keys\n
  detach
  quit 0
 end
 continue
end
continue
