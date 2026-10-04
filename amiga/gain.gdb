# CPU-executed death-fade service over active interrupt-driven MONSTER music.
set pagination off
set confirm off
set $pairs=0
set $active=0
set $newnotes=0
break AitdScreen::showLoudStop
commands
 silent
 printf "FAIL GAIN %s / %s\n",manager,routine
 detach
 quit 1
end
break aitdGainProbeCall
commands
 silent
 if *(unsigned long*)$sp!=19 || *(unsigned long*)($sp+4)!=256-$pairs*8
  echo FAIL GAIN arguments\n
  detach
  quit 1
 end
 set $savedSP=$sp
 set $r2=$d2
 set $r3=$d3
 set $r4=$d4
 set $r5=$d5
 set $r6=$d6
 set $r7=$d7
 set $a0saved=$a0
 set $a1saved=$a1
 set $a2saved=$a2
 set $a3saved=$a3
 set $a4saved=$a4
 set $a5saved=$a5
 set $a6saved=$a6
 set $starts=g_song.starts
 set $steals=g_song.steals
 set $channels0=g_soundDriver.channels[0]
 set $channels1=g_soundDriver.channels[1]
 set $channels2=g_soundDriver.channels[2]
 set $channels3=g_soundDriver.channels[3]
 continue
end
break aitdGainProbeReturn
commands
 silent
 if $sp!=$savedSP || $d0 || $d1!=65535 || ($ps&31)!=4 || $d2!=$r2 || $d3!=$r3 || $d4!=$r4 || $d5!=$r5 || $d6!=$r6 || $d7!=$r7 || $a0!=$a0saved || $a1!=$a1saved || $a2!=$a2saved || $a3!=$a3saved || $a4!=$a4saved || $a5!=$a5saved || $a6!=$a6saved
  echo FAIL GAIN return ABI\n
  detach
  quit 1
 end
 if g_song.starts!=$starts || g_song.steals!=$steals || g_soundDriver.channels[0]!=$channels0 || g_soundDriver.channels[1]!=$channels1 || g_soundDriver.channels[2]!=$channels2 || g_soundDriver.channels[3]!=$channels3
  echo FAIL GAIN voice ownership\n
  detach
  quit 1
 end
 set $pairs=$pairs+1
 continue
end
break aitdGainProbeStep
commands
 silent
 set $i=0
 while $i<4
  if g_soundDriver.channels[$i]>=0
   if g_gainProbeVolumes[$i]!=g_soundDriver.masterGain/4
    echo FAIL GAIN Paula write values\n
    detach
    quit 1
   end
   set $active=$active+1
  end
  set $i=$i+1
 end
 if $pairs==33 && g_gainProbeCount==33 && !g_soundDriver.masterGain
  if g_song.starts>$starts
   set $newnotes=1
  end
 end
 printf "GAIN_STEP count=%u gain=%u starts=%u\n",g_gainProbeCount,g_soundDriver.masterGain,g_song.starts
 continue
end
tbreak aitdGainProbeComplete
continue
if $pairs!=33 || !$active || !$newnotes || g_song.playing || g_song.ownedCount || g_song.sampleCount || (*(unsigned short*)0xdff002&15)
 echo FAIL GAIN coverage/cleanup\n
 detach
 quit 1
end
echo PASS GAIN 33 CPU driver calls, preserved ABI, active/new Paula volume writes, ownership and cleanup\n
detach
quit 0
