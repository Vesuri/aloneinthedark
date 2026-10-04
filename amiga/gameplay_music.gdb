# Observe the original game's natural attic transition into MONSTER music.
set pagination off
set confirm off
break AitdScreen::showLoudStop
commands
 silent
 printf "FAIL GAMEPLAY MUSIC %s / %s selector=%d\n",manager,routine,g_trapSelector
 detach
 quit 1
end
tbreak getFontNumber
continue
set $core=s_segments[3].begin
set $song136_seen=0
break *($core+0x138c) if *(unsigned long*)($sp+4)==136
commands
 silent
 if *(unsigned long*)($core+0x1382)!=0x2f2e0008 || *(unsigned long*)($core+0x1386)!=0x42a7206d || *(unsigned long*)($core+0x138a)!=0xf9544e90 || *(unsigned short*)($core+0x138e)!=0x508f || *(unsigned long*)$sp || g_song.ownedCount || g_song.playing
  echo FAIL GAMEPLAY MUSIC caller bytes/previous ownership\n
  detach
  quit 1
 end
 set $song136_sp=$sp
 set $song136_seen=$song136_seen+1
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
 printf "GAMEPLAY_MUSIC_ENTER song=136 tick=%u\n",g_macTicks
 continue
end
break *($core+0x138e) if $song136_seen
commands
 silent
 if $song136_seen!=1 || $sp!=$song136_sp || $d0 || $d1!=12 || g_song.id!=136 || g_song.midiId!=906 || !g_song.playing || g_song.ownedCount!=33 || g_song.sampleCount!=21 || !g_song.preparedCount || $d2!=$d2_saved || $d3!=$d3_saved || $d4!=$d4_saved || $d5!=$d5_saved || $d6!=$d6_saved || $d7!=$d7_saved || $a0!=$a0_saved || $a1!=$a1_saved || $a2!=$a2_saved || $a3!=$a3_saved || $a4!=$a4_saved || $a5!=$a5_saved || $a6!=$a6_saved
  echo FAIL GAMEPLAY MUSIC result/ABI/resources\n
  detach
  quit 1
 end
 printf "PASS GAMEPLAY MUSIC original song136 transition, preserved=13 result=0/12 resources=33 samples=21 tick=%u\n",g_macTicks
 detach
 quit 0
end
continue
echo FAIL GAMEPLAY MUSIC unexpected debugger stop\n
detach
quit 1
