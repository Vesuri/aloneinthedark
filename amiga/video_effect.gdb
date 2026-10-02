# No INTROSKIP: the first original effect must complete naturally.
set pagination off
set confirm off
set width 0
source video_mode.gdb
break AitdScreen::showLoudStop
commands
 silent
 printf "FAIL video effect: %s / %s selector=%u\n",manager,routine,selector
 detach
 quit 1
end
tbreak dispatchMacTrap if trap==0xa0f8 && inUserService && *(unsigned long*)(userStack+4)==17
continue
set $video_audio_starts=0
break startPaulaSample
commands
 silent
 set $video_audio_starts=$video_audio_starts+1
 printf "VIDEO_AUDIO_PROGRAM period=%u channel=%u\n",period,channel
 if period!=(g_paulaClock+4000)/8000 || channel!=0
  echo FAIL selected-clock Paula programming\n
  detach
  quit 1
 end
 continue
end
source driver17_call.gdb
set $hz=g_effects[0].rate>>16
set $period=(g_paulaClock+$hz/2)/$hz
set $bytes=(g_effects[0].size+1)&~1
set $duration=((unsigned long long)$bytes*$period*60+g_paulaClock-1)/g_paulaClock
set $ends=g_effects[0].ends
# AUD0PER is write-only and this debugger returns zero for it. Observe the
# actual Paula programming call above, then verify its scheduled completion.
if $video_audio_starts!=1 || g_effects[0].period!=$period || g_effects[0].ends-g_effects[0].started-1!=$duration
 echo FAIL selected-clock effect pitch/duration\n
 detach
 quit 1
end
printf "VIDEO_EFFECT pal=%u clock=%u hz=%u bytes=%u period=%u duration=%u\n",g_videoPAL,g_paulaClock,$hz,$bytes,$period,$duration
tbreak stopNativeEffect if index==0
continue
if g_macTicks<$ends || g_effectStarts!=1 || g_effectStops!=0
 echo FAIL effect completed before selected-clock duration\n
 detach
 quit 1
end
finish
if g_soundDriver.effects[0].active || g_effects[0].chip || g_effectStops!=1 || (*(unsigned short*)0xdff002&1)!=0
 echo FAIL native effect DMA cleanup\n
 detach
 quit 1
end
check_video_mode
printf "PASS native video effect pal=%u period=%u duration=%u stopTick=%u scheduled=%u\n",g_videoPAL,$period,$duration,g_macTicks,$ends
detach
quit 0
