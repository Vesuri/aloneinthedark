# End at the first published gameplay frame after successful Save close.
# diag_run.sh then kills only this recorded emulator, without normal Quit.
set pagination off
set confirm off
break AitdScreen::showLoudStop
commands
 silent
 printf "FAIL DURABLE SAVE %s / %s\n",manager,routine
 detach
 quit 1
end
break aitdInputSaveLoadCheckpoint
commands
 silent
 if g_saveLoadStage==65535
  echo FAIL DURABLE SAVE deadline\n
  detach
  quit 1
 end
 if g_saveLoadStage==2
  if g_saveLoadClosedBytes!=36254 || !g_macSceneFramesCompleted
   echo FAIL DURABLE SAVE success/publication\n
   detach
   quit 1
  end
  set $actor=(unsigned long)s_a5WorldStorage+75616-0xb292+160
  dump binary memory ../tmp/m3-saveload/durable-saved-actor.bin $actor $actor+160
  printf "PASS DURABLE SAVE abrupt restart boundary tick=%u bytes=%u frames=%u\n",g_macTicks,g_saveLoadClosedBytes,g_macSceneFramesCompleted
  detach
  quit 0
 end
 continue
end
continue
