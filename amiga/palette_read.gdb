# Requires INTROSKIP=1 PALREADFRAME=13. Hardware readback, not host-video proof.
set pagination off
set confirm off
set width 0
break AitdScreen::showLoudStop
tbreak dispatchMacTrap if trap==0xa8ec
continue
set $menu=(unsigned long)s_segments[12].begin
if *(unsigned short*)($menu+0x1374)!=0x42a7 || *(unsigned short*)($menu+0x13e6)!=0x4227
 echo FAIL palette menu bytes\n
 detach
 quit 1
end
tbreak *($menu+0x1374)
continue
if $pc!=$menu+0x1374 || g_paletteReadDone
 echo FAIL palette menu entry or early readback\n
 detach
 quit 1
end
set $start=g_macTicks
tbreak aitdPaletteReadComplete
continue
set $screen=s_loudStopScreen
printf "PALETTE_READ done=%u banks=%u frame=%u queued=%u presented=%u pending=%u beam=%u dmaBefore=%X dmaAfter=%X ticks=%u start=%u book=%u\n",g_paletteReadDone,g_paletteReadBanks,g_paletteReadFrame,g_macFramesQueued,g_macFramesPresented,$screen->m_framePending,g_paletteReadBeamMax,g_paletteReadDMABefore,g_paletteReadDMAAfter,g_macTicks,$start,g_macBookFramesCompleted
if g_stageBState==3 || g_paletteReadDone!=1 || g_paletteReadBanks!=8 || g_paletteReadFrame!=13 || g_macFramesQueued!=13 || g_macFramesPresented!=13 || $screen->m_framePending || g_paletteReadBeamMax>=72 || (g_paletteReadDMABefore&0x3ff)!=(g_paletteReadDMAAfter&0x3ff) || (g_paletteReadDMABefore&0x380)!=0x380 || g_macTicks>=$start+900 || g_macBookFramesCompleted
 echo FAIL palette readback boundary\n
 detach
 quit 1
end
dump binary memory ../tmp/palette-read-high.bin (char*)g_paletteReadHigh (char*)g_paletteReadHigh+512
dump binary memory ../tmp/palette-read-low.bin (char*)g_paletteReadLow (char*)g_paletteReadLow+512
dump binary memory ../tmp/palette-read-copper.bin (char*)$screen->m_copper (char*)$screen->m_copper+2248
dump binary memory ../tmp/palette-read-planes.bin (char*)$screen->m_chip (char*)$screen->m_chip+64000
dump binary memory ../tmp/palette-read-screen.bin (char*)s_colorScreen (char*)s_colorScreen+307200
dump binary memory ../tmp/palette-read-clut.bin (char*)s_windowManagerColors (char*)s_windowManagerColors+2056
printf "PALETTE_STORAGE front=%X left=%u top=%u\n",$screen->m_chip,$screen->m_cropLeft,$screen->m_cropTop
tbreak *($menu+0x13e6)
continue
if $pc!=$menu+0x13e6 || g_macTicks-$start!=900 || g_stageBState==3
 echo FAIL palette menu continuation\n
 detach
 quit 1
end
echo PASS native hardware palette capture and menu continuation\n
detach
quit 0
