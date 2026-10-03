# Clean build: INTROSKIP=1 FIXEDRNG=1 (SCENEFRAMEBATCH defaults to 1).
# Create ../tmp/route-comparison/amiga-fixed-batch/ before running.
# Read-only captures; normal input fixture selects the unattended demo.
# Validate natural runner status and all captures with tools/check_scene_batches.py.
set pagination off
set confirm off
set width 0
set $seenlate=0
break AitdScreen::showLoudStop
commands
 silent
 printf "FAIL intro timing loud stop: %s / %s\n",manager,routine
 detach
 quit 1
end
set $image=0
set $loops=0
set $lastimage=0
set $lastroom=-1
set $lastcamera=-1
break AitdScreen::presentMacFrame
commands
 silent
 if !this->m_framePending && (g_macTicks-$lastimage>=30 || *(unsigned short*)(s_currentA5-0xcd68)!=$lastroom || *(unsigned short*)(s_currentA5-0xcd70)!=$lastcamera)
  set $lastimage=g_macTicks
  set $lastroom=*(unsigned short*)(s_currentA5-0xcd68)
  set $lastcamera=*(unsigned short*)(s_currentA5-0xcd70)
  set $image=$image+1
  printf "ROUTE_IMAGE n=%u ticks=%u room=%u camera=%u loop=%u cropLeft=%u cropTop=%u\n",$image,g_macTicks,*(unsigned short*)(s_currentA5-0xcd68),*(unsigned short*)(s_currentA5-0xcd70),$loops,cropLeft,cropTop
  eval "dump binary memory ../tmp/route-comparison/amiga-fixed-batch/%05u-screen.bin s_colorScreen s_colorScreen+sizeof(s_colorScreen)",$image
  eval "dump binary memory ../tmp/route-comparison/amiga-fixed-batch/%05u-clut.bin s_windowManagerColors s_windowManagerColors+sizeof(s_windowManagerColors)",$image
 end
 continue
end
set $planarchecks=0
break AitdScreen::queueFrame
commands
 silent
 if g_macSceneFramesBegun
  if g_macSceneFrameOwner
   echo FAIL intermediate scene publication\n
   detach
   quit 1
  end
  set $planarchecks=$planarchecks+1
  printf "SCENE_PLANAR n=%u frame=%u left=%u top=%u back=%X\n",$planarchecks,g_macFramesQueued+1,left,top,this->m_back
  eval "dump binary memory ../tmp/route-comparison/amiga-fixed-batch/queued-%05u-screen.bin s_colorScreen s_colorScreen+sizeof(s_colorScreen)",$planarchecks
  eval "dump binary memory ../tmp/route-comparison/amiga-fixed-batch/queued-%05u-planes.bin this->m_back this->m_back+64000",$planarchecks
  eval "dump binary memory ../tmp/route-comparison/amiga-fixed-batch/queued-%05u-clut.bin s_windowManagerColors s_windowManagerColors+sizeof(s_windowManagerColors)",$planarchecks
  eval "dump binary memory ../tmp/route-comparison/amiga-fixed-batch/queued-%05u-palette.bin this->m_nextPalette this->m_nextPalette+256",$planarchecks
 end
 continue
end
tbreak aitdInputInjectProbeKey
continue
set $stacklower=*(unsigned long*)(*(unsigned long*)4+58)
set $minmargin=6144
break aitdMacMouseVBI if $sp<$stacklower+$minmargin
commands
 silent
 set $minmargin=$sp-$stacklower
 printf "INTRO_STACK margin=%u\n",$minmargin
 continue
end
set $dark=(unsigned long)s_segments[4].begin
if *(unsigned short*)($dark+0x3fba)!=0x4eba || *(unsigned short*)($dark+0x3fc2)!=0x588f
 echo FAIL cold mask route bytes\n
 detach
 quit 1
end
tbreak *($dark+0x3fba) if *(unsigned short*)($a5-0xcd68)==0 && *(unsigned short*)($a5-0xcd70)==3
commands
 silent
 printf "INTRO_MASK phase=begin ticks=%u\n",g_macTicks
 continue
end
tbreak *($dark+0x3fc2) if *(unsigned short*)($a5-0xcd68)==0 && *(unsigned short*)($a5-0xcd70)==3
commands
 silent
 printf "INTRO_MASK phase=end ticks=%u\n",g_macTicks
 continue
end
if *(unsigned short*)($dark+0x522a)!=0x1c00
 echo FAIL intro timing original bytes\n
 detach
 quit 1
end
break *($dark+0x522a)
commands
 silent
 printf "INTRO_TIME stage=menu-return ticks=%u room=%u camera=%u frames=%u\n",g_macTicks,*(unsigned short*)($a5-0xcd68),*(unsigned short*)($a5-0xcd70),g_macFramesPresented
 continue
end
if *(unsigned short*)($dark+0x54e4)!=0x4eb9
 echo FAIL intro timing original bytes\n
 detach
 quit 1
end
break *($dark+0x54e4)
commands
 silent
 printf "INTRO_TIME stage=setup ticks=%u room=%u camera=%u frames=%u\n",g_macTicks,*(unsigned short*)($a5-0xcd68),*(unsigned short*)($a5-0xcd70),g_macFramesPresented
 continue
end
if *(unsigned short*)($dark+0x5504)!=0x3eae
 echo FAIL intro timing original bytes\n
 detach
 quit 1
end
break *($dark+0x5504)
commands
 silent
 printf "INTRO_TIME stage=room-loaded ticks=%u room=%u camera=%u frames=%u\n",g_macTicks,*(unsigned short*)($a5-0xcd68),*(unsigned short*)($a5-0xcd70),g_macFramesPresented
 continue
end
if *(unsigned short*)($dark+0x550e)!=0x4279
 echo FAIL intro timing original bytes\n
 detach
 quit 1
end
break *($dark+0x550e)
commands
 silent
 printf "INTRO_TIME stage=actor-loaded ticks=%u room=%u camera=%u frames=%u\n",g_macTicks,*(unsigned short*)($a5-0xcd68),*(unsigned short*)($a5-0xcd70),g_macFramesPresented
 continue
end
if *(unsigned short*)($dark+0x5522)!=0x3eae
 echo FAIL intro timing original bytes\n
 detach
 quit 1
end
break *($dark+0x5522)
commands
 silent
 printf "INTRO_TIME stage=scene-loaded ticks=%u room=%u camera=%u frames=%u\n",g_macTicks,*(unsigned short*)($a5-0xcd68),*(unsigned short*)($a5-0xcd70),g_macFramesPresented
 continue
end
if *(unsigned short*)($dark+0x5be8)!=0x4eb9
 echo FAIL intro timing original bytes\n
 detach
 quit 1
end
break *($dark+0x5be8)
commands
 silent
 printf "INTRO_TIME stage=transition ticks=%u room=%u camera=%u frames=%u\n",g_macTicks,*(unsigned short*)($a5-0xcd68),*(unsigned short*)($a5-0xcd70),g_macFramesPresented
 continue
end
if *(unsigned short*)($dark+0x5658)!=0x4e56
 echo FAIL intro timing original bytes\n
 detach
 quit 1
end
break *($dark+0x5658)
commands
 silent
 if g_song.maxDeliveryLateness>$seenlate
  set $seenlate=g_song.maxDeliveryLateness
  printf "MUSIC_LATE max=%u tick=%u busyTick=%u busyFields=%u effects=%u/%u\n",g_song.maxDeliveryLateness,g_song.lateTick,g_song.lateBusyTick,g_song.busyFields,g_effectStarts,g_effectStops
 end
 set $loops=$loops+1
 eval "dump binary memory ../tmp/route-comparison/amiga-fixed-batch/loop-%05u-screen.bin s_colorScreen s_colorScreen+sizeof(s_colorScreen)",$loops
 eval "dump binary memory ../tmp/route-comparison/amiga-fixed-batch/loop-%05u-clut.bin s_windowManagerColors s_windowManagerColors+sizeof(s_windowManagerColors)",$loops
 eval "dump binary memory ../tmp/route-comparison/amiga-fixed-batch/actor-%05u.bin ($a5-0xb292) ($a5-0xb292+16000)",$loops
 printf "INTRO_TIME stage=frame ticks=%u room=%u camera=%u frames=%u\n",g_macTicks,*(unsigned short*)($a5-0xcd68),*(unsigned short*)($a5-0xcd70),g_macFramesPresented
 continue
end
if *(unsigned short*)($dark+0x552c)!=0x4e71
 echo FAIL intro timing original bytes\n
 detach
 quit 1
end
break *($dark+0x552c)
commands
 silent
 printf "INTRO_TIME stage=complete ticks=%u room=%u camera=%u frames=%u\n",g_macTicks,*(unsigned short*)($a5-0xcd68),*(unsigned short*)($a5-0xcd70),g_macFramesPresented
 printf "MUSIC_IRQ_ROUTE notes=%u maxLate=%u prepared=%u latePresents=%u beamMax=%u\n",g_song.events,g_song.maxDeliveryLateness,g_song.preparedCount,g_beamPresentsLate,g_beamPresentMax
 printf "MUSIC_BUSY fields=%u last=%u lateTick=%u lateBusyTick=%u\n",g_song.busyFields,g_song.lastBusyTick,g_song.lateTick,g_song.lateBusyTick
 printf "FIXED_ROUTE choice=%u randomCalls=%u\n",*(unsigned short*)($a5-0xd8f2),g_fixedRandomCalls
 if *(unsigned short*)($a5-0xd8f2)!=0 || !g_fixedRandomCalls
  echo FAIL controlled character choice\n
  detach
  quit 1
 end
 printf "SCENE_BATCH begun=%u completed=%u active=%u\n",g_macSceneFramesBegun,g_macSceneFramesCompleted,g_macSceneFrameOwner
 printf "SCENE_DISPLAY queued=%u presented=%u checks=%u\n",g_macFramesQueued,g_macFramesPresented,$planarchecks
 if g_macSceneFrameOwner || g_macSceneFramesBegun!=g_macSceneFramesCompleted || !g_macSceneFramesBegun || g_macFramesQueued!=g_macFramesPresented
  echo FAIL scene batching completion\n
  detach
  quit 1
 end
 if g_song.events!=3736 || g_song.maxDeliveryLateness>1
  echo FAIL intro music delivery timing\n
  detach
  quit 1
 end
 echo PASS original demo timing complete\n
 detach
 quit 0
end
continue
echo FAIL intro timing unexpected stop\n
detach
quit 1
