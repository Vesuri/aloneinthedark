# INTROSKIP=1; no palette readback or scripted menu input.
set pagination off
set confirm off
set width 0
# FS-UAE debugger values, not Amiga reads of write-only registers.
# DIWHIGH's serialized state includes flags at C080; BPLCON3 bank/LOCT vary.
define check_mode
 if *(unsigned short*)0xdff100!=0x0211 || *(unsigned short*)0xdff102!=0 || *(unsigned short*)0xdff104!=0x0024 || (*(unsigned short*)0xdff106&0x1dff)!=0x0c60 || *(unsigned short*)0xdff10c!=0x0011 || (*(unsigned short*)0xdff002&0x380)!=0x380
  echo FAIL owned display mode or DMA\n
  detach
  quit 1
 end
 if *(unsigned short*)0xdff08e!=0x4881 || *(unsigned short*)0xdff090!=0x10c1 || (*(unsigned short*)0xdff1e4&0x3f7f)!=0x2100 || *(unsigned short*)0xdff092!=0x38 || *(unsigned short*)0xdff094!=0xd0 || *(unsigned short*)0xdff108!=0x118 || *(unsigned short*)0xdff10a!=0x118 || *(unsigned short*)0xdff1fc!=0
  echo FAIL owned display geometry\n
  detach
  quit 1
 end
end
check_mode
printf "MODE_START bplcon0=%04X bplcon1=%04X bplcon2=%04X bplcon3=%04X bplcon4=%04X dma=%04X windows=%u\n",*(unsigned short*)0xdff100,*(unsigned short*)0xdff102,*(unsigned short*)0xdff104,*(unsigned short*)0xdff106,*(unsigned short*)0xdff10c,*(unsigned short*)0xdff002,g_systemWindows
printf "MODE_GEOMETRY_START diwstrt=%04X diwstop=%04X diwhigh=%04X ddfstrt=%04X ddfstop=%04X mod1=%04X mod2=%04X fmode=%04X cop1=%08X\n",*(unsigned short*)0xdff08e,*(unsigned short*)0xdff090,*(unsigned short*)0xdff1e4,*(unsigned short*)0xdff092,*(unsigned short*)0xdff094,*(unsigned short*)0xdff108,*(unsigned short*)0xdff10a,*(unsigned short*)0xdff1fc,*(unsigned long*)0xdff080
break AitdScreen::showLoudStop
tbreak dispatchMacTrap if trap==0xa8ec
continue
set $menu=(unsigned long)s_segments[12].begin
if *(unsigned long*)($menu+0x1374)!=0x42a7a975 || *(unsigned short*)($menu+0x13e6)!=0x4227
 echo FAIL menu original bytes\n
 detach
 quit 1
end
tbreak *($menu+0x1374)
continue
if $pc!=$menu+0x1374
 echo FAIL menu wait not reached\n
 detach
 quit 1
end
set $start=g_macTicks
if g_macFramesQueued!=g_macFramesPresented
 tbreak *($menu+0x1374) if g_macFramesQueued==g_macFramesPresented
 continue
end
set $screen=s_loudStopScreen
check_mode
if $pc!=$menu+0x1374 || $screen->m_framePending || g_systemWindows==0 || *(unsigned long*)0xdff080!=(unsigned long)$screen->m_copper
 echo FAIL stable menu copper publication\n
 detach
 quit 1
end
printf "MODE_FRAME front=%X left=%u top=%u queued=%u presented=%u pending=%u\n",$screen->m_chip,$screen->m_cropLeft,$screen->m_cropTop,g_macFramesQueued,g_macFramesPresented,$screen->m_framePending
dump binary memory ../tmp/menu-mode-screen.bin (char*)s_colorScreen (char*)s_colorScreen+307200
dump binary memory ../tmp/menu-mode-clut.bin (char*)s_windowManagerColors (char*)s_windowManagerColors+2056
dump binary memory ../tmp/menu-mode-planes.bin (char*)$screen->m_chip (char*)$screen->m_chip+64000
dump binary memory ../tmp/menu-mode-copper.bin (char*)$screen->m_copper (char*)$screen->m_copper+2248
printf "MODE_MENU bplcon0=%04X bplcon1=%04X bplcon2=%04X bplcon3=%04X bplcon4=%04X dma=%04X windows=%u ticks=%u\n",*(unsigned short*)0xdff100,*(unsigned short*)0xdff102,*(unsigned short*)0xdff104,*(unsigned short*)0xdff106,*(unsigned short*)0xdff10c,*(unsigned short*)0xdff002,g_systemWindows,g_macTicks
printf "MODE_GEOMETRY_MENU diwstrt=%04X diwstop=%04X diwhigh=%04X ddfstrt=%04X ddfstop=%04X mod1=%04X mod2=%04X fmode=%04X cop1=%08X owned=%08X\n",*(unsigned short*)0xdff08e,*(unsigned short*)0xdff090,*(unsigned short*)0xdff1e4,*(unsigned short*)0xdff092,*(unsigned short*)0xdff094,*(unsigned short*)0xdff108,*(unsigned short*)0xdff10a,*(unsigned short*)0xdff1fc,*(unsigned long*)0xdff080,s_loudStopScreen->m_copper
tbreak *($menu+0x13e6)
continue
if $pc!=$menu+0x13e6 || g_macTicks-$start!=900 || g_stageBState==3
 echo FAIL menu continuation\n
 detach
 quit 1
end
check_mode
if *(unsigned long*)0xdff080!=(unsigned long)$screen->m_copper
 echo FAIL menu exit copper pointer\n
 detach
 quit 1
end
printf "MODE_EXIT bplcon0=%04X bplcon1=%04X bplcon2=%04X bplcon3=%04X bplcon4=%04X dma=%04X windows=%u ticks=%u\n",*(unsigned short*)0xdff100,*(unsigned short*)0xdff102,*(unsigned short*)0xdff104,*(unsigned short*)0xdff106,*(unsigned short*)0xdff10c,*(unsigned short*)0xdff002,g_systemWindows,g_macTicks
printf "MODE_GEOMETRY_EXIT diwstrt=%04X diwstop=%04X diwhigh=%04X ddfstrt=%04X ddfstop=%04X mod1=%04X mod2=%04X fmode=%04X cop1=%08X owned=%08X\n",*(unsigned short*)0xdff08e,*(unsigned short*)0xdff090,*(unsigned short*)0xdff1e4,*(unsigned short*)0xdff092,*(unsigned short*)0xdff094,*(unsigned short*)0xdff108,*(unsigned short*)0xdff10a,*(unsigned short*)0xdff1fc,*(unsigned long*)0xdff080,s_loudStopScreen->m_copper
echo PASS unchanged display mode across system handbacks and original idle menu wait\n
detach
quit 0
