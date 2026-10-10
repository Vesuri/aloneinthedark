# INGAME=1; reference CPU. Read-only first-room scenes 60..160.
set pagination off
set confirm off
break AitdScreen::showLoudStop
commands
 silent
 echo FAIL VBL latency loud stop\n
 detach
 quit 1
end
tbreak AitdScreen::queueFrame if g_ingameStage==5 && g_macSceneFramesCompleted>=60
continue
set $base=g_macSceneFramesCompleted
set $callbacks=0
set $late=0
set $total=0
break aitdVBLCallbackComplete
commands
 silent
 # During a callback the Ticks shadow exposes the virtual pass being drained.
 set $delay=g_macTicks-*g_macTicksAddress
 if $delay>$late
  set $late=$delay
 end
 set $total=$total+$delay
 set $callbacks=$callbacks+1
 continue
end
tbreak AitdScreen::queueFrame if g_macSceneFramesCompleted>=$base+100
continue
if !$callbacks
 echo FAIL VBL latency no callbacks\n
 detach
 quit 1
end
printf "VBL_LATENCY scenes=%u callbacks=%u max_ticks=%u total_ticks=%u\n",g_macSceneFramesCompleted-$base,$callbacks,$late,$total
echo PASS VBL callback latency capture\n
detach
quit 0
