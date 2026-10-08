# Ordinary control sequence, natural death call and fresh Carnby game.
set pagination off
set confirm off
# Read live guest stack/code through this custom remote stub.
set stack-cache off
set code-cache off
break AitdScreen::showLoudStop
commands
 silent
 printf "FAIL DEATH ROUTE %s / %s selector=%d\n",manager,routine,g_trapSelector
 detach
 quit 1
end
set $deathSongReturned=0
set $deathMenuSeen=0
break aitdInputDeathRouteCheckpoint
commands
 silent
 if g_deathRouteStage==1
  source death_song_hooks.gdb
 end
 printf "DEATH_ROUTE_STAGE stage=%u tick=%u\n",g_deathRouteStage,g_macTicks
 set $world=(unsigned long)s_a5WorldStorage+75616
 set $actor=$world-0xb292+160
 printf "DEATH_STATE tick=%u mode=%u room=%d floor=%d anim=%d x=%d z=%d word88=%d\n",g_macTicks,*(unsigned char*)($world-0x11b4c),*(short*)($world-0xcd68),*(short*)($actor+0x2e),*(short*)($actor+0x3e),*(short*)($actor+0x1c),*(short*)($actor+0x20),*(short*)($actor+88)
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
if *(short*)$actor!=1 || *(short*)($actor+2)!=12 || *(short*)($actor+0x1c)!=3231 || *(short*)($actor+0x20)!=-1548 || *(short*)($actor+0x30) || *(short*)($actor+0x2e) || *(short*)($actor+0x3e)!=4 || *(unsigned char*)($world-0x11b4c)!=1 || g_macFramesPresented<=$deathMenuFrames || s_keyDown[0x4d] || s_keyDown[0x4c] || s_keyDown[0x60] || s_keyDown[0x23] || s_keyDown[0x40] || s_keyDown[0x44] || s_keyDown[0x4e] || s_keyDown[0x45]
 echo FAIL DEATH ROUTE restored actor/publication/input\n
 detach
 quit 1
end
printf "DEATH_RESTART tick=%u actor=%d body=%d x=%d z=%d anim=%d room=%d floor=%d frames=%u\n",g_macTicks,*(short*)$actor,*(short*)($actor+2),*(short*)($actor+0x1c),*(short*)($actor+0x20),*(short*)($actor+0x3e),*(short*)($actor+0x30),*(short*)($actor+0x2e),g_macFramesPresented
dump binary memory ../tmp/m3-death/death-restart-native-screen.bin s_colorScreen s_colorScreen+307200
dump binary memory ../tmp/m3-death/death-restart-native-clut.bin s_windowManagerColors s_windowManagerColors+2056
dump binary memory ../tmp/m3-death/death-restart-native-actor.bin $actor $actor+160
echo PASS DEATH ROUTE natural death music ABI and new-game restart\n
detach
quit 0
echo FAIL DEATH ROUTE unexpected debugger stop\n
detach
quit 1
