set pagination off
set confirm off
set width 0
set print pretty off
break AitdScreen::showLoudStop
commands
 silent
 printf "LOUDSTOP %s / %s\n",manager,routine
end
break aitdInputFirstFloorLoadCheckpoint
commands
 silent
 printf "FIRSTFLOOR_LOAD stage=%u tick=%u\n",g_firstFloorLoadStage,g_macTicks
 if g_firstFloorLoadStage==5 || g_firstFloorLoadStage==65535
  printf "LOADED stage=%u\n",g_firstFloorLoadStage
 else
  continue
 end
end
continue
