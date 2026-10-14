# Expanded by effect_prepare.sh. Only entry/exit stops occur in each profile.
set pagination off
set confirm off
set width 0
set $prep_completed=0
break AitdScreen::showLoudStop
commands
 silent
 printf "FAIL streamed preparation: %s / %s\n",manager,routine
 detach
 quit 1
end
break aitdEffectPrepBegin
commands
 silent
 set $prep_fast=g_m5Audit.liveFast
 set $prep_chip=g_m5Audit.liveChip
 set $prep_fields=g_vbiCount
 if g_effectPrepCase==0
  maint info sections
  set $i=0
  while $i<32
   if s_segments[$i].begin
    printf "SEG %u %s %x %x\n",$i,s_segments[$i].name,s_segments[$i].begin,s_segments[$i].end
   end
   set $i=$i+1
  end
 end
 monitor aprof start
 continue
end
break aitdEffectPrepEnd
commands
 silent
 eval "monitor aprof stop @OUT@-%u.prof",g_effectPrepCase
 if !g_effectPrepStream || g_effectPrepStream->installed || g_m5Audit.accountingErrors
  echo FAIL preparation ownership/allocation\n
  detach
  quit 1
 end
 set $prep_size=g_effectPrepStream->bytes
 set $prep_expected=((sizeof(EffectDma::Stream)+7)&~7)+(($prep_size+7)&~7)
 if g_m5Audit.liveFast!=$prep_fast+$prep_expected || g_m5Audit.liveChip!=$prep_chip+256
  echo FAIL preparation memory budget\n
  detach
  quit 1
 end
 printf "PREPARATION case=%u bytes=%u fast=%u chip=%u fields=%u\n",g_effectPrepCase,$prep_size,g_m5Audit.liveFast-$prep_fast,g_m5Audit.liveChip-$prep_chip,(unsigned short)(g_vbiCount-$prep_fields)
 continue
end
break aitdEffectPrepReleased
commands
 silent
 if g_effectPrepStream || g_m5Audit.liveFast!=$prep_fast || g_m5Audit.liveChip!=$prep_chip || g_m5Audit.accountingErrors
  echo FAIL preparation release\n
  detach
  quit 1
 end
 set $prep_completed=$prep_completed+1
 continue
end
tbreak aitdEffectLoopReady
continue
if $prep_completed!=6
 printf "FAIL preparation case count: stage=%u ticks=%u calls=%u starts=%u trap=%x pc=%x\n",g_stageBState,g_macTicks,g_soundDriverCalls,g_effectStarts,g_trapWord,g_trapPC
 detach
 quit 1
end
# Stop before playback: six preparations shift the original event timeline.
printf "DELTA fields=0 frames=0 steps=1\n"
echo PASS repeated streamed preparation six cases\n
detach
quit 0
