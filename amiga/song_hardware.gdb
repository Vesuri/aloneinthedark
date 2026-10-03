# Clean build: INTROSKIP=1 SONGHARDWARE=1. Audio on, warp off.
# No debugger stops during the intro: timestamps are buffered in native RAM.
set pagination off
set confirm off
set width 0
break AitdScreen::showLoudStop
commands
 silent
 printf "FAIL song hardware loud stop: %s / %s\n",manager,routine
 detach
 quit 1
end
tbreak aitdInputInjectProbeKey
continue
set $dark=(unsigned long)s_segments[4].begin
if *(unsigned short*)($dark+0x552c)!=0x4e71
 echo FAIL song hardware original completion bytes\n
 detach
 quit 1
end
tbreak *($dark+0x552c)
continue
if g_song.events!=3736 || !g_songHardwareCount || g_songHardwareCount!=g_song.starts || g_songHardwareOverflow || g_song.maxDeliveryLateness>1
 echo FAIL song hardware complete capture\n
 detach
 quit 1
end
printf "SONG_HARDWARE clock=field-raster events=%u starts=%u captured=%u overflow=%u maxLate=%u busyFields=%u tick=%u pal=%u paula=%u\n",g_song.events,g_song.starts,g_songHardwareCount,g_songHardwareOverflow,g_song.maxDeliveryLateness,g_song.busyFields,g_macTicks,g_videoPAL,g_paulaClock
dump binary memory ../tmp/song-hardware.bin (char*)g_songHardware (char*)g_songHardware+g_songHardwareCount*32
echo PASS uninterrupted intro hardware note capture\n
detach
quit 0
