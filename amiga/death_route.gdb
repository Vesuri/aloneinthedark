# Ordinary control sequence, natural death call and fresh Carnby game.
set pagination off
set confirm off
break AitdScreen::showLoudStop
commands
 silent
 printf "FAIL DEATH ROUTE %s / %s selector=%d\n",manager,routine,g_trapSelector
 detach
 quit 1
end
tbreak getFontNumber
continue
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
 if *(short*)($actor+0x3e)!=261 || *(short*)($actor+0x30) || *(short*)($actor+0x32)
  echo FAIL DEATH ROUTE natural death state\n
  detach
  quit 1
 end
 printf "DEATH_ENTER song=131 tick=%u anim=%d room=%d floor=%d\n",g_macTicks,*(short*)($actor+0x3e),*(short*)($actor+0x30),*(short*)($actor+0x32)
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
break aitdInputDeathRouteCheckpoint
commands
 silent
 printf "DEATH_ROUTE_STAGE stage=%u tick=%u\n",g_deathRouteStage,g_macTicks
 set $world=(unsigned long)s_a5WorldStorage+75616
 set $actor=$world-0xb292+160
 printf "DEATH_STATE tick=%u mode=%u room=%d floor=%d anim=%d x=%d z=%d word88=%d\n",g_macTicks,*(unsigned char*)($world-0x11b4c),*(short*)($world-0xcd68),*(short*)($actor+0x32),*(short*)($actor+0x3e),*(short*)($actor+0x1c),*(short*)($actor+0x20),*(short*)($actor+88)
 dump binary memory ../tmp/m3-death/death-wait-native-actors.bin $world-0xb292 $world-0xb292+16000
 if g_deathRouteStage==65535
  echo FAIL DEATH ROUTE state deadline\n
  detach
  quit 1
 end
 if g_deathRouteStage==4
  if !$deathSongReturned
   echo FAIL DEATH ROUTE menu without natural death song\n
   detach
   quit 1
  end
  set $deathMenuSeen=1
  set $deathMenuFrames=g_macFramesPresented
 end
 if g_deathRouteStage!=5
  continue
 end
end
continue
if g_deathRouteStage!=5 || !$deathMenuSeen || !$deathSongReturned
 echo FAIL DEATH ROUTE restart prerequisites\n
 detach
 quit 1
end
set $dark=(unsigned long)s_segments[4].begin
tbreak *($dark+0x5658)
continue
tbreak *($dark+0x5658)
continue
set $world=(unsigned long)s_a5WorldStorage+75616
set $actor=$world-0xb292+160
if *(short*)$actor!=1 || *(short*)($actor+2)!=12 || *(short*)($actor+0x1c)!=3231 || *(short*)($actor+0x20)!=-1548 || *(short*)($actor+0x30) || *(short*)($actor+0x32) || *(short*)($actor+0x3e)!=4 || *(unsigned char*)($world-0x11b4c)!=1 || g_macFramesPresented<=$deathMenuFrames || s_keyDown[0x4d] || s_keyDown[0x4c] || s_keyDown[0x60] || s_keyDown[0x23] || s_keyDown[0x40] || s_keyDown[0x44] || s_keyDown[0x4e] || s_keyDown[0x45]
 echo FAIL DEATH ROUTE restored actor/publication/input\n
 detach
 quit 1
end
printf "DEATH_RESTART tick=%u actor=%d body=%d x=%d z=%d anim=%d room=%d floor=%d frames=%u\n",g_macTicks,*(short*)$actor,*(short*)($actor+2),*(short*)($actor+0x1c),*(short*)($actor+0x20),*(short*)($actor+0x3e),*(short*)($actor+0x30),*(short*)($actor+0x32),g_macFramesPresented
dump binary memory ../tmp/m3-death/death-restart-native-screen.bin s_colorScreen s_colorScreen+307200
dump binary memory ../tmp/m3-death/death-restart-native-clut.bin s_windowManagerColors s_windowManagerColors+2056
dump binary memory ../tmp/m3-death/death-restart-native-actor.bin $actor $actor+160
echo PASS DEATH ROUTE natural death music ABI and new-game restart\n
detach
quit 0
echo FAIL DEATH ROUTE unexpected debugger stop\n
detach
quit 1
