# Isolated native counterpart to mac_effect_slots.lua; no debugger RAM writes.
set pagination off
set confirm off
set width 0
break AitdScreen::showLoudStop
commands
 silent
 printf "FAIL effect slots %s / %s\n",manager,routine
 detach
 quit 1
end
break aitdEffectSlotsCheckpoint
continue
if stage!=0 || g_soundDriver.effectLimit!=2 || g_effectStarts || g_effectStops || g_soundDriver.effects[0].active || g_soundDriver.effects[1].active
 echo FAIL effect slots initial state\n
 detach
 quit 1
end
set $slots_base=g_m5Audit.liveChip
set $slots_high=scratch&0xffff0000
set $slots_stage=1
while $slots_stage<=4
 continue
 if stage!=$slots_stage || g_effectStarts!=stage || (scratch&0xffff0000)!=$slots_high
  echo FAIL effect slots stage\n
  detach
  quit 1
 end
 set $slots_index=(stage==2 || stage==4)
 set $slots_age=stage==1 ? 0x7fff : stage==2 ? 0x7ffe : 0x7ff0
 if (scratch&0xffff)!=$slots_age || g_effects[$slots_index].id!=0x8000+stage || !g_soundDriver.effects[$slots_index].active || !g_effects[$slots_index].chip
  echo FAIL effect slots selected voice and return age\n
  detach
  quit 1
 end
 if g_effects[$slots_index].size!=4096 || g_effects[$slots_index].allocated!=4098 || g_effects[$slots_index].period!=443
  echo FAIL effect slots sample descriptor\n
  detach
  quit 1
 end
 set $slots_channel=g_soundDriver.effects[$slots_index].channel
 if $slots_channel<0 || $slots_channel>3 || g_soundDriver.channels[$slots_channel]!=6+$slots_index || !(*(unsigned short*)0xdff002&(1<<$slots_channel))
  echo FAIL effect slots Paula ownership\n
  detach
  quit 1
 end
 if stage==1
  set $slots_channel0=$slots_channel
 else
  if !g_soundDriver.effects[0].active || !g_soundDriver.effects[1].active || g_soundDriver.effects[0].channel==g_soundDriver.effects[1].channel || g_soundDriver.effects[0].channel!=$slots_channel0
   echo FAIL two active isolated effect channels\n
   detach
   quit 1
  end
  if stage==2
   set $slots_channel1=$slots_channel
   set $slots_other_chip=g_effects[1].chip
  else
   if g_soundDriver.effects[1].channel!=$slots_channel1 || (stage==3 && g_effects[1].chip!=$slots_other_chip) || (stage==4 && g_effects[0].chip!=$slots_other_chip)
    echo FAIL retained channel/unselected buffer\n
    detach
    quit 1
   end
   set $slots_other_chip=g_effects[0].chip
  end
 end
 set $slots_count=stage==1 ? 1 : 2
 if g_m5Audit.liveChip!=$slots_base+4104*$slots_count || g_m5Audit.accountingErrors || g_effectStops!=(stage>2 ? stage-2 : 0)
  echo FAIL replacement allocation ledger\n
  detach
  quit 1
 end
 eval "dump binary memory ../tmp/m4/effects/slots/native-chip-%u.bin %u %u",stage,g_effects[$slots_index].chip,g_effects[$slots_index].chip+4098
 printf "EFFECT_SLOTS stage=%u index=%u age=%X channel=%u starts=%u stops=%u live=%u\n",stage,$slots_index,scratch&0xffff,$slots_channel,g_effectStarts,g_effectStops,g_m5Audit.liveChip
 set $slots_stage=$slots_stage+1
end
continue
if stage!=9 || g_m5Audit.liveChip!=$slots_base || g_m5Audit.accountingErrors || g_effectStarts!=4 || g_effectStops!=4 || g_soundDriver.effects[0].active || g_soundDriver.effects[1].active || g_effects[0].chip || g_effects[1].chip || (*(unsigned short*)0xdff002&((1<<$slots_channel0)|(1<<$slots_channel1)))
 echo FAIL effect slots final cleanup\n
 detach
 quit 1
end
printf "EFFECT_SLOTS_CLEANUP live=%u baseline=%u errors=%u\n",g_m5Audit.liveChip,$slots_base,g_m5Audit.accountingErrors
echo PASS native effect slots selection, replacement and cleanup\n
detach
quit 0
