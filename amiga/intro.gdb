# C2PVERIFY=1 FIXEDRNG=1; no input injection or INTROSKIP.
set pagination off
set confirm off
set width 0
break AitdScreen::showLoudStop
commands
 silent
 printf "FAIL intro loud stop: %s / %s selector=%u\n",manager,routine,selector
 detach
 quit 1
end
break aitdC2PVerifyFailed
commands
 silent
 printf "FAIL intro C2P frame=%u x=%u y=%u expected=%u actual=%u\n",g_c2pVerifiedFrames,g_c2pMismatch.x,g_c2pMismatch.y,g_c2pMismatch.expected,g_c2pMismatch.actual
 detach
 quit 1
end
# The original CODE segments have been loaded by the first CopyBits.
tbreak copyPortBits8
continue
define intro_frame
 if $pc!=$intro_target || g_stageBState==3 || s_pixelsDirty || s_dirtyRectCount
  echo FAIL intro frame state/publication\n
  detach
  quit 1
 end
 set $intro_screen=s_loudStopScreen
 set $intro_checkpoint_d0=$d0
 set $intro_queued=g_macFramesQueued
 printf "INTRO_FRAME n=%u segment=%u offset=%X d0=%X\n",$intro_n,$intro_segment,$intro_offset,$intro_checkpoint_d0
 # Freeze instruction-matched logical pixels before resuming for the queued VBI.
 eval "dump binary memory ../tmp/intro-native-%u-screen.bin %u %u",$intro_n,s_colorScreen,s_colorScreen+307200
 eval "dump binary memory ../tmp/intro-native-%u-clut.bin %u %u",$intro_n,s_windowManagerColors,s_windowManagerColors+2056
 if $intro_screen->m_framePending
  if g_macFramesQueued!=g_macFramesPresented+1
   echo FAIL intro pending queue generation\n
   detach
   quit 1
  end
  set $intro_expected_front=$intro_screen->m_back
  set $intro_expected_copper=$intro_screen->m_nextCopper
  printf "INTRO_WAIT n=%u queued=%u presented=%u expectedFront=%X\n",$intro_n,$intro_queued,g_macFramesPresented,$intro_expected_front
  tbreak AitdScreen::vbiUpdate if this==$intro_screen && m_framePending
  continue
  finish
  if g_macFramesQueued!=$intro_queued || g_macFramesPresented!=$intro_queued || $intro_screen->m_framePending || $intro_screen->m_chip!=$intro_expected_front || $intro_screen->m_copper!=$intro_expected_copper
   echo FAIL intro expected queued frame publication\n
   detach
   quit 1
  end
 end
 if g_macFramesQueued!=g_macFramesPresented
  echo FAIL intro queue without pending publication\n
  detach
  quit 1
 end
 if $intro_screen->m_mouseAllowed || $intro_screen->m_invertActive || *(unsigned short*)0xdff10c!=0x0011
  echo FAIL intro pointer-free palette publication\n
  detach
  quit 1
 end
 printf "INTRO_CURSOR n=%u enabled=%u control=%04X\n",$intro_n,$intro_screen->m_mouseAllowed,*(unsigned short*)0xdff10c
 printf "INTRO_INVERSION n=%u active=%u left=%d top=%d\n",$intro_n,$intro_screen->m_invertActive,$intro_screen->m_invertLeft,$intro_screen->m_invertTop
 eval "dump binary memory ../tmp/intro-native-%u-inversion.bin %u %u",$intro_n,$intro_screen->m_invertRows,(char*)$intro_screen->m_invertRows+32
 printf "INTRO_PUBLICATION n=%u front=%X queued=%u presented=%u randomCalls=%u\n",$intro_n,$intro_screen->m_chip,g_macFramesQueued,g_macFramesPresented,g_fixedRandomCalls
 eval "dump binary memory ../tmp/intro-native-%u-planes.bin %u %u",$intro_n,$intro_screen->m_chip,$intro_screen->m_chip+64000
 eval "dump binary memory ../tmp/intro-native-%u-copper.bin %u %u",$intro_n,$intro_screen->m_copper,(char*)$intro_screen->m_copper+2248
end
set $intro_n=1
set $intro_segment=5
set $intro_offset=0x1c94
set $intro_target=(unsigned long)s_segments[5].begin+$intro_offset
if *(unsigned short*)$intro_target!=0x2d5f
 echo FAIL original logo checkpoint bytes\n
 detach
 quit 1
end
if g_macFramesQueued!=0 || *(unsigned long*)(s_segments[5].begin+0x1bda)!=0x4eba03c0 || *(unsigned long*)(s_segments[5].begin+0x202e)!=0x6000008a || *(unsigned long*)(s_segments[5].begin+0x20ce)!=0x6000005e
 echo FAIL startup publication or MACPLAY bypass\n
 detach
 quit 1
end
break *(s_segments[5].begin+0x2048)
break *(s_segments[5].begin+0x20d2)
commands
 silent
 echo FAIL MACPLAY picture or wait entered\n
 detach
 quit 1
end
tbreak *$intro_target
continue
if g_macFramesQueued!=1
 echo FAIL first publication is not complete Infogrames\n
 detach
 quit 1
end
intro_frame
set $intro_n=2
set $intro_offset=0x1f46
set $intro_target=(unsigned long)s_segments[5].begin+$intro_offset
if *(unsigned short*)$intro_target!=0x2f0b
 echo FAIL original logo animation checkpoint bytes\n
 detach
 quit 1
end
tbreak *$intro_target
continue
intro_frame
set $intro_n=3
set $intro_segment=13
set $intro_offset=0x2ed4
set $intro_target=(unsigned long)s_segments[13].begin+$intro_offset
if *(unsigned short*)$intro_target!=0x42a7
 echo FAIL original title checkpoint bytes\n
 detach
 quit 1
end
tbreak *$intro_target
continue
intro_frame
set $intro_return=(unsigned long)s_segments[4].begin+0x5220
if *(unsigned long*)$intro_return!=0x600001b8
 echo FAIL original intro completion bytes\n
 detach
 quit 1
end
# Duplicate endpoint slots inherit clut 129 even though its splash is omitted.
# Check the completed title before subsequent palette changes.
if *(unsigned long*)(s_windowManagerColors+18)!=0xf7f7f7f7 || *(unsigned short*)(s_windowManagerColors+22)!=0xf7f7 || *(unsigned long*)(s_windowManagerColors+130)!=0x63636363 || *(unsigned short*)(s_windowManagerColors+134)!=0x6363 || *(unsigned long*)(s_windowManagerColors+1538)!=0x08081818 || *(unsigned short*)(s_windowManagerColors+1542)!=0x2121
 echo FAIL inherited MACPLAY palette slots 1/15/191\n
 detach
 quit 1
end
echo PASS inherited MACPLAY palette slots 1/15/191 at book title\n
tbreak *$intro_return
continue
set $intro_n=4
set $intro_segment=4
set $intro_offset=0x5220
set $intro_target=$intro_return
intro_frame
if $intro_checkpoint_d0!=0 || g_stageBState==3
 echo FAIL uninterrupted original intro completion\n
 detach
 quit 1
end
if g_macBookFrameActive || g_macBookFramesBegun!=840 || g_macBookFramesCompleted!=840 || s_pixelsDirty || s_dirtyRectCount || s_loudStopScreen->m_framePending
 echo FAIL full intro publication coverage\n
 detach
 quit 1
end
if g_c2pVerifyFailures || g_c2pVerifiedFrames<840 || !g_c2pPartialFrames || g_c2pVerifiedFrames!=g_macFramesQueued || g_macFramesQueued!=g_macFramesPresented
 echo FAIL full intro C2P coverage\n
 detach
 quit 1
end
printf "PASS full intro C2P frames=%u partial=%u failures=%u queued=%u presented=%u book=%u/%u ticks=%u\n",g_c2pVerifiedFrames,g_c2pPartialFrames,g_c2pVerifyFailures,g_macFramesQueued,g_macFramesPresented,g_macBookFramesBegun,g_macBookFramesCompleted,g_macTicks
detach
quit 0
