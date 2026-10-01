# Normal game route; no input, game code or timer patches.
set pagination off
set confirm off
break AitdScreen::showLoudStop
# Original Core is resident by the first CopyBits.
tbreak dispatchMacTrap if trap==0xa8ec
continue
if g_stageBState==3
 echo FAIL effect replacement startup\n
 detach
 quit 1
end
source effectreplace_call.gdb
detach
quit 0
