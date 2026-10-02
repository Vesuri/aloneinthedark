# AGAPROBE=1 CURSORPROBE=1 C2PVERIFY=1; GDB_ENTRY=aitdRunAgaProbe.
set pagination off
set confirm off
set width 0
source video_mode.gdb
echo CURSOR_INVERSION fixture=1\n
break aitdAgaProbeCheckpoint
set $cursor_n=1
continue
while $cursor_n<=5
 if g_agaProbeStage!=$cursor_n || g_agaProbeError!=0 || g_macFramesQueued!=$cursor_n || g_macFramesPresented!=$cursor_n
  echo FAIL cursor fixture publication\n
  detach
  quit 1
 end
 set $screen=g_agaProbeScreen
 set $cursor_control=$cursor_n==5 ? 0x0011 : 0x010f
 if *(unsigned short*)0xdff10c!=$cursor_control || $screen->m_framePending
  echo FAIL cursor palette publication mode\n
  detach
  quit 1
 end
 printf "CURSOR_FIX stage=%u front=%X copper=%X sprite=%X empty=%X crop=%u/%u allowed=%u visible=%u x=%d y=%d hot=%d/%d pal=%u control=%04X\n",g_agaProbeStage,$screen->m_chip,$screen->m_copper,$screen->m_mouseSprite,$screen->m_emptySprite,$screen->m_cropLeft,$screen->m_cropTop,$screen->m_mouseAllowed,$screen->m_cursorVisible,$screen->m_cursorX,$screen->m_cursorY,$screen->m_cursorHotX,$screen->m_cursorHotY,g_videoPAL,*(unsigned short*)0xdff10c
 eval "dump binary memory ../tmp/cursor-fixture-%u-planes.bin (char*)$screen->m_chip (char*)$screen->m_chip+64000",$cursor_n
 eval "dump binary memory ../tmp/cursor-fixture-%u-copper.bin (char*)$screen->m_copper (char*)$screen->m_copper+2248",$cursor_n
 eval "dump binary memory ../tmp/cursor-fixture-%u-source.bin (char*)g_agaProbeSource (char*)g_agaProbeSource+307200",$cursor_n
 eval "dump binary memory ../tmp/cursor-fixture-%u-clut.bin (char*)g_agaProbeColors (char*)g_agaProbeColors+2056",$cursor_n
 eval "dump binary memory ../tmp/cursor-fixture-%u-sprites.bin (char*)$screen->m_mouseSprite (char*)$screen->m_mouseSprite+144",$cursor_n
 eval "dump binary memory ../tmp/cursor-fixture-%u-empty.bin (char*)$screen->m_emptySprite (char*)$screen->m_emptySprite+8",$cursor_n
 if $cursor_n==5
  check_video_mode
  printf "CURSOR_TIMING verified=%u failures=%u late=%u presentMax=%u endLine=%u\n",g_c2pVerifiedFrames,g_c2pVerifyFailures,g_beamPresentsLate,g_beamPresentMax,$screen->m_cursorProbeEndLine
  if g_c2pVerifyFailures!=0 || g_c2pVerifiedFrames!=5 || g_beamPresentsLate!=0 || $screen->m_cursorProbeEndLine>=(g_videoPAL ? 72 : 44)
   echo FAIL cursor clean conversion or blanking deadline\n
   detach
   quit 1
  end
  printf "CURSOR_C2P verified=%u failures=%u endLine=%u\n",g_c2pVerifiedFrames,g_c2pVerifyFailures,$screen->m_cursorProbeEndLine
 end
 set $cursor_n=$cursor_n+1
 continue
end
if g_agaProbeStage!=99 || g_agaProbeDone!=1 || g_agaProbeError!=0 || g_agaProbeScreen->m_chip!=0 || g_agaProbeScreen->m_back!=0 || g_agaProbeScreen->m_copper!=0 || g_agaProbeScreen->m_mouseSprite!=0 || g_agaProbeScreen->m_emptySprite!=0
 echo FAIL cursor fixture cleanup\n
 detach
 quit 1
end
echo PASS native cursor fixture frames=5 restored=1\n
detach
quit 0
