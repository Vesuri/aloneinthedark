# PROFILEFRAME=<publication> PROBEFIELDS=<fields> (default 300).
# Or PROFILEROOM=<room> PROFILECAMERA=<camera> for a scene-triggered sample.
# Or MASKPROFILE=1 for the first complete room-0/camera-3 mask construction.
# Arrays are dumped in bulk to avoid thousands of remote-debugger round trips.
set pagination off
set confirm off
set width 0
break AitdScreen::showLoudStop
tbreak aitdFrameProfileCheckpoint
continue
if g_stageBState==3 || g_profileState!=2
 echo FAIL idle profile checkpoint\n
 detach
 quit 1
end
printf "IDLE_PROFILE fields=%u frames=%u epoch=%u start=%u ticks=%u\n",g_profileStopField-g_profileStartField,g_profileStopFrames-g_profileStartFrames,g_profileStopEpoch-g_profileStartEpoch,g_profileStartFrames,g_macTicks
printf "IDLE_LOCATION room=%u camera=%u\n",*(unsigned short*)(s_currentA5-0xcd68),*(unsigned short*)(s_currentA5-0xcd70)
set $i=0
while $i<sizeof(g_profileTicks)/sizeof(g_profileTicks[0])
 printf "IDLE_PHASE id=%u ticks=%u calls=%u\n",$i,g_profileTicks[$i],g_profileCalls[$i]
 set $i=$i+1
end
dump binary memory ../tmp/frame-profile-trap-ticks.bin g_profileTrapTicks g_profileTrapTicks+4096
dump binary memory ../tmp/frame-profile-trap-calls.bin g_profileTrapCalls g_profileTrapCalls+4096
echo COMPLETE native idle profile\n
detach
quit 0
