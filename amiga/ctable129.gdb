set pagination off
set confirm off
break AitdScreen::showLoudStop
tbreak dispatchMacTrap if trap==0xaa18 && *(unsigned short*)userStack==129
continue
source ctable129_call.gdb
source runtime_status.gdb
