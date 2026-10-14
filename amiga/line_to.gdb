set pagination off
set confirm off
break AitdScreen::showLoudStop
tbreak dispatchMacTrap if trap==0xa8ec
continue
tbreak *(s_segments[6].begin+0x337e)
continue
tbreak *aitd_line_a_trap_entry
continue
source lineto_call.gdb
detach
quit 0
