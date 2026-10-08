# Arm after gameplay begins; keep the original call/return ABI checks.
set $core=s_segments[3].begin
set $deathSong131_seen=0
set $deathSongReturned=0
set $deathMenuSeen=0
break *($core+0x138c) if *(unsigned long*)($sp+4)==131
commands
 silent
 if *(unsigned long*)($core+0x1382)!=0x2f2e0008 || *(unsigned long*)($core+0x1386)!=0x42a7206d || *(unsigned long*)($core+0x138a)!=0xf9544e90 || *(unsigned short*)($core+0x138e)!=0x508f || *(unsigned long*)$sp || g_song.ownedCount || g_song.playing
  echo FAIL DEATH ROUTE caller bytes/previous ownership\n
  detach
  quit 1
 end
 set $deathSong131_sp=$sp
 set $deathSong131_seen=$deathSong131_seen+1
 set $d2_saved=$d2
 set $d3_saved=$d3
 set $d4_saved=$d4
 set $d5_saved=$d5
 set $d6_saved=$d6
 set $d7_saved=$d7
 set $a0_saved=$a0
 set $a1_saved=$a1
 set $a2_saved=$a2
 set $a3_saved=$a3
 set $a4_saved=$a4
 set $a5_saved=$a5
 set $a6_saved=$a6
 set $world=(unsigned long)s_a5WorldStorage+75616
 set $actor=$world-0xb292+160
 if *(short*)($actor+0x3e)!=261 || *(short*)($actor+0x30) || *(short*)($actor+0x2e)
  echo FAIL DEATH ROUTE natural death state\n
  detach
  quit 1
 end
 printf "DEATH_ENTER song=131 tick=%u anim=%d room=%d floor=%d\n",g_macTicks,*(short*)($actor+0x3e),*(short*)($actor+0x30),*(short*)($actor+0x2e)
 continue
end
break *($core+0x138e) if $deathSong131_seen
commands
 silent
 if $deathSong131_seen!=1 || $sp!=$deathSong131_sp || $d0 || $d1!=12 || g_song.id!=131 || g_song.midiId!=901 || !g_song.playing || g_song.ownedCount!=17 || g_song.sampleCount!=9 || !g_song.preparedCount || $d2!=$d2_saved || $d3!=$d3_saved || $d4!=$d4_saved || $d5!=$d5_saved || $d6!=$d6_saved || $d7!=$d7_saved || $a0!=$a0_saved || $a1!=$a1_saved || $a2!=$a2_saved || $a3!=$a3_saved || $a4!=$a4_saved || $a5!=$a5_saved || $a6!=$a6_saved
  echo FAIL DEATH ROUTE result/ABI/resources\n
  detach
  quit 1
 end
 set $deathSongReturned=1
 set $deathSong131_seen=0
 printf "DEATH_RETURN tick=%u preserved=13 result=0/12 resources=17 samples=9\n",g_macTicks
 continue
end
