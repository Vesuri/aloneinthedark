set pagination off
set confirm off
break AitdScreen::showLoudStop
tbreak dispatchMacTrap if trap==0xa8a2
continue
source paintrect_call.gdb
source runtime_status.gdb
