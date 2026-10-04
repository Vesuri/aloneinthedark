# CPU-executed full FIGHT music fixture; no original MDRV instructions run.
set pagination off
set confirm off
break AitdScreen::showLoudStop
commands
 silent
 printf "FAIL SONG132 %s / %s\n",manager,routine
 detach
 quit 1
end
tbreak aitdSongProbeArmed
continue
if g_song.id!=132 || g_song.midiId!=902 || g_song.ownedCount!=38 || g_song.sampleCount!=24 || g_song.events || g_song.timeline.pulses
 echo FAIL SONG132 armed resources\n
 detach
 quit 1
end
printf "SONG132_ARMED song=%u midi=%u owned=%u samples=%u\n",g_song.id,g_song.midiId,g_song.ownedCount,g_song.sampleCount
tbreak aitdSongProbePlaybackComplete
continue
if g_songTraceCount!=1206 || g_song.events!=1206 || g_song.timeline.active || g_songProbeEffects!=2 || g_song.dropped || g_effectStarts!=1 || g_effectStops!=1 || g_songProbeIRQTicks<180 || !g_songProbeIRQEvents
 echo FAIL SONG132 complete playback/effect/interrupt coverage\n
 detach
 quit 1
end
printf "SONG132_PLAYBACK events=%u pulses=%u starts=%u steals=%u effects=%u/%u stalledTicks=%u stalledEvents=%u started=%u\n",g_song.events,g_song.timeline.pulses,g_song.starts,g_song.steals,g_effectStarts,g_effectStops,g_songProbeIRQTicks,g_songProbeIRQEvents,g_song.started
dump binary memory ../tmp/m3-fight/song132-native-events.bin (char*)g_songTrace (char*)g_songTrace+g_songTraceCount*40
dump binary memory ../tmp/m3-fight/song132-native-delivery.bin (char*)g_songDelivery (char*)g_songDelivery+g_songTraceCount*8
tbreak aitdSongProbeComplete
continue
if !g_songProbeHeapOK || g_song.ownedCount || g_song.sampleCount || g_song.playing || g_song.prepared || g_song.preparedCount || g_effects[0].chip || g_effects[1].chip || (*(unsigned short*)0xdff002&15)
 echo FAIL SONG132 resource/heap/DMA cleanup\n
 detach
 quit 1
end
set $i=0
while $i<6
 if g_song.voices[$i].chip || g_soundDriver.songs[$i].channel!=-1 || g_soundDriver.songs[$i].active
  echo FAIL SONG132 voice cleanup\n
  detach
  quit 1
 end
 set $i=$i+1
end
set $i=0
while $i<4
 if g_soundDriver.channels[$i]!=-1
  echo FAIL SONG132 channel cleanup\n
  detach
  quit 1
 end
 set $i=$i+1
end
set $i=0
while $i<g_resourceCount
 if s_resourceForks.m_items[$i].item.type==0x4d445256 && s_resourceHandles[$i]
  echo FAIL SONG132 original MDRV resident\n
  detach
  quit 1
 end
 set $i=$i+1
end
echo PASS SONG132 full playback, interrupt progress, effect priority, resource cleanup and original MDRV absent\n
detach
quit 0
