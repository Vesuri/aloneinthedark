set pagination off
set confirm off
break AitdScreen::showLoudStop
commands
 silent
 printf "FAIL SYSBEEP %s / %s\n",manager,routine
 detach
 quit 1
end
tbreak aitdSysBeepProbeTrap
continue
set $beep_sp=$sp
set $beep_d1=$d1
set $beep_d2=$d2
set $beep_d3=$d3
set $beep_d4=$d4
set $beep_d5=$d5
set $beep_d6=$d6
set $beep_d7=$d7
set $beep_a1=$a1
set $beep_a2=$a2
set $beep_a3=$a3
set $beep_a4=$a4
set $beep_a5=$a5
set $beep_a6=$a6
set $beep_live=g_m5Audit.liveChip
set $beep_tick=g_macTicks
set $beep_music=g_musicTicks
set $beep_steals=g_song.steals
if *(unsigned short*)$sp!=1 || !g_soundDriver.effects[0].active || g_effects[0].ends-g_macTicks<6
 echo FAIL SYSBEEP active effect positive control\n
 detach
 quit 1
end
set $beep_effect=g_soundDriver.effects[0].channel
set $beep_effect_chip=g_effects[0].chip
dump binary memory ../tmp/m4/sysbeep/native-effects-before.bin (char*)g_soundDriver.effects (char*)g_soundDriver.effects+sizeof(g_soundDriver.effects)
printf "SYSBEEP_NATIVE_ENTER sp=%X tick=%u music=%u steals=%u effectChannel=%d effectChip=%X\n",$sp,g_macTicks,g_musicTicks,g_song.steals,$beep_effect,$beep_effect_chip
tbreak aitdSysBeepStarted
continue
set $beep_channel=channel
set $beep_chip=chip
if channel>3 || channel==$beep_effect || g_soundDriver.channels[channel]!=8 || allocated!=130 || period!=443 || g_m5Audit.liveChip!=$beep_live+136 || g_m5Audit.accountingErrors
 echo FAIL SYSBEEP click allocation\n
 detach
 quit 1
end
dump binary memory ../tmp/m4/sysbeep/native-chip.bin chip chip+allocated
printf "SYSBEEP_NATIVE_STARTED channel=%u chip=%X allocated=%u period=%u dma=%X\n",channel,chip,allocated,period,*(unsigned short*)0xdff002
tbreak aitdSysBeepProbeReturn
continue
if $sp!=$beep_sp+2 || $d0 || $d1!=$beep_d1 || $d2!=$beep_d2 || $d3!=$beep_d3 || $d4!=$beep_d4 || $d5!=$beep_d5 || $d6!=$beep_d6 || $d7!=$beep_d7 || $a1!=$beep_a1 || $a2!=$beep_a2 || $a3!=$beep_a3 || $a4!=$beep_a4 || $a5!=$beep_a5 || $a6!=$beep_a6 || g_macTicks-$beep_tick<3 || g_musicTicks-$beep_music<3 || g_song.steals!=$beep_steals+1
 echo FAIL SYSBEEP ABI or interrupt progress\n
 detach
 quit 1
end
if g_m5Audit.liveChip!=$beep_live || g_m5Audit.accountingErrors || g_soundDriver.channels[$beep_channel]!=-1 || (*(unsigned short*)0xdff002&(1<<$beep_channel)) || g_effects[0].chip!=$beep_effect_chip || g_soundDriver.effects[0].channel!=$beep_effect || !g_soundDriver.effects[0].active
 echo FAIL SYSBEEP cleanup/effect isolation\n
 detach
 quit 1
end
dump binary memory ../tmp/m4/sysbeep/native-effects-after.bin (char*)g_soundDriver.effects (char*)g_soundDriver.effects+sizeof(g_soundDriver.effects)
printf "SYSBEEP_NATIVE_RETURN sp=%X tick=%u music=%u steals=%u dma=%X\n",$sp,g_macTicks,g_musicTicks,g_song.steals,*(unsigned short*)0xdff002
printf "SYSBEEP_NATIVE_LEDGER before=%u after=%u errors=%u\n",$beep_live,g_m5Audit.liveChip,g_m5Audit.accountingErrors
echo PASS native SysBeep actual trap, priority click, interrupt progress and cleanup\n
detach
quit 0
