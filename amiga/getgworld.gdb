set pagination off
set confirm off
set width 0
source .run/startup-state.gdb
break AitdScreen::showLoudStop
tbreak getFontNumber
continue
set $core=s_segments[3].begin
tbreak *($core+0x502)
continue
break dispatchMacTrap if trap==0xab1d && (regs[0]&0xffff)==5
continue
set $dan=s_segments[13].begin
if *(unsigned long*)($dan+0x30e2)!=0xab1d4eba || *(unsigned long*)($dan+0x30de)!=0x00080005
 echo FAIL GetGWorld original bytes\n
 detach
 quit 1
end
set $args=userStack
set $deviceOut=*(unsigned long*)$args
set $portOut=*(unsigned long*)($args+4)
set $qd=(unsigned long)s_qdThePort
set $port=*(unsigned long*)$qd
set $device=(unsigned long)&s_mainDeviceMaster
printf "WORLD_ENTER seq=1 sp=%X deviceOut=%X portOut=%X opcode=AB1D4EBA selectorBytes=00080005 qdPort=%X mainDevice=%X wmgrPort=%X d0=%08X d1=%08X d2=%08X d3=%08X d4=%08X d5=%08X d6=%08X d7=%08X a0=%08X a1=%08X a2=%08X a3=%08X a4=%08X a5=%08X a6=%08X\n",$args,$deviceOut,$portOut,$port,$device,*(unsigned long*)(s_portLowMemory+8),regs[0],regs[1],regs[2],regs[3],regs[4],regs[5],regs[6],regs[7],regs[8],regs[9],regs[10],regs[11],regs[12],regs[13],regs[14]
dump binary memory ../tmp/getgworld-native-before-port.bin $port $port+108
dump binary memory ../tmp/getgworld-native-screen.bin $qd-122 $qd-108
tbreak *($dan+0x30e4)
continue
if $pc!=(unsigned long)($dan+0x30e4) || $sp!=(unsigned long)$args+8 || *(unsigned long*)$portOut!=$port || *(unsigned long*)$deviceOut!=$device || *(unsigned long*)$qd!=$port
 echo FAIL GetGWorld result or stack\n
 detach
 quit 1
end
printf "WORLD_RETURN seq=1 sp=%X expected=%X port=%X device=%X qdPort=%X mainDevice=%X wmgrPort=%X d0=%08X d1=%08X d2=%08X d3=%08X d4=%08X d5=%08X d6=%08X d7=%08X a0=%08X a1=%08X a2=%08X a3=%08X a4=%08X a5=%08X a6=%08X\n",$sp,(unsigned long)$args+8,*(unsigned long*)$portOut,*(unsigned long*)$deviceOut,*(unsigned long*)$qd,$device,*(unsigned long*)(s_portLowMemory+8),$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
dump binary memory ../tmp/getgworld-native-after-port.bin $port $port+108
set $gd=*(unsigned long*)$device
dump binary memory ../tmp/getgworld-native-device.bin $gd $gd+62
set $pm=**(unsigned long**)($gd+22)
set $pixels=*(unsigned long*)$pm
if *(unsigned long*)($port+2)!=$pixels || *(unsigned long*)($qd-122)!=$pixels
 echo FAIL shared device backing\n
 detach
 quit 1
end
continue
printf "WORLD_NEXT state=%u trap=%X selector=%X segment=%u offset=%X routine=%s windows=%u services=%u/%u resources=%u/%u\n",g_stageBState,g_trapWord,g_trapSelector,g_trapSegment,g_trapOffset,g_trapRoutine,g_systemWindows,g_macServiceEntered,g_macServiceCompleted,g_resourceRuntimeReads,g_resourceRuntimeBytes
if g_stageBState!=3 || g_trapWord!=0xaa2c || g_trapSelector!=-1 || g_trapSegment!=9 || g_trapOffset!=0xe3a || *(unsigned long*)(g_trapRoutine+0)!=0x54455354 || *(unsigned long*)(g_trapRoutine+4)!=0x44455649 || *(unsigned long*)(g_trapRoutine+8)!=0x43454154 || *(unsigned long*)(g_trapRoutine+12)!=0x54524942 || *(unsigned long*)(g_trapRoutine+16)!=0x55544500 || g_systemWindows!=$startup_windows || g_macServiceEntered!=$startup_entered || g_macServiceCompleted!=$startup_completed || g_macServiceActive!=0
 echo FAIL GetGWorld next named stop\n
 detach
 quit 1
end
printf "PASS native GetGWorld calls=1 next=TESTDEVICEATTRIBUTE\n"
detach
quit 0
