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
break dispatchMacTrap if trap==0xa97c
continue
set $dan=s_segments[13].begin
if *(unsigned long*)($dan+0x3418)!=0x4878ffff || *(unsigned long*)($dan+0x341c)!=0xa97c285f
 echo FAIL original dialog bytes\n
 detach
 quit 1
end
set $args=userStack
set $qd=s_qdThePort
set $oldport=*(unsigned long*)$qd
printf "DIALOG_ENTER sp=%X behind=%X storage=%X id=%X qdPort=%X windows=%X d3=%X d4=%X d5=%X d6=%X d7=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$args,*(unsigned long*)$args,*(unsigned long*)($args+4),*(unsigned short*)($args+8),$oldport,s_windowList,regs[3],regs[4],regs[5],regs[6],regs[7],regs[10],regs[11],regs[12],regs[13],regs[14]
disable breakpoints
tbreak *($dan+0x341e)
break AitdScreen::showLoudStop
continue
if $pc!=(unsigned long)($dan+0x341e) || $sp!=(unsigned long)$args+10
 echo FAIL hidden dialog result/stack\n
 detach
 quit 1
end
set $dialog=*(unsigned long*)$sp
if !$dialog || s_windowList!=(unsigned char*)$dialog || *(unsigned long*)$qd!=$oldport || *(unsigned char*)($dialog+110)!=0
 echo FAIL hidden dialog identity/visibility/current-port\n
 detach
 quit 1
end
printf "DIALOG_RETURN sp=%X expected=%X dialog=%X qdPort=%X windows=%X d3=%X d4=%X d5=%X d6=%X d7=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$sp,(unsigned long)$args+10,$dialog,*(unsigned long*)$qd,s_windowList,$d3,$d4,$d5,$d6,$d7,$a2,$a3,$a4,$a5,$a6
dump binary memory ../tmp/dialog-native-record.bin $dialog $dialog+170
set $items=**(unsigned long**)($dialog+156)
dump binary memory ../tmp/dialog-native-items.bin $items $items+116
set $foundSource=0
set $ri=0
while $ri<g_resourceCount
 if s_resourceForks.m_items[$ri].item.type==0x4449544c && s_resourceForks.m_items[$ri].item.id==1000
  set $source=s_resourceHandles[$ri]
  if !$source || !*$source || (unsigned long)$source==*(unsigned long*)($dialog+156)
   echo FAIL dialog source/private ownership\n
   detach
   quit 1
  end
  dump binary memory ../tmp/dialog-native-source.bin *$source *$source+116
  set $foundSource=$foundSource+1
 end
 set $ri=$ri+1
end
if $foundSource!=1
 echo FAIL dialog source coverage\n
 detach
 quit 1
end
set $control1=**(unsigned long**)($items+2)
set $control2=**(unsigned long**)($items+26)
set $text=**(unsigned long**)($items+50)
dump binary memory ../tmp/dialog-native-control1.bin $control1 $control1+50
dump binary memory ../tmp/dialog-native-control2.bin $control2 $control2+50
dump binary memory ../tmp/dialog-native-text.bin $text $text+51
set $region=**(unsigned long**)($dialog+24)
dump binary memory ../tmp/dialog-native-vis.bin $region $region+10
set $region=**(unsigned long**)($dialog+28)
dump binary memory ../tmp/dialog-native-clip.bin $region $region+10
set $region=**(unsigned long**)($dialog+114)
dump binary memory ../tmp/dialog-native-struct.bin $region $region+10
set $region=**(unsigned long**)($dialog+118)
dump binary memory ../tmp/dialog-native-content.bin $region $region+10
set $region=**(unsigned long**)($dialog+122)
dump binary memory ../tmp/dialog-native-update.bin $region $region+10
continue
printf "DIALOG_NEXT state=%u trap=%X selector=%X segment=%u offset=%X routine=%s windows=%u services=%u/%u resources=%u/%u\n",g_stageBState,g_trapWord,g_trapSelector,g_trapSegment,g_trapOffset,g_trapRoutine,g_systemWindows,g_macServiceEntered,g_macServiceCompleted,g_resourceRuntimeReads,g_resourceRuntimeBytes
if g_stageBState!=3 || g_trapWord!=0xa870 || g_trapSegment!=9 || g_trapOffset!=0xe20 || g_macServiceActive!=0 || g_systemWindows!=$startup_windows || g_macServiceEntered!=$startup_entered || g_macServiceCompleted!=$startup_completed || g_resourceRuntimeReads!=62 || g_resourceRuntimeBytes!=265454 || *(unsigned long*)(g_trapRoutine+0)!=0x4c4f4341 || *(unsigned long*)(g_trapRoutine+4)!=0x4c544f47 || *(unsigned long*)(g_trapRoutine+8)!=0x4c4f4241 || *(unsigned short*)(g_trapRoutine+12)!=0x4c00
 echo FAIL hidden dialog next stop\n
 detach
 quit 1
end
echo PASS native hidden dialog next=LOCALTOGLOBAL\n
detach
quit 0
