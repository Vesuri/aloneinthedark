# CPU-executed full measured gameplay-song fixture; no original MDRV instructions run.
set pagination off
set confirm off
break AitdScreen::showLoudStop
commands
 silent
 printf "FAIL SONG_LIVE %s / %s\n",manager,routine
 detach
 quit 1
end
tbreak aitdSongProbeArmed
continue
set $song_id=g_song.id
set $song_events=0
set $song_owned=0
set $song_samples=0
if $song_id==132
 set $song_events=1206
 set $song_owned=38
 set $song_samples=24
end
if $song_id==136
 set $song_events=602
 set $song_owned=33
 set $song_samples=21
end
if $song_id==137
 set $song_events=2250
 set $song_owned=38
 set $song_samples=25
end
if !$song_events || g_song.midiId!=$song_id+770 || g_song.ownedCount!=$song_owned || g_song.sampleCount!=$song_samples || g_song.events || g_song.timeline.pulses
 echo FAIL SONG_LIVE armed resources\n
 detach
 quit 1
end
printf "SONG%u_ARMED song=%u midi=%u owned=%u samples=%u\n",$song_id,g_song.id,g_song.midiId,g_song.ownedCount,g_song.sampleCount
tbreak aitdSongProbePlaybackComplete
continue
if g_songTraceCount!=$song_events || g_song.events!=$song_events || g_song.timeline.active || g_songProbeEffects!=2 || g_song.dropped || g_effectStarts!=1 || g_effectStops!=1 || g_songProbeIRQTicks<180 || !g_songProbeIRQEvents
 echo FAIL SONG_LIVE complete playback/effect/interrupt coverage\n
 detach
 quit 1
end
printf "SONG%u_PLAYBACK events=%u pulses=%u starts=%u steals=%u effects=%u/%u stalledTicks=%u stalledEvents=%u started=%u\n",$song_id,g_song.events,g_song.timeline.pulses,g_song.starts,g_song.steals,g_effectStarts,g_effectStops,g_songProbeIRQTicks,g_songProbeIRQEvents,g_song.started
dump binary memory ../tmp/m4/native-song/native-events.bin (char*)g_songTrace (char*)g_songTrace+g_songTraceCount*40
dump binary memory ../tmp/m4/native-song/native-delivery.bin (char*)g_songDelivery (char*)g_songDelivery+g_songTraceCount*8
if g_songHardwareOverflow || g_songEffectOverflow || g_songHardwareCount!=g_song.starts
 echo FAIL SONG_LIVE complete hardware ownership trace\n
 detach
 quit 1
end
printf "SONG_ALLOCATION song=%u events=%u starts=%u steals=%u effects=%u started=%u\n",g_song.id,g_song.events,g_song.starts,g_song.steals,g_songEffectCount,g_song.started
dump binary memory ../tmp/m4/native-song/native-notes.bin (char*)g_songHardware (char*)g_songHardware+g_songHardwareCount*32
dump binary memory ../tmp/m4/native-song/native-clocks.bin (char*)g_songEventClocks (char*)g_songEventClocks+g_songTraceCount*8
dump binary memory ../tmp/m4/native-song/native-effects.bin (char*)g_songEffects (char*)g_songEffects+g_songEffectCount*32
tbreak aitdSongProbeComplete
continue
if !g_songProbeHeapOK || g_song.ownedCount || g_song.sampleCount || g_song.playing || g_song.prepared || g_song.preparedCount || g_effects[0].chip || g_effects[1].chip || (*(unsigned short*)0xdff002&15)
 echo FAIL SONG_LIVE resource/heap/DMA cleanup\n
 detach
 quit 1
end
set $i=0
while $i<6
 if g_song.voices[$i].chip || g_soundDriver.songs[$i].channel!=-1 || g_soundDriver.songs[$i].active
  echo FAIL SONG_LIVE voice cleanup\n
  detach
  quit 1
 end
 set $i=$i+1
end
set $i=0
while $i<4
 if g_soundDriver.channels[$i]!=-1
  echo FAIL SONG_LIVE channel cleanup\n
  detach
  quit 1
 end
 set $i=$i+1
end
set $i=0
while $i<g_resourceCount
 if s_resourceForks.m_items[$i].item.type==0x4d445256 && s_resourceHandles[$i]
  echo FAIL SONG_LIVE original MDRV resident\n
  detach
  quit 1
 end
 set $i=$i+1
end
printf "PASS SONG%u full playback, interrupt progress, effect priority, resource cleanup and original MDRV absent\n",$song_id
detach
quit 0
