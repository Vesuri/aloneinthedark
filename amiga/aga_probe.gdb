set pagination off
set confirm off
set width 0
break aitdAgaProbeCheckpoint
continue
if g_agaProbeStage!=1 || g_agaProbeError!=0 || g_macFramesQueued!=1 || g_macFramesPresented!=1
 echo FAIL AGA fixture stage\n
 detach
 quit 1
end
set $screen=g_agaProbeScreen
printf "AGA_FIX stage=%u front=%X copper=%X crop=%u/%u pending=%u line=%u late=%u\n",g_agaProbeStage,$screen->m_chip,$screen->m_copper,$screen->m_cropLeft,$screen->m_cropTop,$screen->m_framePending,g_beamPresentLine,g_beamPresentsLate
dump binary memory ../tmp/aga-fixture-1-planes.bin (char*)$screen->m_chip (char*)$screen->m_chip+64000
dump binary memory ../tmp/aga-fixture-1-copper.bin (char*)$screen->m_copper (char*)$screen->m_copper+2248
dump binary memory ../tmp/aga-fixture-1-source.bin (char*)g_agaProbeSource (char*)g_agaProbeSource+307200
dump binary memory ../tmp/aga-fixture-1-clut.bin (char*)g_agaProbeColors (char*)g_agaProbeColors+2056
continue
if g_agaProbeStage!=2 || g_agaProbeError!=0 || g_macFramesQueued!=2 || g_macFramesPresented!=2
 echo FAIL AGA fixture stage\n
 detach
 quit 1
end
set $screen=g_agaProbeScreen
printf "AGA_FIX stage=%u front=%X copper=%X crop=%u/%u pending=%u line=%u late=%u\n",g_agaProbeStage,$screen->m_chip,$screen->m_copper,$screen->m_cropLeft,$screen->m_cropTop,$screen->m_framePending,g_beamPresentLine,g_beamPresentsLate
dump binary memory ../tmp/aga-fixture-2-planes.bin (char*)$screen->m_chip (char*)$screen->m_chip+64000
dump binary memory ../tmp/aga-fixture-2-copper.bin (char*)$screen->m_copper (char*)$screen->m_copper+2248
dump binary memory ../tmp/aga-fixture-2-source.bin (char*)g_agaProbeSource (char*)g_agaProbeSource+307200
dump binary memory ../tmp/aga-fixture-2-clut.bin (char*)g_agaProbeColors (char*)g_agaProbeColors+2056
continue
if g_agaProbeStage!=3 || g_agaProbeError!=0 || g_macFramesQueued!=3 || g_macFramesPresented!=3
 echo FAIL AGA fixture stage\n
 detach
 quit 1
end
set $screen=g_agaProbeScreen
printf "AGA_FIX stage=%u front=%X copper=%X crop=%u/%u pending=%u line=%u late=%u\n",g_agaProbeStage,$screen->m_chip,$screen->m_copper,$screen->m_cropLeft,$screen->m_cropTop,$screen->m_framePending,g_beamPresentLine,g_beamPresentsLate
dump binary memory ../tmp/aga-fixture-3-planes.bin (char*)$screen->m_chip (char*)$screen->m_chip+64000
dump binary memory ../tmp/aga-fixture-3-copper.bin (char*)$screen->m_copper (char*)$screen->m_copper+2248
dump binary memory ../tmp/aga-fixture-3-source.bin (char*)g_agaProbeSource (char*)g_agaProbeSource+307200
dump binary memory ../tmp/aga-fixture-3-clut.bin (char*)g_agaProbeColors (char*)g_agaProbeColors+2056
continue
if g_agaProbeStage!=4 || g_agaProbeError!=0 || g_macFramesQueued!=4 || g_macFramesPresented!=4
 echo FAIL AGA fixture stage\n
 detach
 quit 1
end
set $screen=g_agaProbeScreen
printf "AGA_FIX stage=%u front=%X copper=%X crop=%u/%u pending=%u line=%u late=%u\n",g_agaProbeStage,$screen->m_chip,$screen->m_copper,$screen->m_cropLeft,$screen->m_cropTop,$screen->m_framePending,g_beamPresentLine,g_beamPresentsLate
dump binary memory ../tmp/aga-fixture-4-planes.bin (char*)$screen->m_chip (char*)$screen->m_chip+64000
dump binary memory ../tmp/aga-fixture-4-copper.bin (char*)$screen->m_copper (char*)$screen->m_copper+2248
dump binary memory ../tmp/aga-fixture-4-source.bin (char*)g_agaProbeSource (char*)g_agaProbeSource+307200
dump binary memory ../tmp/aga-fixture-4-clut.bin (char*)g_agaProbeColors (char*)g_agaProbeColors+2056
continue
if g_agaProbeStage!=5 || g_agaProbeError!=0 || g_macFramesQueued!=5 || g_macFramesPresented!=5
 echo FAIL AGA fixture stage\n
 detach
 quit 1
end
set $screen=g_agaProbeScreen
printf "AGA_FIX stage=%u front=%X copper=%X crop=%u/%u pending=%u line=%u late=%u\n",g_agaProbeStage,$screen->m_chip,$screen->m_copper,$screen->m_cropLeft,$screen->m_cropTop,$screen->m_framePending,g_beamPresentLine,g_beamPresentsLate
dump binary memory ../tmp/aga-fixture-5-planes.bin (char*)$screen->m_chip (char*)$screen->m_chip+64000
dump binary memory ../tmp/aga-fixture-5-copper.bin (char*)$screen->m_copper (char*)$screen->m_copper+2248
dump binary memory ../tmp/aga-fixture-5-source.bin (char*)g_agaProbeSource (char*)g_agaProbeSource+307200
dump binary memory ../tmp/aga-fixture-5-clut.bin (char*)g_agaProbeColors (char*)g_agaProbeColors+2056
continue
printf "AGA_RESTORED stage=%u done=%u error=%u front=%X back=%X copper=%X\n",g_agaProbeStage,g_agaProbeDone,g_agaProbeError,g_agaProbeScreen->m_chip,g_agaProbeScreen->m_back,g_agaProbeScreen->m_copper
if g_agaProbeStage!=99 || g_agaProbeDone!=1 || g_agaProbeError!=0 || g_agaProbeScreen->m_chip!=0 || g_agaProbeScreen->m_back!=0 || g_agaProbeScreen->m_copper!=0
 echo FAIL AGA fixture cleanup\n
 detach
 quit 1
end
echo PASS AGA fixture frames=5 restored=1\n
detach
quit 0
