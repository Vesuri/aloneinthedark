set pagination off
set confirm off
set width 0
break AitdScreen::showLoudStop
break aitdBookProfileCheckpoint
continue
if g_bookProfileStage!=1 || g_profileState!=0
 echo FAIL book profile start boundary\n
 detach
 quit 1
end
set $book_begun=g_macBookFramesBegun
set $book_completed=g_macBookFramesCompleted
printf "BOOK_BEGIN column=160 frames=%u ticks=%u dan1=%X dan2=%X pending=%u dirty=%u\n",g_macFramesPresented,g_macTicks,s_segments[12].begin,s_segments[13].begin,s_loudStopScreen->m_framePending,s_dirtyRectCount
dump binary memory ../tmp/book-profile-begin-screen.bin s_colorScreen s_colorScreen+307200
dump binary memory ../tmp/book-profile-begin-clut.bin s_windowManagerColors s_windowManagerColors+2056
continue
if g_bookProfileStage!=2 || g_profileState!=2 || g_profileStopEpoch<=g_profileStartEpoch || g_pageProfile[3]==0
 echo FAIL book profile end boundary\n
 detach
 quit 1
end
printf "BOOK_END column=150 fields=%u frames=%u epoch=%u paints=%u copies=%u seeds=%X/%X seedChanges=%u pending=%u dirty=%u\n",g_profileStopField-g_profileStartField,g_profileStopFrames-g_profileStartFrames,g_profileStopEpoch-g_profileStartEpoch,g_pageProfile[1],g_pageProfile[3],g_pageProfile[6],g_pageProfile[7],g_pageProfile[9],s_loudStopScreen->m_framePending,s_dirtyRectCount
printf "BOOK_BATCH active=%u begun=%u completed=%u suppressed=%u\n",g_macBookFrameActive,g_macBookFramesBegun-$book_begun,g_macBookFramesCompleted-$book_completed,g_pageProfile[8]
if g_macBookFrameActive!=0 || g_macBookFramesBegun-$book_begun!=1 || g_macBookFramesCompleted-$book_completed!=1
 echo FAIL book batch lifecycle\n
 detach
 quit 1
end
set $p=0
while $p<15
 printf "BOOK_PHASE id=%u ticks=%u calls=%u\n",$p,g_profileTicks[$p],g_profileCalls[$p]
 set $p=$p+1
end
dump binary memory ../tmp/book-profile-end-screen.bin s_colorScreen s_colorScreen+307200
dump binary memory ../tmp/book-profile-end-clut.bin s_windowManagerColors s_windowManagerColors+2056
dump binary memory ../tmp/book-profile-source-clut.bin (char*)g_pageProfile[4] (char*)g_pageProfile[4]+2056
dump binary memory ../tmp/book-profile-destination-clut.bin (char*)g_pageProfile[5] (char*)g_pageProfile[5]+2056
set $screen=s_loudStopScreen
set $book_queued=g_macFramesQueued
if $screen->m_framePending
 tbreak aitdMacMouseVBI if g_macFramesPresented==$book_queued
 continue
end
printf "BOOK_ACTIVE front=%X crop=%u/%u queued=%u presented=%u pending=%u line=%u late=%u\n",$screen->m_chip,$screen->m_cropLeft,$screen->m_cropTop,g_macFramesQueued,g_macFramesPresented,$screen->m_framePending,g_beamPresentLine,g_beamPresentsLate
if $screen->m_framePending || g_macFramesQueued!=$book_queued || g_macFramesPresented!=$book_queued || $screen->m_cropLeft!=160 || $screen->m_cropTop!=150 || g_beamPresentLine>=72 || g_beamPresentsLate
 echo FAIL book VBI publication\n
 detach
 quit 1
end
dump binary memory ../tmp/book-profile-active-planes.bin (char*)$screen->m_chip (char*)$screen->m_chip+64000
dump binary memory ../tmp/book-profile-active-copper.bin (char*)$screen->m_copper (char*)$screen->m_copper+2248
echo PASS original book-fold interval column=160..150 complete\n
detach
quit 0
