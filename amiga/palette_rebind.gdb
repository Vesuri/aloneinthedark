# INTROSKIP=1 FIXEDRNG=1. Observe the original repeat presentation binding.
set pagination off
set confirm off
set width 0
break AitdScreen::showLoudStop
commands
 silent
 printf "FAIL palette reactivation: %s / %s selector=%u\n",manager,routine,selector
 detach
 quit 1
end
# PAKPROBE=1 records the actual repeat call without per-trap debugger stops.
tbreak aitdPaletteRebindProbe
continue
set $rebind_regs=(unsigned long*)g_rebindProbeRegs
set $rebind_frame=(unsigned char*)g_rebindProbeFrame
set $rebind_args=(unsigned char*)g_rebindProbeArgs
if *(unsigned long*)($rebind_frame+2)!=(unsigned long)s_segments[5].begin+0x20cc
 echo FAIL original repeat SetPalette caller\n
 detach
 quit 1
end
source palette_rebind_call.gdb
detach
quit 0
