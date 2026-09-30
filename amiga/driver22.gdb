set pagination off
set confirm off
break AitdScreen::showLoudStop
tbreak dispatchMacTrap if trap==0xa0f8 && inUserService && *(unsigned long*)(userStack+4)==22
continue
source driver22_call.gdb
source runtime_status.gdb
