set pagination off
set confirm off
set width 0
break AitdScreen::showLoudStop
commands
 silent
 printf "FAIL DRIVER22_ACTIVE %s / %s\n",manager,routine
 detach
 quit 1
end
break aitdAudioStopProbeCheckpoint
commands
 silent
 printf "AUDIO_STOP_KEY stage=%u tick=%u end=%u\n",g_audioStopProbeStage,g_macTicks,g_effects[0].ends
 if g_audioStopProbeStage==65535
  echo FAIL active stop retry limit\n
  detach
  quit 1
 end
 continue
end
tbreak aitdAudioStopProbeAccepted
continue
if g_audioStopProbeStage!=5 || g_ingameStage!=5
 echo FAIL active stop ordinary gameplay input\n
 detach
 quit 1
end
set $active_slot=g_soundDriver.effects[0].active ? 0 : 1
set $active_channel=g_soundDriver.effects[$active_slot].channel
set $active_tick=g_musicTicks
set $stops=g_effectStops
printf "AUDIO_STOP_DURATION remaining=%d\n",(int)(g_effects[$active_slot].ends-g_macTicks)
if (int)(g_effects[$active_slot].ends-g_macTicks)<=0 || $active_channel<0 || $active_channel>3 || !g_effects[$active_slot].chip
 echo FAIL actual effect DMA ownership\n
 detach
 quit 1
end
printf "AUDIO_STOP_ENTER slot=%u channel=%u musicTick=%u starts=%u stops=%u\n",$active_slot,$active_channel,$active_tick,g_effectStarts,g_effectStops
dump binary memory ../tmp/m4/driver22/native/music-before.bin (char*)g_soundDriver.songs (char*)g_soundDriver.songs+sizeof(g_soundDriver.songs)
dump binary memory ../tmp/m4/driver22/native/voices-before.bin (char*)g_song.voices (char*)g_song.voices+sizeof(g_song.voices)
dump binary memory ../tmp/m4/driver22/native/enter-state.bin (char*)&g_soundDriver (char*)&g_soundDriver+sizeof(g_soundDriver)
source driver22_call.gdb
dump binary memory ../tmp/m4/driver22/native/return-state.bin (char*)&g_soundDriver (char*)&g_soundDriver+sizeof(g_soundDriver)
if g_musicTicks!=$active_tick || g_effectStops!=$stops+1 || g_effects[$active_slot].chip || g_effects[$active_slot].allocated || g_soundDriver.effects[$active_slot].channel!=-1 || g_soundDriver.channels[$active_channel]!=-1 || (*(unsigned short*)0xdff002&(1<<$active_channel))
 echo FAIL active stop resource/channel isolation or timing window\n
 detach
 quit 1
end
dump binary memory ../tmp/m4/driver22/native/music-after.bin (char*)g_soundDriver.songs (char*)g_soundDriver.songs+sizeof(g_soundDriver.songs)
dump binary memory ../tmp/m4/driver22/native/voices-after.bin (char*)g_song.voices (char*)g_song.voices+sizeof(g_song.voices)
printf "AUDIO_STOP_RETURN stage=%u stops=%u dma=%X\n",g_audioStopProbeStage,g_effectStops,*(unsigned short*)0xdff002
echo PASS native ordinary active driver22 stop, DMA release and music isolation\n
detach
quit 0
