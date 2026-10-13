# First intro copy, without stopping at every Macintosh trap.
set pagination off
set confirm off
break AitdScreen::showLoudStop
tbreak aitdCopyBitsQuickMiss
continue
mac-trap-args
if *(unsigned long*)($mac_frame+2)!=(unsigned long)s_segments[10].begin+0x24d2
 echo FAIL first intro CopyBits caller\n
 detach
 quit 1
end
source copybits8_call.gdb
detach
quit 0
