set pagination off
set confirm off
set width 0
break AitdScreen::showLoudStop
commands
 silent
 printf "FAIL DRIVER6 %s / %s\n",manager,routine
 detach
 quit 1
end
tbreak aitdDriver6Ready
continue
set $original_sp=(unsigned long)userStack
set $return=*(unsigned long*)$original_sp
set $argument=*(unsigned long*)($original_sp+8)
set $calls=g_soundDriverCalls
set $music_tick=g_musicTicks
set $effect_tick=g_macTicks
set $dma_before=*(unsigned short*)0xdff002
printf "DRIVER6_NATIVE_ENTER sp=%X argument=%X musicTick=%u effectTick=%u dma=%X\n",$original_sp,$argument,$music_tick,$effect_tick,$dma_before
printf "DRIVER6_NATIVE_LAYOUT songSize=%u voices=%u voiceSize=%u driverSize=%u\n",sizeof(g_song),(char*)g_song.voices-(char*)&g_song,sizeof(g_song.voices[0]),sizeof(g_soundDriver)
set $saved_d2=regs[2]
set $saved_d3=regs[3]
set $saved_d4=regs[4]
set $saved_d5=regs[5]
set $saved_d6=regs[6]
set $saved_d7=regs[7]
set $saved_a0=regs[8]
set $saved_a1=regs[9]
set $saved_a2=regs[10]
set $saved_a3=regs[11]
set $saved_a4=regs[12]
set $saved_a5=regs[13]
set $saved_a6=regs[14]
dump binary memory ../tmp/m4/driver6/native/driver-before.bin (char*)&g_soundDriver (char*)&g_soundDriver+sizeof(g_soundDriver)
dump binary memory ../tmp/m4/driver6/native/song-before.bin (char*)&g_song (char*)&g_song+sizeof(g_song)
dump binary memory ../tmp/m4/driver6/native/effects-before.bin (char*)&g_effects (char*)&g_effects+sizeof(g_effects)
tbreak *$return
continue
printf "DRIVER6_NATIVE_ABI sp=%X expected=%X d0=%X d1=%X argument=%X ccr=%X calls=%u expectedCalls=%u\n",$sp,$original_sp+4,$d0,$d1,$argument,$ps&31,g_soundDriverCalls,$calls+1
if $sp!=$original_sp+4 || $d0!=0 || $d1!=$argument || ($ps&31)!=4 || g_soundDriverCalls!=$calls+1
 echo FAIL driver6 native ABI\n
 detach
 quit 1
end
if $d2!=$saved_d2
 echo FAIL driver6 preserved d2\n
 detach
 quit 1
end
if $d3!=$saved_d3
 echo FAIL driver6 preserved d3\n
 detach
 quit 1
end
if $d4!=$saved_d4
 echo FAIL driver6 preserved d4\n
 detach
 quit 1
end
if $d5!=$saved_d5
 echo FAIL driver6 preserved d5\n
 detach
 quit 1
end
if $d6!=$saved_d6
 echo FAIL driver6 preserved d6\n
 detach
 quit 1
end
if $d7!=$saved_d7
 echo FAIL driver6 preserved d7\n
 detach
 quit 1
end
if $a0!=$saved_a0
 echo FAIL driver6 preserved a0\n
 detach
 quit 1
end
if $a1!=$saved_a1
 echo FAIL driver6 preserved a1\n
 detach
 quit 1
end
if $a2!=$saved_a2
 echo FAIL driver6 preserved a2\n
 detach
 quit 1
end
if $a3!=$saved_a3
 echo FAIL driver6 preserved a3\n
 detach
 quit 1
end
if $a4!=$saved_a4
 echo FAIL driver6 preserved a4\n
 detach
 quit 1
end
if $a5!=$saved_a5
 echo FAIL driver6 preserved a5\n
 detach
 quit 1
end
if $a6!=$saved_a6
 echo FAIL driver6 preserved a6\n
 detach
 quit 1
end
dump binary memory ../tmp/m4/driver6/native/driver-after.bin (char*)&g_soundDriver (char*)&g_soundDriver+sizeof(g_soundDriver)
dump binary memory ../tmp/m4/driver6/native/song-after.bin (char*)&g_song (char*)&g_song+sizeof(g_song)
dump binary memory ../tmp/m4/driver6/native/effects-after.bin (char*)&g_effects (char*)&g_effects+sizeof(g_effects)
printf "DRIVER6_NATIVE_RETURN musicTick=%u effectTick=%u dma=%X\n",g_musicTicks,g_macTicks,*(unsigned short*)0xdff002
echo PASS native driver6 return ABI\n
detach
quit 0
