set pagination off
set confirm off
set width 0
break AitdScreen::showLoudStop
tbreak dispatchMacTrap if trap==0xaa18
continue
set $engine=s_segments[7].begin
set $args=(unsigned long)userStack
if *(unsigned long*)(frame+2)!=(unsigned long)$engine+0x110e
 echo FAIL GetCTable entry\n
 detach
 quit 1
end
echo ARM native ctable original bytes\n
printf "CTABLE_ENTER sp=%X id=%X slot=%X bytes=%08X/%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$args,*(unsigned short*)$args,*(unsigned long*)($args+2),*(unsigned long*)($engine+0x110a),*(unsigned short*)($engine+0x110e),regs[0],regs[1],regs[2],regs[3],regs[4],regs[5],regs[6],regs[7],regs[8],regs[9],regs[10],regs[11],regs[12],regs[13],regs[14]
tbreak *($engine+0x1110)
continue
if $pc!=$engine+0x1110
 echo FAIL GetCTable return\n
 detach
 quit 1
end
set $handle=*(unsigned long*)$sp
set $body=*(unsigned long*)$handle
printf "CTABLE_RETURN sp=%X handle=%X master=%X body=%X seed=%X flags=%X size=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$sp,$handle,$body,$body,*(unsigned long*)$body,*(unsigned short*)($body+4),*(unsigned short*)($body+6),$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
dump binary memory ../tmp/ctable-native-return.bin $body $body+2056
tbreak *($engine+0x114a)
continue
if $pc!=$engine+0x114a
 echo FAIL GetCTable mutation loop\n
 detach
 quit 1
end
printf "CTABLE_MUTATED handle=%X body=%X seed=%X flags=%X size=%X count=%X\n",*(unsigned long*)($a4+32),$body,*(unsigned long*)$body,*(unsigned short*)($body+4),*(unsigned short*)($body+6),*(unsigned short*)($a6-2)
dump binary memory ../tmp/ctable-native-mutated.bin $body $body+2056
echo PASS original GetCTable and mutations\n
continue
printf "CTABLE_NEXT state=%u trap=%X selector=%X segment=%u offset=%X manager=%s routine=%s windows=%u services=%u/%u reads=%u bytes=%u\n",g_stageBState,g_trapWord,g_trapSelector,g_trapSegment,g_trapOffset,g_trapManager,g_trapRoutine,g_systemWindows,g_macServiceEntered,g_macServiceCompleted,g_resourceRuntimeReads,g_resourceRuntimeBytes
if g_stageBState!=3 || g_trapWord!=0xab1d || g_trapSegment!=10 || g_trapOffset!=0x2da || *(unsigned long*)(g_trapRoutine+0)!=0x47455450 || *(unsigned long*)(g_trapRoutine+4)!=0x49584241 || *(unsigned long*)(g_trapRoutine+8)!=0x53454144 || *(unsigned short*)(g_trapRoutine+12)!=0x4452 || g_trapRoutine[14]!=0 || g_macServiceActive!=0
 echo FAIL GetCTable next stop\n
 detach
 quit 1
end
set $i=0
while $i<g_resourceCount
 if s_resourceHandles[$i]==$handle || (s_resourceForks.m_items[$i].item.type==0x4d445256 && s_resourceHandles[$i]!=0)
  echo FAIL colour table ownership or original mixer resident\n
  detach
  quit 1
 end
 set $i=$i+1
end
echo PASS native GetCTable detached next=GETPIXBASEADDR original-MDRV=absent\n
detach
quit 0
