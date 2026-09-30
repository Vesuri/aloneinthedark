# WINDOWPROBE=1 PROBES=1. All captures remain local in tmp/.
set pagination off
set confirm off
break AitdScreen::showLoudStop
commands
 silent
 printf "window FAIL: chunk=%u error=%u windows=%u fields=%u %s / %s\n",g_windowProbeChunk,g_windowProbeError,g_systemWindows,g_windowFields,g_trapManager,g_trapRoutine
 detach
 quit 1
end
tbreak aitdWindowProbeBefore
continue
set $window_late=g_beamPresentsLate
dump binary memory ../tmp/window-before.bin g_windowProbePicture g_windowProbePicture+64000
break aitdWindowProbeInside if g_windowProbeChunk==8
continue
if g_systemWindowActive != 1 || g_macLineAInstalled != 0 || ((struct ExecBase*)SysBase)->TDNestCnt != -1
 echo window FAIL: OS ownership inside read\n
 detach
 quit 1
end
dump binary memory ../tmp/window-during.bin g_windowProbePicture g_windowProbePicture+64000
printf "window inside: fields=%u ticks=%u OS multitasking active\n",g_windowFields,g_macTicks
tbreak aitdWindowProbeAfter
continue
if g_windowProbeKeyChecks != 11 || g_windowProbeDone != 1 || g_windowProbeHash != 0x59bc1dc5 || g_systemWindows != 21 || g_windowProbeIOChecks != 5 || g_systemWindowActive != 0 || g_macLineAInstalled != 1 || ((struct ExecBase*)SysBase)->TDNestCnt != 0
 printf "window FAIL: done=%u hash=$%x windows=%u active=%u\n",g_windowProbeDone,g_windowProbeHash,g_systemWindows,g_systemWindowActive
 detach
 quit 1
end

if g_beamPresentsLate != $window_late
 echo window FAIL: late display publication\n
 detach
 quit 1
end
dump binary memory ../tmp/window-after.bin g_windowProbePicture g_windowProbePicture+64000
printf "window display: late-fields=%u max-line=%u\n",g_beamPresentsLate-$window_late,g_beamPresentMax
printf "window measured: hash=$%x fields=%u ticks=%u inside-fields=%u entry=%u exit=%u\n",g_windowProbeHash,g_windowProbeFields,g_windowProbeTicks,g_windowFields,g_windowEnterTicks,g_windowExitTicks
printf "window Paula: interrupts=%u inside=%u positive-windows=%u\n",g_windowProbeAudio,g_windowProbeAudioInside,g_windowProbeAudioWindows
echo PASS native KeyMap: 11 guarded released/held/multiple-key/alias snapshots; events not consumed\n
echo PASS window-read: bytes=1048576 chunks=16 checksum=59bc1dc5\n
detach
quit 0
