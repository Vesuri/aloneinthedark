set pagination off
set confirm off
set width 0
break AitdScreen::showLoudStop
tbreak dispatchMacTrap if trap==0xa8ec
continue
set $call=(unsigned long)s_segments[4].begin+0x346c
if g_stageBState==3 || *(unsigned long*)($call-4)!=0x42672f0a || *(unsigned short*)$call!=0xa8ec
 echo FAIL masked copy original bytes\n
 detach
 quit 1
end
tbreak *$call
continue
if $pc!=$call
 echo FAIL masked copy caller not reached\n
 detach
 quit 1
end
tbreak dispatchMacTrap
continue
if g_stageBState==3 || trap!=0xa8ec
 echo FAIL masked copy dispatch\n
 detach
 quit 1
end
source maskcopy_call.gdb
set $dispose=$call-0x346c+0x3058
tbreak *$dispose
continue
printf "MASKCOPY_CONTINUE pc=%X expected=%X sp=%X sr=%X\n",$pc,$dispose,$sp,$sr
info registers
x/24wx $sp
if $pc!=$dispose
 echo FAIL disposal caller not reached\n
 detach
 quit 1
end
printf "MASKCOPY_DISPOSE bytes=%04X%04X handle=%X body=%X\n",*(unsigned short*)($dispose-2),*(unsigned short*)$dispose,*(unsigned long*)$sp,*(unsigned long*)*(unsigned long*)$sp
tbreak dispatchMacTrap
continue
printf "MASKCOPY_DISPATCH pc=%X trap=%X stage=%u\n",$pc,trap,g_stageBState
info registers
continue
if g_stageBState!=3 || g_trapWord!=0xa8d9 || g_trapSegment!=4 || g_trapOffset!=0x3058
 echo FAIL masked copy continuation\n
 detach
 quit 1
end
printf "MASKCOPY_NEXT trap=%X segment=%X offset=%X routine=%s\n",g_trapWord,g_trapSegment,g_trapOffset,g_trapRoutine
echo COMPLETE native masked copy and continuation\n
detach
quit 0
