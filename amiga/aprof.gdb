# Template expanded by aprof.sh; see docs/performance.md. Needs the FS-UAE
# built by tools/build_fsuae_aprof.sh (monitor aprof start/stop).
# @START@ is the scene start condition, @COUNTER@ the completed-step counter,
# @COUNT@ the interval length in steps and @OUT@ the output path prefix.
set pagination off
set confirm off
set width 0
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
break AitdScreen::queueFrame if @START@
set $startbp=$bpnum
continue
set $base=@COUNTER@
set $v0=g_vbiCount
set $q0=g_macFramesQueued
set $room0=*(unsigned short*)(s_currentA5-0xcd68)
set $camera0=*(unsigned short*)(s_currentA5-0xcd70)
printf "START fields=%u frames=%u steps=%u ticks=%u\n",g_vbiCount,g_macFramesQueued,$base,g_macTicks
aprof_segments "SEG"
printf "A5 %x\n",s_currentA5
dump binary memory @OUT@.jt.bin s_currentA5+32 s_currentA5+32+3744
maint info sections
monitor aprof start
delete $startbp
break AitdScreen::queueFrame if @COUNTER@>=$base+@COUNT@
continue
monitor aprof stop @OUT@.prof
printf "DELTA fields=%u frames=%u steps=%u\n",(unsigned short)(g_vbiCount-$v0),(unsigned short)(g_macFramesQueued-$q0),@COUNTER@-$base
printf "ROOM start=%u/%u stop=%u/%u\n",$room0,$camera0,*(unsigned short*)(s_currentA5-0xcd68),*(unsigned short*)(s_currentA5-0xcd70)
aprof_segments "SEGSTOP"
echo COMPLETE\n
detach
quit 0
