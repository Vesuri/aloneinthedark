# MENUENTER=1: normal input, not a patched menu result.
set pagination off
set confirm off
set width 0
break AitdScreen::showLoudStop
tbreak dispatchMacTrap if trap==0xa8ec
continue
set $menu=(unsigned long)s_segments[12].begin
set $dark=(unsigned long)s_segments[4].begin
if *(unsigned long*)($menu+0x1374)!=0x42a7a975 || *(unsigned long*)($dark+0x522a)!=0x1c001006 || *(unsigned short*)($dark+0x52b6)!=0x4a79 || *(unsigned long*)($dark+0x52b8)!=(unsigned long)s_a5WorldStorage+75616-0xd84e
 echo FAIL menu input original bytes\n
 detach
 quit 1
end
tbreak *($menu+0x1374)
continue
if $pc!=$menu+0x1374 || g_menuEnterState!=0
 echo FAIL original menu wait not reached\n
 detach
 quit 1
end
set $start=g_macTicks
tbreak *($dark+0x522a)
continue
printf "MENU_ENTER result=%X ticks=%u start=%u pressed=%u state=%u book=%u\n",$d0,g_macTicks,$start,g_menuEnterTick,g_menuEnterState,g_macBookFramesCompleted
if $pc!=$dark+0x522a || ($d0&255)!=0 || g_macTicks-$start>=900 || g_menuEnterState<2 || g_macBookFramesCompleted
 echo FAIL original menu did not accept Enter\n
 detach
 quit 1
end
tbreak *($dark+0x52b6)
continue
if $pc!=$dark+0x52b6
 echo FAIL original new-game branch\n
 detach
 quit 1
end
if g_menuEnterState!=3
 tbreak dispatchMacTrap if g_menuEnterState==3
 continue
end
printf "MENU_RELEASE state=%u pressed=%u released=%u held=%u stage=%u\n",g_menuEnterState,g_menuEnterTick,g_menuEnterReleased,s_keyDown[0x44],g_stageBState
if g_menuEnterState!=3 || s_keyDown[0x44] || g_stageBState==3
 echo FAIL menu Enter release\n
 detach
 quit 1
end
echo PASS original menu selects new game with normal Enter and releases key\n
detach
quit 0
