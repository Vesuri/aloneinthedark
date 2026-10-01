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
set $portraits=(unsigned long)s_segments[13].begin+0x1eb6
if *(unsigned short*)$portraits!=0x4eb9
 echo FAIL portraits wait bytes\n
 detach
 quit 1
end
tbreak *$portraits
continue
printf "PORTRAITS pc=%X expected=%X ticks=%u choice=%u queued=%u presented=%u dirty=%u stage=%u trap=%X segment=%u offset=%X routine=%s\n",$pc,$portraits,g_macTicks,$d7,g_macFramesQueued,g_macFramesPresented,s_pixelsDirty,g_stageBState,g_trapWord,g_trapSegment,g_trapOffset,g_trapRoutine
if $pc!=$portraits || g_stageBState==3
 echo FAIL portraits wait not reached\n
 detach
 quit 1
end
set $screen=s_loudStopScreen
if $screen->m_framePending
 tbreak *$portraits if g_macFramesQueued==g_macFramesPresented
 continue
 if $pc!=$portraits || $screen->m_framePending || s_pixelsDirty
  echo FAIL portraits publication not reached\n
  detach
  quit 1
 end
end
printf "PORTRAITS_STABLE ticks=%u choice=%u queued=%u presented=%u\n",g_macTicks,$d7,g_macFramesQueued,g_macFramesPresented
printf "PORTRAITS_STORAGE front=%X left=%u top=%u pending=%u\n",$screen->m_chip,$screen->m_cropLeft,$screen->m_cropTop,$screen->m_framePending
dump binary memory ../tmp/portraits-native-screen.bin (char*)s_colorScreen (char*)s_colorScreen+307200
dump binary memory ../tmp/portraits-native-clut.bin (char*)s_windowManagerColors (char*)s_windowManagerColors+2056
dump binary memory ../tmp/portraits-native-planes.bin (char*)$screen->m_chip (char*)$screen->m_chip+64000
dump binary memory ../tmp/portraits-native-copper.bin (char*)$screen->m_copper (char*)$screen->m_copper+2248
dump binary memory ../tmp/portraits-native-a5.bin s_a5WorldStorage s_a5WorldStorage+75616+3776
echo PASS native portraits wait capture\n
detach
quit 0
