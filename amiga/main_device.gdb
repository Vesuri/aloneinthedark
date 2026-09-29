set pagination off
set confirm off
set width 0
source .run/startup-state.gdb
break AitdScreen::showLoudStop
tbreak getFontNumber
continue
set $engine=s_segments[7].begin
break dispatchMacTrap if trap==0xaa2a
continue
if *(unsigned long*)($engine+0x4780)!=0x42a7aa2a || *(unsigned long*)($engine+0x4784)!=0x285f206e
 echo FAIL original GetMainDevice bytes\n
 detach
 quit 1
end
set $args=userStack
set $main=(unsigned long)&s_mainDeviceMaster
set $gd=(unsigned long)s_mainDeviceMaster
set $qd=s_qdThePort
set $port=*(unsigned long*)$qd
printf "MAIN_ENTER sp=%X opcode=AA2A285F main=%X current=%X port=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$args,$main,$main,$port,regs[0],regs[1],regs[2],regs[3],regs[4],regs[5],regs[6],regs[7],regs[8],regs[9],regs[10],regs[11],regs[12],regs[13],regs[14]
dump binary memory ../tmp/main-device-native-before.bin $gd $gd+62
disable breakpoints
tbreak *($engine+0x4784)
break AitdScreen::showLoudStop
continue
if $pc!=(unsigned long)$engine+0x4784 || $sp!=(unsigned long)$args || *(unsigned long*)$sp!=$main || *(unsigned long*)$qd!=$port || (unsigned long)s_mainDeviceMaster!=$gd
 echo FAIL GetMainDevice result/state/stack\n
 detach
 quit 1
end
printf "MAIN_RETURN sp=%X result=%X main=%X current=%X port=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$sp,*(unsigned long*)$sp,$main,$main,*(unsigned long*)$qd,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
dump binary memory ../tmp/main-device-native-after.bin $gd $gd+62
continue
printf "MAIN_NEXT state=%u trap=%X selector=%X segment=%u offset=%X routine=%s windows=%u services=%u/%u\n",g_stageBState,g_trapWord,g_trapSelector,g_trapSegment,g_trapOffset,g_trapRoutine,g_systemWindows,g_macServiceEntered,g_macServiceCompleted
if g_stageBState!=3 || g_trapWord!=0xaa95 || g_trapSelector!=-1 || g_trapSegment!=9 || g_trapOffset!=0x10fa || *(unsigned long*)(g_trapRoutine+0)!=0x53455450 || *(unsigned long*)(g_trapRoutine+4)!=0x414c4554 || *(unsigned short*)(g_trapRoutine+8)!=0x5445 || g_trapRoutine[10]!=0 || g_macServiceActive!=0 || g_systemWindows!=$startup_windows || g_macServiceEntered!=$startup_entered || g_macServiceCompleted!=$startup_completed
 echo FAIL GetMainDevice next stop\n
 detach
 quit 1
end
echo PASS native GetMainDevice next=SETPALETTE\n
detach
quit 0
