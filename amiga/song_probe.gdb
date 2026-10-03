set pagination off
set confirm off
set width 0
break AitdScreen::showLoudStop
tbreak aitdSongProbeArmed
continue
if g_song.ownedCount!=41 || g_song.sampleCount!=28 || g_song.id!=135 || g_song.midiId!=905 || g_song.events!=0 || g_song.timeline.pulses!=0 || g_songProbeEffects!=0
 echo FAIL song probe armed state\n
 detach
 quit 1
end
printf "SONG_PROBE_ARMED song=%u midi=%u owned=%u samples=%u tick=%u\n",g_song.id,g_song.midiId,g_song.ownedCount,g_song.sampleCount,g_macTicks
tbreak aitdSongVoiceStarted if g_song.voices[g_songLastVoice].stride==1
continue
set $slot=g_songLastVoice
set $voice=&g_song.voices[$slot]
set $channel=g_soundDriver.songs[$slot].channel
if $voice->stride!=1 || $channel<0 || g_soundDriver.channels[$channel]!=$slot || !g_soundDriver.songs[$slot].active || (*(unsigned short*)0xdff002 & (1<<$channel))==0
 echo FAIL song probe DMA ownership\n
 detach
 quit 1
end
printf "SONG_PROBE_PCM stride=%u period=%u sample=%u note=%u instrument=%u midiChannel=%u channel=%u allocated=%u chip=%X dma=%X\n",$voice->stride,$voice->period,$voice->sample,$voice->note,$voice->instrument,$voice->channel,$channel,$voice->allocated,$voice->chip,*(unsigned short*)0xdff002
dump binary memory ../tmp/song-probe-pcm-1.bin $voice->chip $voice->chip+$voice->allocated
tbreak aitdSongVoiceStarted if g_song.voices[g_songLastVoice].stride==2
continue
set $slot=g_songLastVoice
set $voice=&g_song.voices[$slot]
set $channel=g_soundDriver.songs[$slot].channel
if $voice->stride!=2 || $channel<0 || g_soundDriver.channels[$channel]!=$slot || !g_soundDriver.songs[$slot].active || (*(unsigned short*)0xdff002 & (1<<$channel))==0
 echo FAIL song probe DMA ownership\n
 detach
 quit 1
end
printf "SONG_PROBE_PCM stride=%u period=%u sample=%u note=%u instrument=%u midiChannel=%u channel=%u allocated=%u chip=%X dma=%X\n",$voice->stride,$voice->period,$voice->sample,$voice->note,$voice->instrument,$voice->channel,$channel,$voice->allocated,$voice->chip,*(unsigned short*)0xdff002
dump binary memory ../tmp/song-probe-pcm-2.bin $voice->chip $voice->chip+$voice->allocated
tbreak aitdSongProbePlaybackComplete
continue
if g_songTraceCount!=3736 || g_song.events!=3736 || g_songProbeEffects!=2 || g_song.timeline.active
 echo FAIL song probe complete sequence\n
 detach
 quit 1
end
printf "SONG_PROBE_PLAYBACK events=%u pulses=%u starts=%u steals=%u dropped=%u effects=%u/%u tick=%u\n",g_song.events,g_song.timeline.pulses,g_song.starts,g_song.steals,g_song.dropped,g_effectStarts,g_effectStops,g_macTicks
dump binary memory ../tmp/song-probe-events.bin (char*)g_songTrace (char*)g_songTrace+g_songTraceCount*40
if g_songProbeIRQTicks<180 || !g_songProbeIRQEvents
 echo FAIL music did not advance during CPU-only stall\n
 detach
 quit 1
end
printf "SONG_PROBE_INTERRUPT stalledTicks=%u events=%u started=%u\n",g_songProbeIRQTicks,g_songProbeIRQEvents,g_song.started
set $periodmax=0
set $i=0
while $i<g_song.preparedCount
 if g_song.prepared[$i].dma.period>$periodmax
  set $periodmax=g_song.prepared[$i].dma.period
 end
 set $i=$i+1
end
printf "SONG_PROBE_PREPARED notes=%u bytes=%u maxPeriod=%u\n",g_song.preparedCount,g_song.preparedCount*sizeof(g_song.prepared[0]),$periodmax
dump binary memory ../tmp/song-probe-delivery.bin (char*)g_songDelivery (char*)g_songDelivery+g_songTraceCount*8
set $sample=0
set $cached=0
set $cacheBytes=0
while $sample<g_song.sampleCount
 set $variant=0
 while $variant<5
  set $pcm=g_song.samples[$sample].chip[$variant]
  set $bytes=g_song.samples[$sample].allocated[$variant]
  if $pcm
   set $id=g_song.samples[$sample].id
   set $stride=1<<$variant
   printf "SONG_PROBE_CACHE sample=%u stride=%u allocated=%u\n",$id,$stride,$bytes
   eval "dump binary memory ../tmp/song-cache-%u-%u.bin $pcm $pcm+$bytes",$id,$stride
   set $cached=$cached+1
   set $cacheBytes=$cacheBytes+$bytes
  end
  set $variant=$variant+1
 end
 set $sample=$sample+1
end
printf "SONG_PROBE_CACHE_TOTAL entries=%u bytes=%u\n",$cached,$cacheBytes
tbreak aitdSongProbeComplete
continue
if g_song.ownedCount!=0 || g_song.sampleCount!=0 || g_song.playing || !g_songProbeHeapOK
 echo FAIL song probe cleanup state\n
 detach
 quit 1
end
set $sample=0
while $sample<128
 set $variant=0
 while $variant<5
  if g_song.samples[$sample].chip[$variant] || g_song.samples[$sample].allocated[$variant]
   echo FAIL song probe retained PCM cleanup\n
   detach
   quit 1
  end
  set $variant=$variant+1
 end
 set $sample=$sample+1
end
set $i=0
while $i<6
 if g_song.voices[$i].chip!=0 || g_song.voices[$i].allocated!=0 || g_soundDriver.songs[$i].channel!=-1 || g_soundDriver.songs[$i].active || g_soundDriver.songs[$i].sample
  echo FAIL song probe voice cleanup\n
  detach
  quit 1
 end
 set $i=$i+1
end
set $i=0
while $i<4
 if g_soundDriver.channels[$i]!=-1
  echo FAIL song probe channel cleanup\n
  detach
  quit 1
 end
 set $i=$i+1
end
set $i=0
while $i<g_resourceCount
 if s_resourceForks.m_items[$i].item.type==0x4d445256 && s_resourceHandles[$i]!=0
  echo FAIL song probe original MDRV resident\n
  detach
  quit 1
 end
 set $i=$i+1
end
if g_song.prepared || g_song.preparedCount
 echo FAIL prepared song memory cleanup\n
 detach
 quit 1
end
echo PASS native full song: playback, effect priority, PCM variants, cleanup and original MDRV absent\n
detach
quit 0
