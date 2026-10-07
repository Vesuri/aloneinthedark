set pagination off
set confirm off
set width 0
break aitdM5SongPrepared
commands
 silent
 printf "M5_SONG id=%u hz=%u total=%u resource=%u move=%u lock=%u decode=%u pcm=%u resources=%u prepared=%u samples=%u\n",g_m5SongPrepare[0],g_m5Audit.clockHz,g_m5SongPrepare[1],g_m5SongPrepare[2],g_m5SongPrepare[3],g_m5SongPrepare[4],g_m5SongPrepare[5],g_m5SongPrepare[6],g_m5SongPrepare[7],g_song.preparedCount,g_song.sampleCount
 continue
end
source death_route.gdb
