# ACTIONPROBE=1: ordinary Return input; time 20 completed character rotations.
# Dan1+$F7A is the shared angle decrement in the Actions preview routine.
set pagination off
set confirm off
set $count=0
set $paces=0
break AitdScreen::paceFrame
commands
 silent
 set $paces=$paces+1
 continue
end
set $previous_angle=0
break AitdScreen::showLoudStop
commands
 silent
 printf "FAIL ACTION %s / %s\n",manager,routine
 detach
 quit 1
end
tbreak getFontNumber
continue
if *(unsigned short*)((unsigned long)s_segments[12].begin+0xf7a)!=0x5179
 echo FAIL ACTION original preview bytes\n
 detach
 quit 1
end
break *((unsigned long)s_segments[12].begin+0xf7a) if g_actionProbeStage==3
commands
 silent
 if $count && *(short*)(s_currentA5-0xce86)!=(short)($previous_angle-8)
  echo FAIL ACTION rotation sequence\n
  detach
  quit 1
 end
 if $count
  if $paces-$lastPaces!=1 || (unsigned short)(g_macFramesQueued-$lastQueue)!=1
   echo FAIL ACTION partial publication or extra frame wait\n
   detach
   quit 1
  end
  printf "ACTION_PACING waits=%u publications=%u\n",$paces-$lastPaces,(unsigned short)(g_macFramesQueued-$lastQueue)
 end
 set $lastPaces=$paces
 set $lastQueue=g_macFramesQueued
 set $previous_angle=*(short*)(s_currentA5-0xce86)
 set $count=$count+1
 if $count==1
  set $began=g_macTicks
 end
 if $count==21
  set $elapsed=g_macTicks-$began
 end
 printf "ACTION_PREVIEW n=%u tick=%u angle=%d actor=%d\n",$count,g_macTicks,*(short*)(s_currentA5-0xce86),*(short*)($a6+8)
 continue
end
break *((unsigned long)s_segments[12].begin+0x10ee) if $count==21
commands
 silent
 dump binary memory ../tmp/m3-action/native-menu-screen.bin s_colorScreen s_colorScreen+sizeof(s_colorScreen)
 dump binary memory ../tmp/m3-action/native-menu-clut.bin s_windowManagerColors s_windowManagerColors+sizeof(s_windowManagerColors)
 printf "PASS action timing elapsed=%u updates=20 hz=60 keyTick=%u firstTick=%u\n",$elapsed,g_actionProbeTick,$began
 detach
 quit 0
end
continue
