# Positive frame-9 checkpoint, before the first original book line.
set pagination off
set confirm off
set width 0
break AitdScreen::showLoudStop
commands
 silent
 printf "FAIL AGA startup: %s / %s selector=%u\n",manager,routine,selector
 detach
 quit 1
end
tbreak dispatchMacTrap if trap==0xa891 && s_segments[6].begin && *(unsigned long*)(frame+2)==(unsigned long)s_segments[6].begin+0x337e
continue
if *(unsigned short*)(s_segments[6].begin+0x337e)!=0xa891 || g_stageBState!=1
 echo FAIL original first book line checkpoint\n
 detach
 quit 1
end
source aga_startup_call.gdb
detach
quit 0
