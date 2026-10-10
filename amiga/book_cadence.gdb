# Clean-build FRAMEAUDIT=1. No per-frame breakpoints or profiling timers.
set pagination off
set confirm off
set width 0
break AitdScreen::showLoudStop
commands
 silent
 echo FAIL book audit loud stop\n
 detach
 quit 1
end
tbreak copyPortBits8
continue
set $dark=(unsigned long)s_segments[4].begin
if *(unsigned long*)($dark+0x5220)!=0x600001b8
 echo FAIL book audit original bytes\n
 detach
 quit 1
end
tbreak *($dark+0x5220)
continue
if g_macBookFramesCompleted!=840 || g_macBookFrameActive
 echo FAIL incomplete book audit\n
 detach
 quit 1
end
dump binary memory ../tmp/book-cadence.bin (char*)g_frameAudit (char*)g_frameAudit+sizeof(g_frameAudit)
echo PASS complete book audit\n
detach
quit 0
