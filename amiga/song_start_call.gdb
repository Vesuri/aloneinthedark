set $song_sp=$sp
if *(unsigned long*)(g_code3Base+0x1382)!=0x2f2e0008 || *(unsigned long*)(g_code3Base+0x1386)!=0x42a7206d || *(unsigned long*)(g_code3Base+0x138a)!=0xf9544e90 || *(unsigned short*)(g_code3Base+0x138e)!=0x508f
 echo FAIL song original caller bytes\n
 detach
 quit 1
end
if *(unsigned long*)$sp!=0 || *(unsigned long*)($sp+4)!=135
 echo FAIL song original request\n
 detach
 quit 1
end
echo SONG_NATIVE_BYTES 2F2E000842A7206DF9544E90508F\n
set $song_d2=$d2
set $song_d3=$d3
set $song_d4=$d4
set $song_d5=$d5
set $song_d6=$d6
set $song_d7=$d7
set $song_a0=$a0
set $song_a1=$a1
set $song_a2=$a2
set $song_a3=$a3
set $song_a4=$a4
set $song_a5=$a5
set $song_a6=$a6
tbreak *(g_code3Base+0x138e) if $sp==$song_sp
continue
if $pc!=(unsigned long)(g_code3Base+0x138e) || $sp!=$song_sp || $d0!=0 || $d1!=12
 echo FAIL song native return\n
 detach
 quit 1
end
if $d2!=$song_d2
 echo FAIL song preserved d2\n
 detach
 quit 1
end
if $d3!=$song_d3
 echo FAIL song preserved d3\n
 detach
 quit 1
end
if $d4!=$song_d4
 echo FAIL song preserved d4\n
 detach
 quit 1
end
if $d5!=$song_d5
 echo FAIL song preserved d5\n
 detach
 quit 1
end
if $d6!=$song_d6
 echo FAIL song preserved d6\n
 detach
 quit 1
end
if $d7!=$song_d7
 echo FAIL song preserved d7\n
 detach
 quit 1
end
if $a0!=$song_a0
 echo FAIL song preserved a0\n
 detach
 quit 1
end
if $a1!=$song_a1
 echo FAIL song preserved a1\n
 detach
 quit 1
end
if $a2!=$song_a2
 echo FAIL song preserved a2\n
 detach
 quit 1
end
if $a3!=$song_a3
 echo FAIL song preserved a3\n
 detach
 quit 1
end
if $a4!=$song_a4
 echo FAIL song preserved a4\n
 detach
 quit 1
end
if $a5!=$song_a5
 echo FAIL song preserved a5\n
 detach
 quit 1
end
if $a6!=$song_a6
 echo FAIL song preserved a6\n
 detach
 quit 1
end
printf "SONG_NATIVE_RETURN song=%u midi=%u playing=%u owned=%u samples=%u voices=%u/%u/%u events=%u pulse=%u step=%X\n",g_song.id,g_song.midiId,g_song.playing,g_song.ownedCount,g_song.sampleCount,g_soundDriver.songLimit,g_soundDriver.normalizedLimit,g_soundDriver.effectLimit,g_song.events,g_song.timeline.pulses,g_song.timeline.step
set $song_i=0
while $song_i<g_song.ownedCount
 set $handle=g_song.owned[$song_i].handle
 set $body=*$handle
 set $size=*(unsigned long*)($body-20)
 set $zone=g_applicationZoneBase
 if $body>=g_systemZoneBase && $body<g_systemZoneBase+s_systemZone.bytes_
  set $zone=g_systemZoneBase
 end
 set $flags=*(unsigned char*)($zone+*(unsigned long*)($body-8))
 printf "SONG_NATIVE_RESOURCE n=%u type=%X id=%u handle=%X body=%X bytes=%u flags=%X\n",$song_i,g_song.owned[$song_i].type,g_song.owned[$song_i].id,$handle,$body,$size,$flags
 if ($flags&0xe0)!=0x80
  echo FAIL song resource flags\n
  detach
  quit 1
 end
 set $ri=0
 while $ri<g_resourceCount
  if s_resourceHandles[$ri]==$handle
   echo FAIL song resource still attached\n
   detach
   quit 1
  end
  set $ri=$ri+1
 end
 eval "dump binary memory ../tmp/song-native-resource-%u.bin %u %u",$song_i,$body,$body+$size
 set $song_i=$song_i+1
end
echo PASS native song return and owned resources\n
