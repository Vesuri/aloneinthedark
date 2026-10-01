set pagination off
set confirm off
break AitdScreen::showLoudStop
commands
 silent
 printf "FAIL driver5 loud stop: %s / %s selector=%u\n",manager,routine,selector
 detach
 quit 1
end
tbreak *recordKey
continue
tbreak *(g_code3Base+0x1400)
continue
set $d5_sp=$sp
dump binary memory ../tmp/driver5-native-enter-config.bin (char*)&g_soundDriver (char*)&g_soundDriver.songs
set $d5_events=g_song.events
set $d5_data=g_song.description.data
set $d5_owned=g_song.ownedCount
set $d5_samples=g_song.sampleCount
dump binary memory ../tmp/driver5-native-enter-effects.bin (char*)&g_soundDriver.effects (char*)&g_soundDriver.channels
dump binary memory ../tmp/driver5-native-enter-resources.bin (char*)&g_song.owned (char*)&g_song.owned+sizeof(g_song.owned)
if *(unsigned long*)(g_code3Base+0x13f8)!=0x48780005 || *(unsigned long*)(g_code3Base+0x13fc)!=0x206df954 || *(unsigned long*)(g_code3Base+0x1400)!=0x4e90588f
 echo FAIL driver5 original caller bytes\n
 detach
 quit 1
end
if *(unsigned long*)$sp!=5 || g_song.description.data==0
 echo FAIL driver5 original request or song state\n
 detach
 quit 1
end
echo DRIVER5_NATIVE_BYTES 48780005206DF9544E90588F\n
set $d5_d2=$d2
set $d5_d3=$d3
set $d5_d4=$d4
set $d5_d5=$d5
set $d5_d6=$d6
set $d5_d7=$d7
set $d5_a0=$a0
set $d5_a1=$a1
set $d5_a2=$a2
set $d5_a3=$a3
set $d5_a4=$a4
set $d5_a5=$a5
set $d5_a6=$a6
tbreak *(g_code3Base+0x1402) if $sp==$d5_sp
continue
if $pc!=(unsigned long)(g_code3Base+0x1402) || $sp!=$d5_sp || $d0!=0 || $d1!=0xffff || ($sr&31)!=4
 echo FAIL driver5 native return\n
 detach
 quit 1
end
if $d2!=$d5_d2
 echo FAIL driver5 preserved d2\n
 detach
 quit 1
end
if $d3!=$d5_d3
 echo FAIL driver5 preserved d3\n
 detach
 quit 1
end
if $d4!=$d5_d4
 echo FAIL driver5 preserved d4\n
 detach
 quit 1
end
if $d5!=$d5_d5
 echo FAIL driver5 preserved d5\n
 detach
 quit 1
end
if $d6!=$d5_d6
 echo FAIL driver5 preserved d6\n
 detach
 quit 1
end
if $d7!=$d5_d7
 echo FAIL driver5 preserved d7\n
 detach
 quit 1
end
if $a0!=$d5_a0
 echo FAIL driver5 preserved a0\n
 detach
 quit 1
end
if $a1!=$d5_a1
 echo FAIL driver5 preserved a1\n
 detach
 quit 1
end
if $a2!=$d5_a2
 echo FAIL driver5 preserved a2\n
 detach
 quit 1
end
if $a3!=$d5_a3
 echo FAIL driver5 preserved a3\n
 detach
 quit 1
end
if $a4!=$d5_a4
 echo FAIL driver5 preserved a4\n
 detach
 quit 1
end
if $a5!=$d5_a5
 echo FAIL driver5 preserved a5\n
 detach
 quit 1
end
if $a6!=$d5_a6
 echo FAIL driver5 preserved a6\n
 detach
 quit 1
end
if g_song.playing || g_song.timeline.active || g_soundDriver.songControl || g_song.description.data!=$d5_data || g_song.ownedCount!=$d5_owned || g_song.sampleCount!=$d5_samples
 echo FAIL driver5 stop or resource retention\n
 detach
 quit 1
end
set $i=0
while $i<6
 if g_soundDriver.songs[$i].active || g_soundDriver.songs[$i].channel!=-1 || g_song.voices[$i].chip || g_song.voices[$i].allocated
  echo FAIL driver5 music DMA cleanup\n
  detach
  quit 1
 end
 set $i=$i+1
end
dump binary memory ../tmp/driver5-native-return-effects.bin (char*)&g_soundDriver.effects (char*)&g_soundDriver.channels
dump binary memory ../tmp/driver5-native-return-resources.bin (char*)&g_song.owned (char*)&g_song.owned+sizeof(g_song.owned)
dump binary memory ../tmp/driver5-native-return-config.bin (char*)&g_soundDriver (char*)&g_soundDriver.songs
printf "DRIVER5_NATIVE_RETURN d0=%X d1=%X ccr=%X eventsBefore=%u eventsAfter=%u active=%u\n",$d0,$d1,$sr&31,$d5_events,g_song.events,g_song.timeline.active
echo PASS native driver5 stop ABI\n
detach
quit 0
