set $d4_sp=$sp
dump binary memory ../tmp/driver4-native-enter-config.bin (char*)&g_soundDriver (char*)&g_soundDriver.songs
set $d4_events=g_song.events
if *(unsigned long*)(g_code3Base+0x1fc0)!=0x48780004 || *(unsigned long*)(g_code3Base+0x1fc4)!=0x206df954 || *(unsigned long*)(g_code3Base+0x1fc8)!=0x4e90588f
 echo FAIL driver4 original caller bytes\n
 detach
 quit 1
end
if *(unsigned long*)$sp!=4 || g_song.description.data==0 || !g_song.timeline.active || g_soundDriver.songControl!=0
 echo FAIL driver4 original request or song state\n
 detach
 quit 1
end
echo DRIVER4_NATIVE_BYTES 48780004206DF9544E90588F\n
set $d4_d2=$d2
set $d4_d3=$d3
set $d4_d4=$d4
set $d4_d5=$d5
set $d4_d6=$d6
set $d4_d7=$d7
set $d4_a0=$a0
set $d4_a1=$a1
set $d4_a2=$a2
set $d4_a3=$a3
set $d4_a4=$a4
set $d4_a5=$a5
set $d4_a6=$a6
tbreak *(g_code3Base+0x1fca) if $sp==$d4_sp
continue
if $pc!=(unsigned long)(g_code3Base+0x1fca) || $sp!=$d4_sp || $d0!=0xffff || $d1!=23 || ($sr&31)!=8
 echo FAIL driver4 native return\n
 detach
 quit 1
end
if $d2!=$d4_d2
 echo FAIL driver4 preserved d2\n
 detach
 quit 1
end
if $d3!=$d4_d3
 echo FAIL driver4 preserved d3\n
 detach
 quit 1
end
if $d4!=$d4_d4
 echo FAIL driver4 preserved d4\n
 detach
 quit 1
end
if $d5!=$d4_d5
 echo FAIL driver4 preserved d5\n
 detach
 quit 1
end
if $d6!=$d4_d6
 echo FAIL driver4 preserved d6\n
 detach
 quit 1
end
if $d7!=$d4_d7
 echo FAIL driver4 preserved d7\n
 detach
 quit 1
end
if $a0!=$d4_a0
 echo FAIL driver4 preserved a0\n
 detach
 quit 1
end
if $a1!=$d4_a1
 echo FAIL driver4 preserved a1\n
 detach
 quit 1
end
if $a2!=$d4_a2
 echo FAIL driver4 preserved a2\n
 detach
 quit 1
end
if $a3!=$d4_a3
 echo FAIL driver4 preserved a3\n
 detach
 quit 1
end
if $a4!=$d4_a4
 echo FAIL driver4 preserved a4\n
 detach
 quit 1
end
if $a5!=$d4_a5
 echo FAIL driver4 preserved a5\n
 detach
 quit 1
end
if $a6!=$d4_a6
 echo FAIL driver4 preserved a6\n
 detach
 quit 1
end
dump binary memory ../tmp/driver4-native-return-config.bin (char*)&g_soundDriver (char*)&g_soundDriver.songs
printf "DRIVER4_NATIVE_RETURN d0=%X d1=%X ccr=%X eventsBefore=%u eventsAfter=%u active=%u\n",$d0,$d1,$sr&31,$d4_events,g_song.events,g_song.timeline.active
echo PASS native driver4 status ABI\n
