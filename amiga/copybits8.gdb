set pagination off
set confirm off
break AitdScreen::showLoudStop
tbreak dispatchMacTrap if trap==0xa8ec && *(unsigned long*)(frame+2)==(unsigned long)s_segments[10].begin+0x24d2
continue
source copybits8_call.gdb
source runtime_status.gdb
