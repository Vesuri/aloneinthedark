# Diagnostic normal Enter input; game instructions and timers are untouched.
set pagination off
set confirm off
break AitdScreen::showLoudStop
tbreak aitdInputInjectProbeKey
continue
if g_stageBState==3
 echo FAIL intro Enter injection not reached\n
 detach
 quit 1
end
set $return=(unsigned long)s_segments[4].begin+0x53da
if *(unsigned long*)$return!=0x4a076700
 echo FAIL original intro return bytes\n
 detach
 quit 1
end
tbreak *$return
continue
printf "INTRO_SKIP pc=%X expected=%X d0=%X state=%u pressed=%u now=%u held=%u book=%u/%u pending=%u\n",$pc,$return,$d0,g_introSkipState,g_introSkipTick,g_macTicks,s_keyDown[0x44],g_macBookFramesBegun,g_macBookFramesCompleted,g_macBookFrameActive
if $pc!=$return || $d0!=1 || g_macBookFrameActive || g_macBookFramesBegun!=g_macBookFramesCompleted || g_macBookFramesCompleted>=840
 echo FAIL original intro did not accept and release Enter\n
 detach
 quit 1
end
# Observe the queued key-up itself and its completed state separately: the
# original intro can return before the bounded hold has ended.
tbreak aitdInputInjectProbeKey
continue
printf "INTRO_KEYUP state=%u pressed=%u now=%u held=%u\n",g_introSkipState,g_introSkipTick,g_macTicks,s_keyDown[0x44]
if g_stageBState==3 || g_introSkipState!=1 || rawKey!=0x44 || down
 echo FAIL Enter release not reached\n
 detach
 quit 1
end
tbreak dispatchMacTrap if g_introSkipState==2
continue
printf "INTRO_RELEASE state=%u now=%u held=%u book=%u/%u\n",g_introSkipState,g_macTicks,s_keyDown[0x44],g_macBookFramesBegun,g_macBookFramesCompleted
if g_stageBState==3 || g_introSkipState!=2 || s_keyDown[0x44]!=0 || g_macBookFrameActive
 echo FAIL Enter not released\n
 detach
 quit 1
end
echo PASS original intro skipped with normal Enter input\n
detach
quit 0
