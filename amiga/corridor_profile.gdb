# Build CORRIDORPROFILE=1 INTROSKIP=1 PROBEFIELDS=250 after make clean.
# Capture only after the upper landing; frame counts depend on the car route.
set pagination off
set confirm off
set width 0
break AitdScreen::showLoudStop
tbreak aitdProfileStart
continue
if g_profileState!=0 || *(unsigned short*)(s_currentA5-0xcd68)!=1 || *(unsigned short*)(s_currentA5-0xcd70)!=2
 echo FAIL corridor profile start state\n
 detach
 quit 1
end
printf "CORRIDOR_START ticks=%u frames=%u room=%u camera=%u choice=%u\n",g_macTicks,g_macFramesPresented,*(unsigned short*)(s_currentA5-0xcd68),*(unsigned short*)(s_currentA5-0xcd70),*(unsigned short*)(s_currentA5-0xd8f2)
dump binary memory ../tmp/corridor-start-screen.bin s_colorScreen s_colorScreen+sizeof(s_colorScreen)
dump binary memory ../tmp/corridor-start-clut.bin s_windowManagerColors s_windowManagerColors+sizeof(s_windowManagerColors)
tbreak aitdFrameProfileCheckpoint
continue
if g_stageBState==3 || g_profileState!=2 || *(unsigned short*)(s_currentA5-0xcd68)!=1 || *(unsigned short*)(s_currentA5-0xcd70)!=2 || g_profileStopFrames<=g_profileStartFrames
 echo FAIL corridor profile checkpoint\n
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
dump binary memory ../tmp/corridor-end-screen.bin s_colorScreen s_colorScreen+sizeof(s_colorScreen)
dump binary memory ../tmp/corridor-end-clut.bin s_windowManagerColors s_windowManagerColors+sizeof(s_windowManagerColors)
echo PASS late corridor profile\n
detach
quit 0
