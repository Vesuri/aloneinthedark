set pagination off
set confirm off
break AitdScreen::showLoudStop
commands
 silent
 printf "FAIL driver7 loud stop: %s / %s selector=%u\n",manager,routine,selector
 detach
 quit 1
end
tbreak *recordKey
continue
tbreak *(g_code3Base+0x140c)
continue
set $d7_sp=$sp
set $d7_argument=*(unsigned long*)($sp+4)
dump binary memory ../tmp/driver7-native-enter-config.bin (char*)&g_soundDriver (char*)&g_soundDriver.songs
set $d7_events=g_song.events
set $d7_data=g_song.description.data
set $d7_owned=g_song.ownedCount
set $d7_samples=g_song.sampleCount
set $i=0
while $i<$d7_owned
 set $h=(unsigned long)g_song.owned[$i].handle
 set $body=*(unsigned long*)$h
 set $arena=(unsigned long)s_applicationZone.arena_
 if $h>=(unsigned long)s_systemZone.arena_ && $h<(unsigned long)s_systemZone.arena_+s_systemZone.bytes_
  set $arena=(unsigned long)s_systemZone.arena_
 end
 set $flag=$arena+*(unsigned long*)($body-8)
 if *(unsigned long*)($body-12)!=2 || (*(unsigned char*)$flag&1)==0
  echo FAIL driver7 owned handle metadata\n
  detach
  quit 1
 end
 eval "set $d7_h_%u=%u",$i,$h
 eval "set $d7_f_%u=%u",$i,$flag
 printf "DRIVER7_HANDLE_ENTER n=%u handle=%X body=%X flag=%X\n",$i,$h,$body,*(unsigned char*)$flag
 set $i=$i+1
end
dump binary memory ../tmp/driver7-native-enter-effects.bin (char*)&g_soundDriver.effects (char*)&g_soundDriver.channels
dump binary memory ../tmp/driver7-native-enter-resources.bin (char*)&g_song.owned (char*)&g_song.owned+sizeof(g_song.owned)
if *(unsigned long*)(g_code3Base+0x1404)!=0x48780007 || *(unsigned long*)(g_code3Base+0x1408)!=0x206df954 || *(unsigned long*)(g_code3Base+0x140c)!=0x4e90588f
 echo FAIL driver7 original caller bytes\n
 detach
 quit 1
end
if *(unsigned long*)$sp!=7 || g_song.description.data==0
 echo FAIL driver7 original request or song state\n
 detach
 quit 1
end
echo DRIVER7_NATIVE_BYTES 48780007206DF9544E90588F\n
set $d7_d2=$d2
set $d7_d3=$d3
set $d7_d4=$d4
set $d7_d5=$d5
set $d7_d6=$d6
set $d7_d7=$d7
set $d7_a0=$a0
set $d7_a1=$a1
set $d7_a2=$a2
set $d7_a3=$a3
set $d7_a4=$a4
set $d7_a5=$a5
set $d7_a6=$a6
tbreak *(g_code3Base+0x140e) if $sp==$d7_sp
continue
if $pc!=(unsigned long)(g_code3Base+0x140e) || $sp!=$d7_sp || $d0!=0 || $d1!=$d7_argument || ($sr&31)!=4
 echo FAIL driver7 native return\n
 detach
 quit 1
end
if $d2!=$d7_d2
 echo FAIL driver7 preserved d2\n
 detach
 quit 1
end
if $d3!=$d7_d3
 echo FAIL driver7 preserved d3\n
 detach
 quit 1
end
if $d4!=$d7_d4
 echo FAIL driver7 preserved d4\n
 detach
 quit 1
end
if $d5!=$d7_d5
 echo FAIL driver7 preserved d5\n
 detach
 quit 1
end
if $d6!=$d7_d6
 echo FAIL driver7 preserved d6\n
 detach
 quit 1
end
if $d7!=$d7_d7
 echo FAIL driver7 preserved d7\n
 detach
 quit 1
end
if $a0!=$d7_a0
 echo FAIL driver7 preserved a0\n
 detach
 quit 1
end
if $a1!=$d7_a1
 echo FAIL driver7 preserved a1\n
 detach
 quit 1
end
if $a2!=$d7_a2
 echo FAIL driver7 preserved a2\n
 detach
 quit 1
end
if $a3!=$d7_a3
 echo FAIL driver7 preserved a3\n
 detach
 quit 1
end
if $a4!=$d7_a4
 echo FAIL driver7 preserved a4\n
 detach
 quit 1
end
if $a5!=$d7_a5
 echo FAIL driver7 preserved a5\n
 detach
 quit 1
end
if $a6!=$d7_a6
 echo FAIL driver7 preserved a6\n
 detach
 quit 1
end
if g_song.playing || g_song.timeline.active || g_soundDriver.songControl || g_song.description.data || g_song.ownedCount || g_song.sampleCount
 echo FAIL driver7 release state\n
 detach
 quit 1
end
set $i=0
while $i<$d7_owned
 eval "set $h=$d7_h_%u",$i
 eval "set $flag=$d7_f_%u",$i
 # MacHeap::publish links free master slots through their pointer words.
 # The allocation flag and cleared owner ledger identify disposal.
 if *(unsigned char*)$flag || g_song.owned[$i].handle
  echo FAIL driver7 owned handle not disposed\n
  detach
  quit 1
 end
 printf "DRIVER7_HANDLE_RETURN n=%u handle=%X freeNext=%X flag=%X\n",$i,$h,*(unsigned long*)$h,*(unsigned char*)$flag
 set $i=$i+1
end
set $i=0
while $i<6
 if g_soundDriver.songs[$i].active || g_soundDriver.songs[$i].channel!=-1 || g_song.voices[$i].chip || g_song.voices[$i].allocated
  echo FAIL driver7 music DMA cleanup\n
  detach
  quit 1
 end
 set $i=$i+1
end
dump binary memory ../tmp/driver7-native-return-effects.bin (char*)&g_soundDriver.effects (char*)&g_soundDriver.channels
dump binary memory ../tmp/driver7-native-return-resources.bin (char*)&g_song.owned (char*)&g_song.owned+sizeof(g_song.owned)
dump binary memory ../tmp/driver7-native-return-config.bin (char*)&g_soundDriver (char*)&g_soundDriver.songs
printf "DRIVER7_NATIVE_RETURN d0=%X d1=%X ccr=%X eventsBefore=%u eventsAfter=%u active=%u\n",$d0,$d1,$sr&31,$d7_events,g_song.events,g_song.timeline.active
echo PASS native driver7 release ABI\n
detach
quit 0
