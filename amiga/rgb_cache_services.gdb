# MONSTERPROFILE=1 FIXEDRNG=1 SCENEFRAMEVERIFY=1 RGBCACHEVERIFY=1 M5AUDIT=1.
# Idle monster-to-death: RGB/particle/CopyBits quick entries, scene edges and audio.
source m5_snapshot.gdb
set pagination off
set confirm off
break AitdScreen::showLoudStop
commands
 silent
 printf "FAIL RGB services %s / %s\n",manager,routine
 detach
 quit 1
end
break aitdMonsterCheckpoint
commands
 silent
 printf "RGB_SERVICES phase=%u frames=%u\n",g_monsterPhase,g_monsterCount
 if g_monsterPhase==5
  printf "SCENE_END_VERIFY checks=%u failures=%u reused=%u begun=%u completed=%u\n",g_sceneFrameEndChecks,g_sceneFrameEndFailures,g_sceneFrameEndReused,g_macSceneFramesBegun,g_macSceneFramesCompleted
  printf "RGB_CACHE_VERIFY checks=%u failures=%u quick_hits=%u\n",g_rgbCacheChecks,g_rgbCacheFailures,g_rgbQuickHits
  if g_sceneFrameEndChecks<1000 || g_sceneFrameEndFailures || g_macSceneFramesCompleted>g_macSceneFramesBegun || g_macSceneFramesBegun-g_macSceneFramesCompleted>1 || g_rgbCacheChecks<1000 || g_rgbQuickHits<1000 || g_rgbCacheFailures
   echo FAIL RGB independent service verification\n
   detach
   quit 1
  end
  m5_snapshot
  echo PASS RGB monster service audit\n
  detach
  quit 0
 end
 continue
end
continue
