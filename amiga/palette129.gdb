set pagination off
set confirm off
set width 0
break AitdScreen::showLoudStop
tbreak dispatchMacTrap if trap==0xaa91 && *(unsigned long*)(frame+2)==(unsigned long)s_segments[5].begin+0x201c
continue
source palette129_call.gdb
source runtime_status.gdb
