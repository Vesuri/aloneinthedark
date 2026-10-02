# INTROSKIP=1 FIXEDRNG=1. Capture original state keys, not elapsed-time samples.
set pagination off
set confirm off
set width 0
break AitdScreen::showLoudStop
commands
 silent
 printf "FAIL demo frame loud stop: %s / %s\n",manager,routine
 detach
 quit 1
end
tbreak aitdInputInjectProbeKey
continue
set $demo_dark=(unsigned long)s_segments[4].begin
if *(unsigned long*)($demo_dark+0x5658)!=0x4e56fff8 || *(unsigned short*)($demo_dark+0x5be8)!=0x4eb9
 echo FAIL original demo checkpoint bytes\n
 detach
 quit 1
end
set $demo_frame=0
set $demo_car=0
set $demo_pond=0
break *($demo_dark+0x5be8)
break *($demo_dark+0x5658)
define demo_capture
 set $screen=s_loudStopScreen
 printf "DEMO_CAPTURE kind=%u queued=%u presented=%u pending=%u pixelsDirty=%u rects=%u crop=%u/%u\n",$demo_n,g_macFramesQueued,g_macFramesPresented,$screen->m_framePending,s_pixelsDirty,s_dirtyRectCount,$screen->m_cropLeft,$screen->m_cropTop
 if s_pixelsDirty || s_dirtyRectCount || g_macFramesQueued!=g_macFramesPresented+$screen->m_framePending
  echo FAIL demo logical frame completeness\n
  detach
  quit 1
 end
 printf "DEMO_STATE kind=%u segment=4 offset=5658 frame=%u ticks=%u random=%u room=%u camera=%u actor0=",$demo_n,$demo_frame,g_macTicks,g_fixedRandomCalls,*(unsigned short*)($a5-0xcd68),*(unsigned short*)($a5-0xcd70)
 set $demo_word=0
 while $demo_word<80
  printf "%04X",*(unsigned short*)($a5-0xb292+$demo_word*2)
  set $demo_word=$demo_word+1
 end
 echo \n
 set $demo_queue=g_macFramesQueued
 eval "dump binary memory ../tmp/demo-native-%u-a5.bin 0x%x 0x%x",$demo_n,$a5-75616,$a5+3776
 eval "dump binary memory ../tmp/demo-native-%u-screen.bin (char*)s_colorScreen (char*)s_colorScreen+307200",$demo_n
 eval "dump binary memory ../tmp/demo-native-%u-clut.bin (char*)s_windowManagerColors (char*)s_windowManagerColors+2056",$demo_n
 if $screen->m_framePending
  # Save the original state above, then observe this queued frame's real VBI.
  # These are debugger waits, not guest calls or writes.
  tbreak *aitdMacMouseVBI if g_macFramesPresented==$demo_queue
  continue
  if $pc!=aitdMacMouseVBI
   echo FAIL demo publication wait checkpoint\n
   detach
   quit 1
  end
  finish
  finish
 end
 if $screen->m_framePending || s_pixelsDirty || s_dirtyRectCount || g_macFramesQueued!=$demo_queue || g_macFramesPresented!=$demo_queue || $screen->m_cropLeft!=160 || $screen->m_cropTop!=150
  echo FAIL demo queued frame publication/crop\n
  detach
  quit 1
 end
 printf "DEMO_PUBLICATION kind=%u front=%X queued=%u presented=%u pending=%u pixelsDirty=%u rects=%u control=%04X inverse=%u left=%d top=%d\n",$demo_n,$screen->m_chip,g_macFramesQueued,g_macFramesPresented,$screen->m_framePending,s_pixelsDirty,s_dirtyRectCount,*(unsigned short*)0xdff10c,$screen->m_invertActive,$screen->m_invertLeft,$screen->m_invertTop
 eval "dump binary memory ../tmp/demo-native-%u-published-screen.bin (char*)s_colorScreen (char*)s_colorScreen+307200",$demo_n
 eval "dump binary memory ../tmp/demo-native-%u-published-clut.bin (char*)s_windowManagerColors (char*)s_windowManagerColors+2056",$demo_n
 eval "dump binary memory ../tmp/demo-native-%u-planes.bin (char*)$screen->m_chip (char*)$screen->m_chip+64000",$demo_n
 eval "dump binary memory ../tmp/demo-native-%u-copper.bin (char*)$screen->m_copper (char*)$screen->m_copper+2248",$demo_n
 eval "dump binary memory ../tmp/demo-native-%u-inversion.bin (char*)$screen->m_invertRows (char*)$screen->m_invertRows+32",$demo_n
end
while 1
 continue
 if $pc==$demo_dark+0x5be8
  printf "DEMO_TRANSITION room=%u camera=%u frame=%u\n",*(unsigned short*)($a5-0xcd68),*(unsigned short*)($a5-0xcd70),$demo_frame
  if *(unsigned short*)($a5-0xcd68)==0 && *(unsigned short*)($a5-0xcd70)==1
   set $demo_pond=1
  end
 else
 if $pc!=$demo_dark+0x5658 || g_stageBState==3
  printf "FAIL original demo frame checkpoint pc=%X expected=%X state=%u\n",$pc,$demo_dark+0x5658,g_stageBState
  detach
  quit 1
 end
 set $demo_frame=$demo_frame+1
 if $demo_frame>2000 || *(unsigned short*)($a5-0xd8f2)!=0
  echo FAIL demo frame/choice bound\n
  detach
  quit 1
 end
 if $demo_pond
  if *(unsigned short*)($a5-0xcd68)!=0 || *(unsigned short*)($a5-0xcd70)!=3
   echo FAIL first pond camera state\n
   detach
   quit 1
  end
  if !$demo_car
   echo FAIL no visible near car before pond\n
   detach
   quit 1
  end
  set $demo_n=2
  demo_capture
  echo PASS native near car and first completed pond camera frame\n
  detach
  quit 0
 end
 set $demo_l=*(short*)($a5-0xb27e)
 set $demo_t=*(short*)($a5-0xb27c)
 set $demo_r=*(short*)($a5-0xb27a)
 set $demo_b=*(short*)($a5-0xb278)
 if *(unsigned short*)($a5-0xcd68)==0 && *(unsigned short*)($a5-0xcd70)==0 && $demo_r-$demo_l>=80 && $demo_l<320 && $demo_r>0 && $demo_t<200 && $demo_b>0
  if *(unsigned short*)($a5-0xb292)!=286
   echo FAIL car identity\n
   detach
   quit 1
  end
  set $demo_n=1
  demo_capture
  set $demo_car=1
 end
end
end
