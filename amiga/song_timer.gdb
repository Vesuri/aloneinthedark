# SONGPROBE=1 CIAMUSIC=1. The normal fixture tests two timer start/stop
# cycles before loading its song. Reaching Armed proves those checks passed.
set pagination off
set confirm off
set width 0
break AitdScreen::showLoudStop
tbreak aitdSongProbeArmed
continue
if g_song.ownedCount!=41 || g_song.sampleCount!=28 || g_song.id!=135 || g_song.events!=0 || g_song.timeline.pulses!=0 || !g_song.playing
 echo FAIL CIA lifecycle did not reach armed song\n
 detach
 quit 1
end
if g_musicTimerSource<1 || g_musicTimerSource>2
 echo FAIL CIA song timer not acquired\n
 detach
 quit 1
end
printf "PASS CIA lifecycle: two advancing timers stopped, ticks stayed fixed after release, same timer reacquired; song source=%u\n",g_musicTimerSource
detach
quit 0
