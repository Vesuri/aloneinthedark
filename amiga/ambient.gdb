set pagination off
set confirm off
set width 0
break AitdScreen::showLoudStop
commands
 silent
 printf "FAIL ambient %s / %s\n",manager,routine
 detach
 quit 1
end
tbreak aitdAmbientEffectReady
continue
set $ambient_sp=(unsigned long)userStack
set $ambient_return=*(unsigned long*)$ambient_sp
set $ambient_packet=*(unsigned long*)($ambient_sp+8)
set $ambient_sample=*(unsigned long*)$ambient_packet
set $ambient_size=*(unsigned long*)($ambient_packet+4)
set $ambient_starts=g_effectStarts
set $ambient_stops=g_effectStops
set $ambient_world=(unsigned long)s_a5WorldStorage+75616
dump binary memory ../tmp/m4/ambient/native-current/packet.bin $ambient_packet $ambient_packet+26
dump binary memory ../tmp/m4/ambient/native-current/source.bin $ambient_sample $ambient_sample+$ambient_size
dump binary memory ../tmp/m4/ambient/native-current/actors.bin $ambient_world-0xb292 $ambient_world-0xb292+8000
set $ambient_d2=regs[2]
set $ambient_d3=regs[3]
set $ambient_d4=regs[4]
set $ambient_d5=regs[5]
set $ambient_d6=regs[6]
set $ambient_d7=regs[7]
set $ambient_a0=regs[8]
set $ambient_a1=regs[9]
set $ambient_a2=regs[10]
set $ambient_a3=regs[11]
set $ambient_a4=regs[12]
set $ambient_a5=regs[13]
set $ambient_a6=regs[14]
tbreak *$ambient_return if $sp==$ambient_sp+4
continue
printf "AMBIENT_NATIVE_ABI d0=%X d1=%X packet=%X ccr=%X starts=%u stops=%u\n",$d0,$d1,$ambient_packet,$ps&31,g_effectStarts,g_effectStops
if $d0!=0 || $d1!=(($ambient_packet&0xffff0000)|0x7fff) || ($ps&31)!=4
 echo FAIL ambient return ABI\n
 detach
 quit 1
end
if $d2!=$ambient_d2
 echo FAIL ambient preserved d2\n
 detach
 quit 1
end
if $d3!=$ambient_d3
 echo FAIL ambient preserved d3\n
 detach
 quit 1
end
if $d4!=$ambient_d4
 echo FAIL ambient preserved d4\n
 detach
 quit 1
end
if $d5!=$ambient_d5
 echo FAIL ambient preserved d5\n
 detach
 quit 1
end
if $d6!=$ambient_d6
 echo FAIL ambient preserved d6\n
 detach
 quit 1
end
if $d7!=$ambient_d7
 echo FAIL ambient preserved d7\n
 detach
 quit 1
end
if $a0!=$ambient_a0
 echo FAIL ambient preserved a0\n
 detach
 quit 1
end
if $a1!=$ambient_a1
 echo FAIL ambient preserved a1\n
 detach
 quit 1
end
if $a2!=$ambient_a2
 echo FAIL ambient preserved a2\n
 detach
 quit 1
end
if $a3!=$ambient_a3
 echo FAIL ambient preserved a3\n
 detach
 quit 1
end
if $a4!=$ambient_a4
 echo FAIL ambient preserved a4\n
 detach
 quit 1
end
if $a5!=$ambient_a5
 echo FAIL ambient preserved a5\n
 detach
 quit 1
end
if $a6!=$ambient_a6
 echo FAIL ambient preserved a6\n
 detach
 quit 1
end
set $ambient_channel=g_soundDriver.effects[0].channel
set $ambient_started=g_effects[0].started
set $ambient_end=g_effects[0].ends
if g_effectStarts!=$ambient_starts+1 || g_effectStops!=$ambient_stops || !g_soundDriver.effects[0].active || $ambient_channel<0 || $ambient_channel>3 || !(*(unsigned short*)0xdff002&(1<<$ambient_channel))
 echo FAIL ambient DMA start\n
 detach
 quit 1
end
set $ambient_chip=(unsigned long)g_effects[0].chip
dump binary memory ../tmp/m4/ambient/native-current/chip.bin $ambient_chip $ambient_chip+g_effects[0].allocated
printf "AMBIENT_NATIVE_PLAY size=%u rate=%X period=%u duration=%u channel=%d allocated=%u selected=%u\n",g_effects[0].size,g_effects[0].rate,g_effects[0].period,g_effects[0].ends-$ambient_started-1,$ambient_channel,g_effects[0].allocated,g_ambientProbeSelected
tbreak stopNativeEffect if index==0
continue
if g_macTicks<$ambient_end
 echo FAIL ambient early stop\n
 detach
 quit 1
end
set $ambient_elapsed=g_macTicks-$ambient_started
finish
if g_soundDriver.effects[0].active || g_effects[0].chip || g_effects[0].allocated || g_effectStops!=$ambient_stops+1 || (*(unsigned short*)0xdff002&(1<<$ambient_channel))
 echo FAIL ambient cleanup\n
 detach
 quit 1
end
printf "AMBIENT_NATIVE_COMPLETE elapsed=%u\n",$ambient_elapsed
if g_effectDmaProbeCount!=4 || !g_effectDmaProbeRestored
 echo FAIL ambient DMA timestamps or vector restoration\n
 detach
 quit 1
end
set $i=0
while $i<4
 printf "AMBIENT_DMA_IRQ n=%u clocks=%u hz=%u\n",$i,g_effectDmaProbeIRQ[$i]-g_effectDmaProbeStarted,g_m5Audit.clockHz
 set $i=$i+1
end
echo PASS native isolated ambient playback, DMA, cleanup and ABI\n
detach
quit 0
