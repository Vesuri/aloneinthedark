set $screen=s_loudStopScreen
printf "AGA_STOP state=%u trap=%X segment=%u offset=%X queued=%u presented=%u pending=%u\n",g_stageBState,g_trapWord,g_trapSegment,g_trapOffset,g_macFramesQueued,g_macFramesPresented,$screen->m_framePending
if g_macFramesQueued!=9 || g_macFramesPresented>9
 echo FAIL AGA startup boundary\n
 detach
 quit 1
end
printf "AGA_PENDING front=%X back=%X active=%X next=%X crop=%u/%u sync=%u\n",$screen->m_chip,$screen->m_back,$screen->m_copper,$screen->m_nextCopper,$screen->m_nextCropLeft,$screen->m_nextCropTop,$screen->m_syncRectCount
set $target=$screen->m_framePending ? $screen->m_back : $screen->m_chip
set $copper=$screen->m_framePending ? $screen->m_nextCopper : $screen->m_copper
dump binary memory ../tmp/aga-startup-queued-planes.bin (char*)$target (char*)$target+64000
dump binary memory ../tmp/aga-startup-queued-copper.bin (char*)$copper (char*)$copper+2248
dump binary memory ../tmp/aga-startup-logical.bin (char*)s_colorScreen (char*)s_colorScreen+307200
dump binary memory ../tmp/aga-startup-clut.bin (char*)s_windowManagerColors (char*)s_windowManagerColors+2056
if g_macFramesPresented<9
 tbreak aitdMacMouseVBI if g_macFramesPresented==9
 continue
end
printf "AGA_ACTIVE front=%X back=%X copper=%X crop=%u/%u queued=%u presented=%u pending=%u line=%u late=%u\n",$screen->m_chip,$screen->m_back,$screen->m_copper,$screen->m_cropLeft,$screen->m_cropTop,g_macFramesQueued,g_macFramesPresented,$screen->m_framePending,g_beamPresentLine,g_beamPresentsLate
if $screen->m_framePending || g_macFramesPresented!=9 || $screen->m_chip!=$target || $screen->m_copper!=$copper || $screen->m_cropLeft!=160 || $screen->m_cropTop!=150 || !$screen->m_mouseAllowed || *(unsigned short*)0xdff10c!=0x010f
 echo FAIL AGA VBI publication\n
 detach
 quit 1
end
printf "AGA_CURSOR enabled=%u control=%04X\n",$screen->m_mouseAllowed,*(unsigned short*)0xdff10c
dump binary memory ../tmp/aga-startup-active-planes.bin (char*)$screen->m_chip (char*)$screen->m_chip+64000
dump binary memory ../tmp/aga-startup-active-copper.bin (char*)$screen->m_copper (char*)$screen->m_copper+2248
echo PASS AGA startup queued and VBI-published frames=9\n
