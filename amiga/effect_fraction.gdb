# Authorized isolated packet fixture, first unchanged original selector-17 call.
set pagination off
set confirm off
set width 0
break AitdScreen::showLoudStop
commands
 silent
 printf "FAIL fractional effect %s / %s\n",manager,routine
 detach
 quit 1
end
tbreak aitdEffectFractionReady
continue
set $fraction_packet=*(unsigned long*)(userStack+8)
if *(unsigned long*)($fraction_packet+4)!=4096 || *(unsigned long*)($fraction_packet+8)!=0x1f408000
 echo FAIL fractional packet fixture\n
 detach
 quit 1
end
source driver17_call.gdb
set $fraction_tick=g_effects[0].started
set $fraction_period=g_effects[0].period
set $fraction_duration=g_effects[0].ends-g_effects[0].started-1
set $fraction_end=g_effects[0].ends
if g_effects[0].rate!=0x1f408000 || $fraction_period!=443 || $fraction_duration!=31
 echo FAIL fractional pitch and deadline\n
 detach
 quit 1
end
tbreak stopNativeEffect if index==0
continue
if g_macTicks<$fraction_end
 echo FAIL premature fractional completion\n
 detach
 quit 1
end
set $fraction_stop_tick=g_macTicks
printf "EFFECT_FRACTION_STOP elapsed=%u deadline=%u\n",$fraction_stop_tick-$fraction_tick,$fraction_end-$fraction_tick
finish
if g_soundDriver.effects[0].active || g_effects[0].chip || g_effects[0].allocated || g_effectStops!=1 || (*(unsigned short*)0xdff002&1)
 echo FAIL fractional sample/DMA cleanup\n
 detach
 quit 1
end
printf "EFFECT_FRACTION period=%u duration=%u elapsed=%u\n",$fraction_period,$fraction_duration,g_macTicks-$fraction_tick
echo PASS native fractional effect packet, playback and cleanup\n
detach
quit 0
