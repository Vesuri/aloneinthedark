set $er_call=(unsigned long)s_segments[3].begin+0x17fc
if *(unsigned short*)$er_call!=0x4e90 || *(unsigned long*)($er_call-6)!=0x0011206d
 echo FAIL occupied effect original caller\n
 detach
 quit 1
end
tbreak *$er_call if g_soundDriver.effectLimit==1 && g_soundDriver.effects[0].active && (int)(g_macTicks-g_effects[0].ends)<0
continue
if $pc!=$er_call
 echo FAIL occupied effect caller not reached\n
 detach
 quit 1
end
set $er_sp=$sp
set $er_packet=*(unsigned long*)($sp+4)
set $er_chip=g_effects[0].chip
set $er_channel=g_soundDriver.effects[0].channel
set $er_started=g_effects[0].started
set $er_tick=g_macTicks
set $er_starts=g_effectStarts
set $er_stops=g_effectStops
printf "EFFECT_NATIVE_ENTER ticks=%u started=%u ends=%u starts=%u stops=%u chip=%X channel=%d packet=%X sp=%X\n",g_macTicks,$er_started,g_effects[0].ends,g_effectStarts,g_effectStops,$er_chip,$er_channel,$er_packet,$sp
dump binary memory ../tmp/effectreplace-native-packet.bin $er_packet $er_packet+26
set $er_sample=*(unsigned long*)$er_packet
set $er_size=*(unsigned long*)($er_packet+4)
dump binary memory ../tmp/effectreplace-native-sample.bin $er_sample $er_sample+$er_size
dump binary memory ../tmp/effectreplace-native-songs-before.bin (char*)g_soundDriver.songs (char*)g_soundDriver.songs+sizeof(g_soundDriver.songs)
set $er_d2=$d2
set $er_d3=$d3
set $er_d4=$d4
set $er_d5=$d5
set $er_d6=$d6
set $er_d7=$d7
set $er_a0=$a0
set $er_a1=$a1
set $er_a2=$a2
set $er_a3=$a3
set $er_a4=$a4
set $er_a5=$a5
set $er_a6=$a6
tbreak *($er_call+2) if $sp==$er_sp
continue
printf "EFFECT_NATIVE_RETURN ticks=%u starts=%u stops=%u chip=%X channel=%d active=%u id=%X d0=%X d1=%X sp=%X\n",g_macTicks,g_effectStarts,g_effectStops,g_effects[0].chip,g_soundDriver.effects[0].channel,g_soundDriver.effects[0].active,g_soundDriver.effectIds[0],$d0,$d1,$sp
if $pc!=$er_call+2 || $sp!=$er_sp || $d0!=0 || ($d1&0xffff0000)!=($er_packet&0xffff0000) || ($d1&0xffff)>0x7ffe-($er_tick-$er_started) || ($d1&0xffff)<0x7ffe-(g_macTicks-$er_started)
 echo FAIL occupied effect return or age\n
 detach
 quit 1
end
if g_effectStarts!=$er_starts+1 || g_effectStops!=$er_stops+1 || !g_soundDriver.effects[0].active || g_soundDriver.effects[0].channel!=$er_channel || g_soundDriver.channels[$er_channel]!=6 || !g_effects[0].chip || g_effects[0].chip==$er_chip
 echo FAIL occupied effect DMA ownership\n
 detach
 quit 1
end
if $d2!=$er_d2
 echo FAIL occupied effect preserved d2\n
 detach
 quit 1
end
if $d3!=$er_d3
 echo FAIL occupied effect preserved d3\n
 detach
 quit 1
end
if $d4!=$er_d4
 echo FAIL occupied effect preserved d4\n
 detach
 quit 1
end
if $d5!=$er_d5
 echo FAIL occupied effect preserved d5\n
 detach
 quit 1
end
if $d6!=$er_d6
 echo FAIL occupied effect preserved d6\n
 detach
 quit 1
end
if $d7!=$er_d7
 echo FAIL occupied effect preserved d7\n
 detach
 quit 1
end
if $a0!=$er_a0
 echo FAIL occupied effect preserved a0\n
 detach
 quit 1
end
if $a1!=$er_a1
 echo FAIL occupied effect preserved a1\n
 detach
 quit 1
end
if $a2!=$er_a2
 echo FAIL occupied effect preserved a2\n
 detach
 quit 1
end
if $a3!=$er_a3
 echo FAIL occupied effect preserved a3\n
 detach
 quit 1
end
if $a4!=$er_a4
 echo FAIL occupied effect preserved a4\n
 detach
 quit 1
end
if $a5!=$er_a5
 echo FAIL occupied effect preserved a5\n
 detach
 quit 1
end
if $a6!=$er_a6
 echo FAIL occupied effect preserved a6\n
 detach
 quit 1
end
dump binary memory ../tmp/effectreplace-native-songs-after.bin (char*)g_soundDriver.songs (char*)g_soundDriver.songs+sizeof(g_soundDriver.songs)
dump binary memory ../tmp/effectreplace-native-chip.bin (char*)g_effects[0].chip (char*)g_effects[0].chip+g_effects[0].allocated
echo PASS native occupied effect replacement\n
