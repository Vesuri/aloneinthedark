# VBLPROBE=1: real traps/callbacks; no debugger stops inside the fixture.
set pagination off
set confirm off
break AitdScreen::showLoudStop
commands
 silent
 echo FAIL VBL contract loud stop\n
 detach
 quit 1
end
tbreak aitdVBLProbeComplete
continue
if g_vblProbeDone!=1 || g_vblProbeCases!=7 || g_macLineAInstalled!=0
 printf "FAIL VBL contract cases=%u done=%u\n",g_vblProbeCases,g_vblProbeDone
 detach
 quit 1
end
echo PASS VBL contract: four countdowns, rearming, automatic removal, VRemove, retained links, queued passes\n
detach
quit 0
