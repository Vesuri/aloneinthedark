# Event-boundary stops only; frame records are buffered in the guest.
# Template expanded by aprof.sh; see docs/performance.md. Needs the FS-UAE
# built by AmigaXDev (make setup; monitor aprof start/stop).
# @OUT@ is the output prefix; @FRAME_STOPS@ enables the observer-bias control.
set pagination off
set confirm off
set width 0
echo MONSTER_CONFIG fixed_rng=1 deterministic=1 start_scene=200\n
define aprof_segments
 set $i=0
 while $i<32
  if s_segments[$i].begin
   printf "%s %u %s %x %x\n",$arg0,$i,s_segments[$i].name,s_segments[$i].begin,s_segments[$i].end
  end
  set $i=$i+1
 end
end
break AitdScreen::showLoudStop
commands
 printf "LOUDSTOP\n"
 detach
 quit 1
end
# Keep the prototype's initial state bracket; stops before profiling are not
# part of any measured window. All measured windows use only event markers.
break AitdScreen::queueFrame if g_ingameStage==5 && g_macSceneFramesCompleted>=200
continue
delete $bpnum
break aitdMonsterCheckpoint
continue
printf "INITIAL phase=%u count=%u song=%u carnby=%d monster=%d\n",g_monsterPhase,g_monsterCount,g_monsterFrames[0].song,g_monsterFrames[0].carnby,g_monsterFrames[0].monster
if g_monsterPhase!=1 || g_monsterFrames[0].song!=137 || g_monsterFrames[0].carnby!=4 || g_monsterFrames[0].monster!=-1
 echo FAIL monster start\n
 quit 1
end
# Optional A/B control: intentionally stop inside windows to price observer bias.
set $frameStops=0
if @FRAME_STOPS@
 break aitdMonsterFrame
 commands
  silent
  set $frameStops=$frameStops+1
  continue
 end
end
printf "PHASE_START attic row=%u\n",g_monsterCount-1
aprof_segments "SEG"
printf "A5 %x\n",s_currentA5
maint info sections
dump binary memory @OUT@-attic.jt.bin s_currentA5+32 s_currentA5+32+3744
monitor aprof start
continue
monitor aprof stop @OUT@-attic.prof
if g_monsterPhase!=2
 echo FAIL monster phase\n
 quit 1
end
printf "PHASE_END attic row=%u\n",g_monsterCount-1
aprof_segments "SEGSTOP"
printf "PHASE_START entry row=%u\n",g_monsterCount-1
aprof_segments "SEG"
printf "A5 %x\n",s_currentA5
maint info sections
dump binary memory @OUT@-entry.jt.bin s_currentA5+32 s_currentA5+32+3744
monitor aprof start
continue
monitor aprof stop @OUT@-entry.prof
if g_monsterPhase!=3
 echo FAIL monster phase\n
 quit 1
end
printf "PHASE_END entry row=%u\n",g_monsterCount-1
aprof_segments "SEGSTOP"
printf "PHASE_START approach row=%u\n",g_monsterCount-1
aprof_segments "SEG"
printf "A5 %x\n",s_currentA5
maint info sections
dump binary memory @OUT@-approach.jt.bin s_currentA5+32 s_currentA5+32+3744
monitor aprof start
continue
monitor aprof stop @OUT@-approach.prof
if g_monsterPhase!=4
 echo FAIL monster phase\n
 quit 1
end
printf "PHASE_END approach row=%u\n",g_monsterCount-1
aprof_segments "SEGSTOP"
printf "PHASE_START fight row=%u\n",g_monsterCount-1
aprof_segments "SEG"
printf "A5 %x\n",s_currentA5
maint info sections
dump binary memory @OUT@-fight.jt.bin s_currentA5+32 s_currentA5+32+3744
monitor aprof start
continue
monitor aprof stop @OUT@-fight.prof
if g_monsterPhase!=5
 echo FAIL monster phase\n
 quit 1
end
printf "PHASE_END fight row=%u\n",g_monsterCount-1
aprof_segments "SEGSTOP"
dump binary memory @OUT@.frames.bin &g_monsterFrames[0] &g_monsterFrames[g_monsterCount]
printf "WINDOW_FRAME_STOPS %u\n",$frameStops
if @RGB_VERIFY@
 printf "RGB_CACHE_VERIFY checks=%u failures=%u quick_hits=%u\n",g_rgbCacheChecks,g_rgbCacheFailures,g_rgbQuickHits
 if g_rgbCacheChecks<1000 || g_rgbQuickHits<1000 || g_rgbCacheFailures
  echo FAIL RGB cache verification\n
  quit 1
 end
end
echo COMPLETE\n
detach
quit 0
