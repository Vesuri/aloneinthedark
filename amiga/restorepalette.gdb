set pagination off
set confirm off
break AitdScreen::showLoudStop
tbreak dispatchMacTrap if trap==0xaa95 && *(unsigned long*)(frame+2)==(unsigned long)s_segments[5].begin+0x214c
continue
source restorepalette_call.gdb
source runtime_status.gdb
