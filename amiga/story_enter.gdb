# STORYENTER=1: normal Enter at the menu and portrait input waits.
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
set $engine=(unsigned long)s_segments[7].begin
set $dan1=(unsigned long)s_segments[12].begin
set $dan2=(unsigned long)s_segments[13].begin
set $world=(unsigned long)s_a5WorldStorage+75616
if *(unsigned short*)($engine+0x1f84)!=0xa974 || *(unsigned long*)($engine+0x1f6a)!=0x4e56ffe2 || *(unsigned long*)($dan1+0x620e)!=0x4e560000 || *(unsigned short*)($dan1+0x622a)!=0x4eb9 || *(unsigned long*)($dan1+0x622c)!=$world+0xaa2 || *(unsigned long*)($dan2+0x1eb8)!=$world+0x572
 echo FAIL original portrait polling chain bytes\n
 detach
 quit 1
end
set $story=$dan1+0x4870
if *(unsigned long*)$story!=0x4eba199c
 echo FAIL story wait original bytes\n
 detach
 quit 1
end
tbreak *$story
continue
printf "STORY pc=%X expected=%X page=%u ticks=%u request=%u stage=%u trap=%X segment=%u offset=%X routine=%s\n",$pc,$story,$d3,g_macTicks,g_storyEnterState,g_stageBState,g_trapWord,g_trapSegment,g_trapOffset,g_trapRoutine
if $pc!=$story || g_stageBState==3
 echo FAIL story wait not reached\n
 detach
 quit 1
end
if $screen->m_framePending
 tbreak *$story if g_macFramesQueued==g_macFramesPresented
 continue
end
if $pc!=$story || $d3!=0 || g_stageBState==3 || g_storyEnterState!=3 || s_keyDown[0x44] || g_storyEnterReleased-g_storyEnterTick<2 || g_macFramesQueued!=g_macFramesPresented || $screen->m_framePending || s_pixelsDirty
 echo FAIL story input release or publication\n
 detach
 quit 1
end
printf "STORY_STABLE page=%u ticks=%u queued=%u presented=%u request=%u pressed=%u released=%u held=%u\n",$d3,g_macTicks,g_macFramesQueued,g_macFramesPresented,g_storyEnterState,g_storyEnterTick,g_storyEnterReleased,s_keyDown[0x44]
printf "STORY_STORAGE front=%X left=%u top=%u pending=%u\n",$screen->m_chip,$screen->m_cropLeft,$screen->m_cropTop,$screen->m_framePending
dump binary memory ../tmp/story-native-screen.bin (char*)s_colorScreen (char*)s_colorScreen+307200
dump binary memory ../tmp/story-native-clut.bin (char*)s_windowManagerColors (char*)s_windowManagerColors+2056
dump binary memory ../tmp/story-native-planes.bin (char*)$screen->m_chip (char*)$screen->m_chip+64000
dump binary memory ../tmp/story-native-copper.bin (char*)$screen->m_copper (char*)$screen->m_copper+2248
dump binary memory ../tmp/story-native-a5.bin s_a5WorldStorage s_a5WorldStorage+75616+3776
echo PASS original story page reached by normal Enter with released key and published frame\n
detach
quit 0
